// PitchDetection.swift
// luksMusic
//
// Turns microphone audio into played notes, apart from the audio session so it can be tested with synthetic tones.
// `PitchDetector` finds the pitch of a window of samples (YIN: the first strong dip of the normalized difference
// function, which avoids the octave errors of picking the strongest autocorrelation peak on a piano's harmonics).
// `NoteOnsetTracker` decides when a key was actually struck, so a note that keeps ringing counts once, and
// `StrikeAnalyzer` names the note a strike added, apart from the notes still ringing.

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

/// Finds the moment a key is struck: the level jumps, or (a softer key over notes still ringing) the hammer's bright
/// attack stands out in the hop's first difference while the level still rises a little.
struct NoteOnsetTracker {

    /// One hop of audio.
    struct Frame {
        let level: Float
        /// Level of the hop's first difference, which a hammer's attack raises far more than a ringing note
        var brightness: Float = 0
    }

    /// Never treat as sound anything quieter than this
    var minimumGate: Float = 0.001
    /// Below this the room is treated as silence: a few times the room's own noise, which is followed as it changes
    var noiseGate: Float { max(minimumGate, noiseFloor * 3) }
    /// A strike raises the level at least this much above the notes still ringing
    var attackRatio: Float = 1.45
    /// Or raises the brightness this much while the level rises at least `softRise`
    var brightAttackRatio: Float = 1.5
    var softRise: Float = 1.1
    /// How fast the remembered levels fall per hop: a piano note fades slowly, its bright attack quickly
    var envelopeDecay: Float = 0.94
    var brightnessDecay: Float = 0.85

    private(set) var envelope: Float = 0
    private var brightEnvelope: Float = 0
    /// The quietest level heard lately: falls at once, rises slowly while sound goes on
    private var noiseFloor: Float = 0.002

    /// Forgets everything heard so far (after the app played something, or when listening restarts).
    mutating func reset() {
        envelope = 0
        brightEnvelope = 0
        noiseFloor = 0.002
    }

    /// Takes the next hop and says whether a key was struck in it.
    mutating func isStrike(_ frame: Frame) -> Bool {
        noiseFloor = frame.level < noiseFloor ? max(frame.level, 0.0001) : noiseFloor * 1.0015
        let isLoud = frame.level >= noiseGate
        let strong = isLoud && frame.level > max(envelope, noiseGate * 0.5) * attackRatio
        let soft = isLoud && !strong && frame.brightness > brightEnvelope * brightAttackRatio
            && frame.level > envelope * softRise
        envelope = max(frame.level, envelope * envelopeDecay)
        brightEnvelope = max(frame.brightness, brightEnvelope * brightnessDecay)
        return strong || soft
    }
}

/// Which note a strike added. It is the note whose harmonics gained energy from just before the strike to just after
/// it, so notes still ringing (or held by the pedal) stay out of the answer. A pitch reading of the whole sound hears
/// two ringing notes as their common lower octave, which was the wrong note the lessons reported.
enum StrikeAnalyzer {
    /// The notes considered, A0 sharp to E7
    static let notes = 28...100
    private static let harmonics = 6
    private static let highestFrequency = 5000.0
    private static let fftSize = 16_384
    private static let setup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

    /// The best note must stand this far above the typical note: noise lifts every note alike
    private static let peakRatio: Float = 6
    /// The expected note is taken when it gained at least this share of what the best note gained
    private static let expectedShare: Float = 0.6
    /// Energy gained against the energy the note already had. The expected note may be ringing already (a key
    /// played again), so it needs less.
    private static let freshExpected: Float = 0.4
    private static let freshOther: Float = 1
    /// The note's new energy as a share of all the sound after the strike
    private static let minimumShare: Float = 0.03
    /// Energy gained on the note's harmonics against energy gained halfway between them
    private static let harmonicRatio: Float = 3
    /// A struck note's lowest partials are its strongest; a pick carried by upper partials only is another note's
    /// harmonic that happens to coincide
    private static let fundamentalShare: Float = 0.25

    struct Spectrum {
        /// Power of each harmonic of each note in `notes`
        let harmonicPowers: [[Float]]
        /// Power halfway between the note's harmonics, from the first to the fifth
        let betweenPowers: [[Float]]
        /// All the sound's power, on the same scale
        let totalPower: Float
    }

    static func spectrum(of samples: [Float], sampleRate: Double) -> Spectrum {
        let count = min(samples.count, fftSize)
        let empty = Spectrum(harmonicPowers: notes.map { _ in [Float](repeating: 0, count: harmonics) },
                             betweenPowers: notes.map { _ in [Float](repeating: 0, count: harmonics - 1) }, totalPower: 0)
        guard count > 0, let setup else { return empty }

        var window = [Float](repeating: 0, count: count)
        vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_DENORM))
        var shaped = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(Array(samples.suffix(count)), 1, window, 1, &shaped, 1, vDSP_Length(count))

        let half = fftSize / 2
        var inReal = [Float](repeating: 0, count: half)
        var inImaginary = [Float](repeating: 0, count: half)
        for index in 0..<half {
            inReal[index] = shaped[2 * index]
            inImaginary[index] = shaped[2 * index + 1]
        }
        var outReal = [Float](repeating: 0, count: half)
        var outImaginary = [Float](repeating: 0, count: half)
        vDSP_DFT_Execute(setup, inReal, inImaginary, &outReal, &outImaginary)

        var power = [Float](repeating: 0, count: half + 1)
        power[0] = outReal[0] * outReal[0]
        power[half] = outImaginary[0] * outImaginary[0]
        var sum = power[0] + power[half]
        for bin in 1..<half {
            power[bin] = outReal[bin] * outReal[bin] + outImaginary[bin] * outImaginary[bin]
            sum += 2 * power[bin]
        }
        // Parseval: the window's energy, on the same scale as the bins, whatever scale the transform uses
        let total = sum / Float(fftSize) * Float(count) / 2

        let binsPerHertz = Double(fftSize) / sampleRate
        let top = min(highestFrequency, sampleRate / 2 * 0.98)
        func strongest(near frequency: Double, tolerance: Double) -> Float {
            guard frequency <= top else { return 0 }
            let low = max(1, Int((frequency * (1 - tolerance) * binsPerHertz).rounded(.down)))
            let high = min(half, max(low, Int((frequency * (1 + tolerance) * binsPerHertz).rounded(.up))))
            return power[low...high].max() ?? 0
        }

        var harmonicPowers: [[Float]] = []
        var betweenPowers: [[Float]] = []
        for midi in notes {
            let fundamental = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
            harmonicPowers.append((1...harmonics).map { number in
                let n = Double(number)
                // Strings are a little stiff, so their upper harmonics run sharp
                return strongest(near: n * fundamental * (1 + 0.0004 * n * n).squareRoot(), tolerance: 0.01)
            })
            betweenPowers.append((1..<harmonics).map { number in
                strongest(near: (Double(number) + 0.5) * fundamental, tolerance: 0)
            })
        }
        return Spectrum(harmonicPowers: harmonicPowers, betweenPowers: betweenPowers, totalPower: total)
    }

    /// The note struck between `before` and `after`, or nil when nothing clearly new is sounding.
    static func struckNote(before: Spectrum, after: Spectrum, expected: Int?) -> Int? {
        let count = notes.count
        var gains = [[Float]](repeating: [], count: count)
        var score = [Float](repeating: 0, count: count)
        var fresh = [Float](repeating: 0, count: count)
        for index in 0..<count {
            var gained: Float = 0
            var had: Float = 0
            gains[index] = zip(before.harmonicPowers[index], after.harmonicPowers[index]).map { max(0, $1 - $0) }
            for number in 0..<harmonics {
                gained += gains[index][number] / Float(number + 1)
                had += before.harmonicPowers[index][number] / Float(number + 1)
            }
            score[index] = gained
            fresh[index] = gained / max(had, 1e-12)
        }
        guard let top = score.max(), top > 1e-9, let best = score.firstIndex(of: top) else { return nil }
        guard top >= peakRatio * score.sorted()[count / 2] else { return nil }

        func isNote(_ index: Int) -> Bool {
            guard score[index] >= minimumShare * after.totalPower else { return false }
            var between: Float = 0
            var onHarmonics: Float = 0
            for number in 0..<(harmonics - 1) {
                between += max(0, after.betweenPowers[index][number] - before.betweenPowers[index][number]) / Float(number + 1)
                onHarmonics += gains[index][number] / Float(number + 1)
            }
            return onHarmonics >= harmonicRatio * between
        }

        if let expected, notes.contains(expected) {
            let index = expected - notes.lowerBound
            if score[index] >= expectedShare * top, fresh[index] >= freshExpected, isNote(index) {
                return expected
            }
        }
        guard fresh[best] >= freshOther, isNote(best) else { return nil }
        let midi = notes.lowerBound + best
        // Low notes reach a phone's microphone mostly through their second harmonic
        let lowest = gains[best][0] + (midi < 48 ? gains[best][1] : 0)
        guard lowest >= fundamentalShare * gains[best].reduce(0, +) else { return nil }
        return midi
    }

    /// The energy of a note's harmonics in a short window, to notice the moment it starts while others ring.
    static func energy(of midi: Int, in samples: [Float], sampleRate: Double) -> Float {
        var window = [Float](repeating: 0, count: samples.count)
        vDSP_hann_window(&window, vDSP_Length(samples.count), Int32(vDSP_HANN_DENORM))
        var shaped = [Float](repeating: 0, count: samples.count)
        vDSP_vmul(samples, 1, window, 1, &shaped, 1, vDSP_Length(samples.count))
        let fundamental = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
        var total: Float = 0
        for number in 1...harmonics {
            let n = Double(number)
            let frequency = n * fundamental * (1 + 0.0004 * n * n).squareRoot()
            guard frequency < sampleRate / 2 * 0.98 else { break }
            total += [0.99, 1.0, 1.01].map { ChordMatcher.goertzel(shaped, frequency: frequency * $0, sampleRate: sampleRate) }.max() ?? 0
        }
        return total
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

    static func goertzel(_ samples: [Float], frequency: Double, sampleRate: Double) -> Float {
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

/// Slices microphone audio into short hops and reports each key struck, once.
///
/// When the exercise says which note it wants, that note's own harmonics are watched too, so its strike is caught
/// even in a room full of ringing notes; a strike is then read by what it added to the sound (`StrikeAnalyzer`).
/// Without an expected note (Modo Estudo), a soft note heard without a strike is still read by its pitch.
struct MicrophoneNoteReader {
    let sampleRate: Double
    private(set) var level: Float = 0

    /// The notes the exercise wants now: one note is listened for by itself, several must sound together
    var expectedNotes: Set<Int>? {
        didSet {
            guard expectedNotes != oldValue else { return }
            chordCountdown = nil
            watchHistory.removeAll()
        }
    }
    /// How many strikes didn't have every note of the expected chord
    private(set) var missedChords = 0

    private var expectedChord: Set<Int>? { (expectedNotes?.count ?? 0) > 1 ? expectedNotes : nil }
    private var expectedNote: Int? { expectedNotes?.count == 1 ? expectedNotes?.first : nil }

    private let hopSize = 1024
    private let windowSize = 4096
    /// Enough to tell apart notes a semitone from each other, read once the attack has passed
    private let chordWindowSize = 8192
    private let chordWaitHops = 9
    /// Hops after a strike before reading it, so the window holds only sound from after the hammer
    private let settleHops = 4
    /// A new strike counts this many hops after the last one at the earliest
    private let refractoryHops = 5
    /// The expected note's energy rising this many times over its recent low is its strike
    private let watchRise: Float = 4
    private let watchWindowSize = 2048
    /// Pitch readings less periodic than this are noise, or several notes at once
    private let minimumClarity = 0.7
    /// Hops a different pitch must hold, with no strike heard, to count as a new note
    private let changeFrames = 4

    private var pending: [Float] = []
    private var window: [Float] = []
    private var lastSample: Float = 0
    private var tracker = NoteOnsetTracker()
    private var chordCountdown: Int?
    private var hopsSinceStrike = 1_000
    /// A strike waiting to be read: the sound before it, and how it was noticed
    private var strike: (before: [Float], hops: Int, byWatch: Bool)?
    private var watchHistory: [Float] = []
    /// The last note reported, while it still sounds
    private var soundingNote: Int?
    private var candidate: Int?
    private var candidateFrames = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    mutating func reset() {
        pending.removeAll(keepingCapacity: true)
        window.removeAll(keepingCapacity: true)
        lastSample = 0
        tracker.reset()
        chordCountdown = nil
        hopsSinceStrike = 1_000
        strike = nil
        watchHistory.removeAll()
        soundingNote = nil
        candidate = nil
        candidateFrames = 0
        level = 0
    }

    /// Takes the next samples of any length and returns the notes struck in them, in order.
    mutating func read(_ samples: UnsafeBufferPointer<Float>) -> [Int] {
        pending.append(contentsOf: samples)
        var notes: [Int] = []
        var start = 0
        while pending.count - start >= hopSize {
            let hop = Array(pending[start..<(start + hopSize)])
            start += hopSize
            notes += process(hop)
        }
        pending.removeFirst(start)
        return notes
    }

    private mutating func process(_ hop: [Float]) -> [Int] {
        var rms: Float = 0
        vDSP_rmsqv(hop, 1, &rms, vDSP_Length(hop.count))
        level = rms
        let brightness = Self.brightness(of: hop, after: lastSample)
        lastSample = hop[hop.count - 1]
        let before = strike == nil ? Array(window.suffix(windowSize)) : []
        window.append(contentsOf: hop)
        if window.count > chordWindowSize {
            window.removeFirst(window.count - chordWindowSize)
        }
        hopsSinceStrike += 1

        var struck = tracker.isStrike(NoteOnsetTracker.Frame(level: rms, brightness: brightness))
        let isLoud = rms >= tracker.noiseGate
        var byWatch = false
        if let expected = expectedNote, window.count >= watchWindowSize {
            let energy = StrikeAnalyzer.energy(of: expected, in: Array(window.suffix(watchWindowSize)), sampleRate: sampleRate)
            if !struck, isLoud, watchHistory.count >= 3, let low = watchHistory.suffix(6).min(),
               energy > low * watchRise, energy > 1e-6 {
                struck = true
                byWatch = true
            }
            watchHistory.append(energy)
            if watchHistory.count > 12 {
                watchHistory.removeFirst()
            }
        }

        if let chord = expectedChord {
            return readChord(chord, struck: struck)
        }

        if struck, strike == nil, hopsSinceStrike >= refractoryHops {
            hopsSinceStrike = 0
            let padding = [Float](repeating: 0, count: windowSize - before.count)
            strike = (before: padding + before, hops: 0, byWatch: byWatch)
            return []
        }
        if var waiting = strike {
            waiting.hops += 1
            guard waiting.hops >= settleHops else {
                strike = waiting
                return []
            }
            strike = nil
            let expected = expectedNote
            var note = StrikeAnalyzer.struckNote(
                before: StrikeAnalyzer.spectrum(of: waiting.before, sampleRate: sampleRate),
                after: StrikeAnalyzer.spectrum(of: Array(window.suffix(windowSize)), sampleRate: sampleRate),
                expected: expected
            )
            // The watch only listens for the expected note
            if waiting.byWatch, note != expected {
                note = nil
            }
            guard let note else { return [] }
            soundingNote = note
            candidate = nil
            candidateFrames = 0
            return [note]
        }

        guard isLoud else {
            if tracker.envelope < tracker.noiseGate {
                soundingNote = nil
            }
            candidate = nil
            candidateFrames = 0
            return []
        }
        guard expectedNote == nil, window.count >= windowSize,
              let estimate = PitchDetector.estimate(samples: Array(window.suffix(windowSize)), sampleRate: sampleRate),
              estimate.clarity >= minimumClarity, (21...108).contains(estimate.midiNote),
              estimate.midiNote != soundingNote else {
            candidate = nil
            candidateFrames = 0
            return []
        }
        // No note expected: a soft note over a loud one, heard by its pitch without a strike
        let note = estimate.midiNote
        if note == candidate {
            candidateFrames += 1
        } else {
            candidate = note
            candidateFrames = 1
        }
        guard candidateFrames >= changeFrames else { return [] }
        candidate = nil
        candidateFrames = 0
        soundingNote = note
        return [note]
    }

    /// Waits for the attack of a strike to pass, then checks that every expected note is sounding.
    private mutating func readChord(_ chord: Set<Int>, struck: Bool) -> [Int] {
        if struck {
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

    /// The level of the hop's first difference: high frequencies, where a hammer's attack shows.
    private static func brightness(of hop: [Float], after previous: Float) -> Float {
        var sum: Float = 0
        var last = previous
        for sample in hop {
            let difference = sample - last
            sum += difference * difference
            last = sample
        }
        return (sum / Float(max(1, hop.count))).squareRoot()
    }
}
