// PitchDetection.swift
// luksMusic
//
// Turns microphone audio into played notes, apart from the audio session so it can be tested with synthetic tones.
// `PitchDetector` finds the pitch of a window of samples (YIN: the first strong dip of the normalized difference
// function, which avoids the octave errors of picking the strongest autocorrelation peak on a piano's harmonics).
// `NoteOnsetTracker` decides when a key was actually struck, so a note that keeps ringing counts once.

import Accelerate
import Foundation

enum PitchDetector {

    struct Estimate: Equatable {
        let frequency: Double
        /// 0 (noise) to 1 (perfectly periodic)
        let clarity: Double

        var midiNote: Int { Int((69.0 + 12.0 * log2(frequency / 440.0)).rounded()) }
    }

    static let lowestFrequency = 50.0 // below A1
    static let highestFrequency = 4300.0 // above C8
    /// A dip must go below this to count as the period
    private static let dipThreshold: Float = 0.15

    /// The window should hold at least two periods of the lowest note: 4096 samples at 44.1 or 48 kHz.
    static func estimate(samples: [Float], sampleRate: Double) -> Estimate? {
        let maxLag = min(samples.count / 2, Int(sampleRate / lowestFrequency))
        let minLag = max(2, Int(sampleRate / highestFrequency))
        guard maxLag > minLag + 2 else { return nil }
        let window = samples.count - maxLag

        // d(lag) = sum of (x[i] - x[i + lag])^2
        var difference = [Float](repeating: 0, count: maxLag + 1)
        var scratch = [Float](repeating: 0, count: window)
        samples.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            for lag in 1...maxLag {
                vDSP_vsub(base.advanced(by: lag), 1, base, 1, &scratch, 1, vDSP_Length(window))
                vDSP_svesq(scratch, 1, &difference[lag], vDSP_Length(window))
            }
        }

        // d'(lag) = d(lag) / mean of d(1...lag): removes the bias toward short lags
        var normalized = [Float](repeating: 1, count: maxLag + 1)
        var running: Float = 0
        for lag in 1...maxLag {
            running += difference[lag]
            normalized[lag] = running > 0 ? difference[lag] * Float(lag) / running : 1
        }

        // The first dip under the threshold is the period; multiples of it are deeper or equal but an octave low
        var lag = minLag
        var found: Int?
        while lag < maxLag {
            if normalized[lag] < dipThreshold {
                while lag + 1 < maxLag && normalized[lag + 1] < normalized[lag] {
                    lag += 1
                }
                found = lag
                break
            }
            lag += 1
        }
        guard let best = found, best > 0, best < maxLag else { return nil }

        let before = Double(normalized[best - 1])
        let center = Double(normalized[best])
        let after = Double(normalized[best + 1])
        let curvature = before - 2 * center + after
        let refined = Double(best) + (curvature != 0 ? (before - after) / (2 * curvature) : 0)
        guard refined > 0 else { return nil }
        let clarity = max(0, min(1, 1 - center))
        return Estimate(frequency: sampleRate / refined, clarity: clarity)
    }
}

/// Reads one short frame of microphone audio at a time and reports each struck note once.
struct NoteOnsetTracker {

    /// One hop of audio: its level and, when it could be measured, its note.
    struct Frame {
        let level: Float
        let midiNote: Int?
    }

    /// Below this the room is treated as silence
    var noiseGate: Float = 0.012
    /// A strike raises the level at least this much above the note still ringing
    var attackRatio: Float = 1.45
    /// Hops to wait after a strike, while the hammer noise fades, before reading the note
    var settleFrames = 4
    /// Hops to keep trying to read the note after a strike
    var readFrames = 14
    /// Hops a different note must hold, with no strike heard, to count as a new note (a soft note over a loud one)
    var changeFrames = 4
    /// How fast the remembered level falls per hop (a piano note fades slowly)
    var envelopeDecay: Float = 0.94

    private var envelope: Float = 0
    private var framesSinceStrike: Int?
    private var soundingNote: Int?
    private var candidate: Int?
    private var candidateFrames = 0

    /// Forgets everything heard so far (after the app played something, or when listening restarts).
    mutating func reset() {
        envelope = 0
        framesSinceStrike = nil
        soundingNote = nil
        candidate = nil
        candidateFrames = 0
    }

    /// Returns the note that was just played, if this frame completes one.
    mutating func process(_ frame: Frame) -> Int? {
        let isStrike = frame.level >= noiseGate && frame.level > max(envelope, noiseGate * 0.5) * attackRatio
        envelope = max(frame.level, envelope * envelopeDecay)

        guard frame.level >= noiseGate else {
            if envelope < noiseGate {
                soundingNote = nil
            }
            framesSinceStrike = nil
            candidate = nil
            candidateFrames = 0
            return nil
        }

        if isStrike {
            framesSinceStrike = 0
            candidate = nil
            candidateFrames = 0
            return nil
        }

        if let frames = framesSinceStrike {
            let elapsed = frames + 1
            framesSinceStrike = elapsed
            guard elapsed >= settleFrames else { return nil }
            if let note = frame.midiNote {
                framesSinceStrike = nil
                soundingNote = note
                return note
            }
            if elapsed >= readFrames {
                framesSinceStrike = nil
            }
            return nil
        }

        guard let note = frame.midiNote, note != soundingNote else {
            candidate = nil
            candidateFrames = 0
            return nil
        }
        if note == candidate {
            candidateFrames += 1
        } else {
            candidate = note
            candidateFrames = 1
        }
        guard candidateFrames >= changeFrames else { return nil }
        candidate = nil
        candidateFrames = 0
        soundingNote = note
        return note
    }
}

/// Slices microphone audio into short hops, measures each one and reports the notes played.
struct MicrophoneNoteReader {
    let sampleRate: Double
    private(set) var level: Float = 0
    private(set) var lastEstimate: PitchDetector.Estimate?

    private let hopSize = 1024
    private let windowSize = 4096
    /// Estimates less periodic than this are noise, or several notes at once
    private let minimumClarity = 0.8
    private var pending: [Float] = []
    private var window: [Float] = []
    private var tracker = NoteOnsetTracker()

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    mutating func reset() {
        pending.removeAll(keepingCapacity: true)
        window.removeAll(keepingCapacity: true)
        tracker.reset()
        level = 0
        lastEstimate = nil
    }

    /// Takes the next samples of any length and returns the notes struck in them, in order.
    mutating func read(_ samples: UnsafeBufferPointer<Float>) -> [Int] {
        pending.append(contentsOf: samples)
        var notes: [Int] = []
        var start = 0
        while pending.count - start >= hopSize {
            let hop = Array(pending[start..<(start + hopSize)])
            start += hopSize
            window.append(contentsOf: hop)
            if window.count > windowSize {
                window.removeFirst(window.count - windowSize)
            }

            var rms: Float = 0
            vDSP_rmsqv(hop, 1, &rms, vDSP_Length(hop.count))
            level = rms

            var note: Int?
            lastEstimate = nil
            if window.count == windowSize, rms >= tracker.noiseGate,
               let estimate = PitchDetector.estimate(samples: window, sampleRate: sampleRate),
               estimate.clarity >= minimumClarity, (21...108).contains(estimate.midiNote) {
                note = estimate.midiNote
                lastEstimate = estimate
            }
            if let played = tracker.process(NoteOnsetTracker.Frame(level: rms, midiNote: note)) {
                notes.append(played)
            }
        }
        pending.removeFirst(start)
        return notes
    }
}
