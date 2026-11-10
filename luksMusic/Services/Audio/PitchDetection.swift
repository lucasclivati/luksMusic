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
        // No dip under the threshold (a real room's echo, a bright piano tone): take the first dip close to the
        // deepest one, as long as the deepest is clearly periodic
        if found == nil, let deepest = normalized[minLag..<maxLag].min(), deepest < 0.3 {
            lag = minLag + 1
            while lag < maxLag {
                if normalized[lag] <= deepest + 0.05, normalized[lag] <= normalized[lag - 1], normalized[lag] <= normalized[lag + 1] {
                    found = lag
                    break
                }
                lag += 1
            }
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

    /// Never treat as sound anything quieter than this
    var minimumGate: Float = 0.001
    /// Below this the room is treated as silence: a few times the room's own noise, which is followed as it changes
    var noiseGate: Float { max(minimumGate, noiseFloor * 3) }
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

    /// The last frame was the attack of a new sound
    private(set) var struckThisFrame = false

    private var envelope: Float = 0
    /// The quietest level heard lately: falls at once, rises slowly while sound goes on
    private var noiseFloor: Float = 0.002
    private var framesSinceStrike: Int?
    private var soundingNote: Int?
    private var candidate: Int?
    private var candidateFrames = 0

    /// Forgets everything heard so far (after the app played something, or when listening restarts).
    mutating func reset() {
        envelope = 0
        noiseFloor = 0.002
        framesSinceStrike = nil
        soundingNote = nil
        candidate = nil
        candidateFrames = 0
    }

    /// Returns the note that was just played, if this frame completes one.
    mutating func process(_ frame: Frame) -> Int? {
        noiseFloor = frame.level < noiseFloor ? max(frame.level, 0.0001) : noiseFloor * 1.0015
        let isStrike = frame.level >= noiseGate && frame.level > max(envelope, noiseGate * 0.5) * attackRatio
        struckThisFrame = isStrike
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

/// Whether the notes a chord should have are all sounding. Telling several notes apart from nothing is hard, but
/// checking for known ones is not: each expected fundamental must stand out in the spectrum.
enum ChordMatcher {
    /// Below this share of the strongest note's energy, a note isn't considered present
    private static let presenceRatio: Float = 0.06

    static func matches(samples: [Float], sampleRate: Double, expected: Set<Int>) -> Bool {
        guard !expected.isEmpty, samples.count >= 2048 else { return false }
        var window = [Float](repeating: 0, count: samples.count)
        vDSP_hann_window(&window, vDSP_Length(samples.count), Int32(vDSP_HANN_NORM))
        var shaped = [Float](repeating: 0, count: samples.count)
        vDSP_vmul(samples, 1, window, 1, &shaped, 1, vDSP_Length(samples.count))

        var strongest: Float = 0
        for midi in 33...100 {
            strongest = max(strongest, energy(of: midi, in: shaped, sampleRate: sampleRate))
        }
        guard strongest > 0 else { return false }
        return expected.allSatisfy { energy(of: $0, in: shaped, sampleRate: sampleRate) >= strongest * presenceRatio }
    }

    /// The energy around a note's fundamental, allowing for a slightly out-of-tune instrument.
    private static func energy(of midi: Int, in samples: [Float], sampleRate: Double) -> Float {
        let frequency = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
        return [0.985, 1.0, 1.015].map { goertzel(samples, frequency: frequency * $0, sampleRate: sampleRate) }.max() ?? 0
    }

    private static func goertzel(_ samples: [Float], frequency: Double, sampleRate: Double) -> Float {
        let coefficient = Float(2 * cos(2 * .pi * frequency / sampleRate))
        var previous: Float = 0
        var beforePrevious: Float = 0
        for sample in samples {
            let current = sample + coefficient * previous - beforePrevious
            beforePrevious = previous
            previous = current
        }
        return previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious
    }
}

/// Slices microphone audio into short hops, measures each one and reports the notes played.
struct MicrophoneNoteReader {
    let sampleRate: Double
    private(set) var level: Float = 0
    private(set) var lastEstimate: PitchDetector.Estimate?

    /// Set when the exercise wants several notes at once: only a strike with all of them counts
    var expectedChord: Set<Int>? {
        didSet { if expectedChord != oldValue { chordCountdown = nil } }
    }
    /// How many strikes didn't have every note of `expectedChord`
    private(set) var missedChords = 0

    private let hopSize = 1024
    private let windowSize = 4096
    /// Enough to tell apart notes a semitone from each other, read once the attack has passed
    private let chordWindowSize = 8192
    private let chordWaitHops = 9
    private var chordCountdown: Int?
    /// Estimates less periodic than this are noise, or several notes at once
    private let minimumClarity = 0.7
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
        chordCountdown = nil
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
            if window.count > chordWindowSize {
                window.removeFirst(window.count - chordWindowSize)
            }

            var rms: Float = 0
            vDSP_rmsqv(hop, 1, &rms, vDSP_Length(hop.count))
            level = rms

            var note: Int?
            lastEstimate = nil
            if window.count >= windowSize, rms >= tracker.noiseGate,
               let estimate = PitchDetector.estimate(samples: Array(window.suffix(windowSize)), sampleRate: sampleRate),
               estimate.clarity >= minimumClarity, (21...108).contains(estimate.midiNote) {
                note = estimate.midiNote
                lastEstimate = estimate
            }
            let played = tracker.process(NoteOnsetTracker.Frame(level: rms, midiNote: note))
            if let chord = expectedChord {
                notes += readChord(chord)
            } else if let played {
                notes.append(played)
            }
        }
        pending.removeFirst(start)
        return notes
    }

    /// Waits for the attack of a strike to pass, then checks that every expected note is sounding.
    private mutating func readChord(_ chord: Set<Int>) -> [Int] {
        if tracker.struckThisFrame {
            chordCountdown = chordWaitHops
            return []
        }
        guard let countdown = chordCountdown else { return [] }
        guard countdown <= 1 else {
            chordCountdown = countdown - 1
            return []
        }
        chordCountdown = nil
        if ChordMatcher.matches(samples: window, sampleRate: sampleRate, expected: chord) {
            return chord.sorted()
        }
        missedChords += 1
        return []
    }
}
