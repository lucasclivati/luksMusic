// TunerTests.swift
// luksMusicTests
//
// The tuner: frequency to note and cents at different reference A's, the guitar's strings, and the pitch tracker
// against synthetic tones (pure sines, plucked strings with harmonics, piano bass with a weak fundamental, room
// noise), fed in hops as the microphone delivers them.

import XCTest
@testable import luksMusic

final class TunerTests: XCTestCase {

    private let sampleRate = 48_000.0

    // MARK: - Frequency to note

    func testFrequencyOfNotes() {
        XCTAssertEqual(Tuning.frequency(ofMidi: 69), 440, accuracy: 1e-9)
        XCTAssertEqual(Tuning.frequency(ofMidi: 57), 220, accuracy: 1e-9)
        XCTAssertEqual(Tuning.frequency(ofMidi: 21), 27.5, accuracy: 1e-9)
        XCTAssertEqual(Tuning.frequency(ofMidi: 108), 4186.009, accuracy: 0.001)
        XCTAssertEqual(Tuning.frequency(ofMidi: 40), 82.407, accuracy: 0.001)
        XCTAssertEqual(Tuning.frequency(ofMidi: 69, a4: 432), 432, accuracy: 1e-9)
        XCTAssertEqual(Tuning.frequency(ofMidi: 81, a4: 415), 830, accuracy: 1e-9)
    }

    func testCents() {
        XCTAssertEqual(Tuning.cents(from: 440, to: 880), 1200, accuracy: 1e-9)
        XCTAssertEqual(Tuning.cents(from: 440, to: Tuning.frequency(ofMidi: 70)), 100, accuracy: 1e-9)
        XCTAssertEqual(Tuning.cents(from: 440, to: 445), 19.56, accuracy: 0.01)
        XCTAssertEqual(Tuning.cents(from: 440, to: 435), -19.79, accuracy: 0.01)
    }

    func testNearestNote() throws {
        let a4 = try XCTUnwrap(Tuning.nearestNote(to: 440))
        XCTAssertEqual(a4.midi, 69)
        XCTAssertEqual(a4.cents, 0, accuracy: 1e-9)
        XCTAssertTrue(a4.isInTune)

        let sharp = try XCTUnwrap(Tuning.nearestNote(to: 445))
        XCTAssertEqual(sharp.midi, 69)
        XCTAssertEqual(sharp.cents, 19.56, accuracy: 0.01)
        XCTAssertTrue(sharp.isSharp)
        XCTAssertEqual(sharp.targetFrequency, 440, accuracy: 1e-9)

        // Just under halfway to A♯4 is still A4, just over is A♯4
        XCTAssertEqual(Tuning.nearestNote(to: 440 * pow(2, 49.0 / 1200))?.midi, 69)
        XCTAssertEqual(Tuning.nearestNote(to: 440 * pow(2, 51.0 / 1200))?.midi, 70)
        XCTAssertEqual(Tuning.nearestNote(to: 440 * pow(2, 51.0 / 1200))?.cents ?? 0, -49, accuracy: 1e-6)

        // The piano's ends, and nothing beyond them
        XCTAssertEqual(Tuning.nearestNote(to: 27.5)?.midi, 21)
        XCTAssertEqual(Tuning.nearestNote(to: 4186.01)?.midi, 108)
        XCTAssertEqual(Tuning.nearestNote(to: 82.41)?.midi, 40)
        XCTAssertNil(Tuning.nearestNote(to: 20))
        XCTAssertNil(Tuning.nearestNote(to: 5000))
        XCTAssertNil(Tuning.nearestNote(to: 0))
        XCTAssertNil(Tuning.nearestNote(to: -10))
        XCTAssertNil(Tuning.nearestNote(to: .nan))
    }

    func testReferenceA() throws {
        // At A4 = 415 (baroque), 415 Hz is an A in tune and 440 Hz is about a semitone up
        let baroque = try XCTUnwrap(Tuning.nearestNote(to: 415, a4: 415))
        XCTAssertEqual(baroque.midi, 69)
        XCTAssertEqual(baroque.cents, 0, accuracy: 1e-9)
        let modern = try XCTUnwrap(Tuning.nearestNote(to: 440, a4: 415))
        XCTAssertEqual(modern.midi, 70)
        XCTAssertEqual(modern.cents, 1.27, accuracy: 0.01)
        // At A4 = 442, a 440 Hz A is 8 cents flat
        let orchestra = try XCTUnwrap(Tuning.nearestNote(to: 440, a4: 442))
        XCTAssertEqual(orchestra.midi, 69)
        XCTAssertEqual(orchestra.cents, -7.85, accuracy: 0.01)
        XCTAssertTrue(orchestra.isFlat)

        XCTAssertEqual(Tuning.clampedA4(500), 466)
        XCTAssertEqual(Tuning.clampedA4(400), 415)
        XCTAssertEqual(Tuning.clampedA4(441.4), 441)
    }

    func testInTuneBand() {
        func reading(_ cents: Double) -> TuningReading {
            TuningReading(midi: 69, cents: cents, frequency: 440 * pow(2, cents / 1200), targetFrequency: 440)
        }
        XCTAssertTrue(reading(5).isInTune)
        XCTAssertTrue(reading(-5).isInTune)
        XCTAssertFalse(reading(5.1).isInTune)
        XCTAssertTrue(reading(5.1).isSharp)
        XCTAssertTrue(reading(-5.1).isFlat)
        XCTAssertFalse(reading(0).isFlat)
        XCTAssertFalse(reading(0).isSharp)
    }

    func testGuitarStrings() throws {
        XCTAssertEqual(Tuning.guitarStrings.map { Tuning.noteName($0, letters: true) + "\(Tuning.octave($0))" },
                       ["E2", "A2", "D3", "G3", "B3", "E4"])
        XCTAssertEqual(Tuning.guitarStrings.map { Tuning.noteName($0, letters: false) }, ["Mi", "Lá", "Ré", "Sol", "Si", "Mi"])

        XCTAssertEqual(Tuning.nearestGuitarString(to: 82.41), 0)
        XCTAssertEqual(Tuning.nearestGuitarString(to: 104), 1) // closer to A2 than to E2
        XCTAssertEqual(Tuning.nearestGuitarString(to: 146.8), 2)
        XCTAssertEqual(Tuning.nearestGuitarString(to: 190), 3)
        XCTAssertEqual(Tuning.nearestGuitarString(to: 250), 4)
        XCTAssertEqual(Tuning.nearestGuitarString(to: 330), 5)
        XCTAssertEqual(Tuning.nearestGuitarString(to: 600), 5)
        XCTAssertNil(Tuning.nearestGuitarString(to: 0))

        // A2 a little flat: tighten
        let flat = try XCTUnwrap(Tuning.reading(for: 108, string: 1))
        XCTAssertEqual(flat.midi, 45)
        XCTAssertEqual(flat.cents, -31.77, accuracy: 0.01)
        XCTAssertTrue(flat.isFlat)
        // A string picked by hand is compared even from far away (low E tuned a fourth up toward A)
        let far = try XCTUnwrap(Tuning.reading(for: 110, string: 0))
        XCTAssertEqual(far.cents, 500, accuracy: 0.01)
        XCTAssertNil(Tuning.reading(for: 110, string: 6))
    }

    func testNoteNamesAndOctaves() {
        XCTAssertEqual(Tuning.noteName(60, letters: true), "C")
        XCTAssertEqual(Tuning.noteName(60, letters: false), "Dó")
        XCTAssertEqual(Tuning.noteName(61, letters: true), "C♯")
        XCTAssertEqual(Tuning.noteName(70, letters: false), "Lá♯")
        XCTAssertEqual(Tuning.octave(60), 4)
        XCTAssertEqual(Tuning.octave(59), 3)
        XCTAssertEqual(Tuning.octave(21), 0)
        XCTAssertEqual(Tuning.octave(108), 8)
    }

    // MARK: - Pitch of one window

    func testDetectorOnGuitarStrings() throws {
        let profiles: [[Float]] = [
            [1], // a pure sine
            [1, 0.7, 0.45, 0.3, 0.2, 0.12, 0.08, 0.05], // a plucked string
            [0.15, 1, 0.8, 0.6, 0.4, 0.3, 0.2], // a weak fundamental, as from a small speaker or a far microphone
        ]
        for midi in Tuning.guitarStrings {
            for profile in profiles {
                // Past the 4 ms attack, which isn't periodic yet
                let window = Array(tone(frequency: Tuning.frequency(ofMidi: midi), seconds: 0.2, harmonics: profile)[2400..<6496])
                let estimate = try XCTUnwrap(PitchDetector.estimate(samples: window, sampleRate: sampleRate, lowest: 60, highest: 1400),
                                             "MIDI \(midi), \(profile.count) harmonics")
                XCTAssertEqual(Tuning.cents(from: Tuning.frequency(ofMidi: midi), to: estimate.frequency), 0, accuracy: 1,
                               "MIDI \(midi), \(profile.count) harmonics")
                XCTAssertGreaterThan(estimate.clarity, 0.9)
            }
        }
    }

    func testDetectorOnThePianoRange() throws {
        // The low keys' fundamental is weak (most of their sound is in the harmonics); the top keys are nearly sines
        for midi in [21, 24, 28, 33, 40, 48, 60, 69, 84, 96, 108] {
            let profile: [Float] = midi < 45 ? [0.1, 0.5, 1, 0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2] : [1, 0.3, 0.1]
            let window = Array(tone(frequency: Tuning.frequency(ofMidi: midi), seconds: 0.25, harmonics: profile)[2400..<10592])
            let estimate = try XCTUnwrap(PitchDetector.estimate(samples: window, sampleRate: sampleRate, lowest: 26, highest: 4300),
                                         "MIDI \(midi)")
            XCTAssertEqual(Tuning.nearestNote(to: estimate.frequency)?.midi, midi)
            XCTAssertEqual(Tuning.cents(from: Tuning.frequency(ofMidi: midi), to: estimate.frequency), 0, accuracy: 2, "MIDI \(midi)")
        }
    }

    // MARK: - Tracking a ringing note

    func testTrackerHoldsPluckedStringsSteady() {
        for midi in Tuning.guitarStrings {
            let target = Tuning.frequency(ofMidi: midi)
            let audio = silence(seconds: 0.3) + tone(frequency: target, seconds: 2.5, stretch: 0.00005, decaying: true, seed: UInt64(midi))
            let readings = track(audio, mode: .guitar)
            let ringing = readings.filter { $0.time > 0.6 && $0.time < 2.8 }
            XCTAssertFalse(ringing.isEmpty)
            // Never a gap while the string rings, and never more than a cent off
            XCTAssertTrue(ringing.allSatisfy { $0.frequency != nil }, "MIDI \(midi): lost the note while it rang")
            let worst = ringing.compactMap { $0.frequency }.map { abs(Tuning.cents(from: target, to: $0)) }.max() ?? .infinity
            XCTAssertLessThan(worst, 1, "MIDI \(midi)")
            // And the needle is up within a quarter second of the pluck
            let first = readings.first { $0.frequency != nil }?.time ?? .infinity
            XCTAssertLessThan(first, 0.3 + 0.25, "MIDI \(midi)")
        }
    }

    func testTrackerReadsAnOutOfTuneString() throws {
        // Low E 20 cents flat in a noisy room, A2 13 cents sharp, high E 35 cents flat
        for (midi, detune) in [(40, -20.0), (45, 13.0), (64, -35.0)] {
            let target = Tuning.frequency(ofMidi: midi)
            let audio = silence(seconds: 0.3)
                + tone(frequency: target * pow(2, detune / 1200), seconds: 2, decaying: true, noise: 0.006, seed: 7)
            let readings = track(audio, mode: .guitar).filter { $0.time > 0.6 && $0.time < 1.8 }
            let cents = readings.compactMap { $0.frequency }.map { Tuning.cents(from: target, to: $0) }
            XCTAssertEqual(cents.count, readings.count, "MIDI \(midi)")
            for value in cents {
                XCTAssertEqual(value, detune, accuracy: 2, "MIDI \(midi)")
            }
            let index = try XCTUnwrap(Tuning.nearestGuitarString(to: target * pow(2, detune / 1200)))
            XCTAssertEqual(Tuning.guitarStrings[index], midi)
        }
    }

    func testTrackerFollowsThePianoBass() {
        for midi in [21, 28, 33, 48, 60, 72, 84, 96, 108] {
            let target = Tuning.frequency(ofMidi: midi)
            let profile: [Float] = midi < 45 ? [0.15, 0.6, 1, 0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2] : [1, 0.5, 0.3, 0.2, 0.1]
            let audio = silence(seconds: 0.3) + tone(frequency: target, seconds: 2.5, harmonics: profile, decaying: true, slowFade: true, seed: UInt64(midi))
            let ringing = track(audio, mode: .piano).filter { $0.time > 0.8 && $0.time < 2.8 }
            XCTAssertTrue(ringing.allSatisfy { $0.frequency != nil }, "MIDI \(midi): lost the note while it rang")
            for frequency in ringing.compactMap({ $0.frequency }) {
                XCTAssertEqual(Tuning.nearestNote(to: frequency)?.midi, midi)
                XCTAssertEqual(Tuning.cents(from: target, to: frequency), 0, accuracy: 1.5, "MIDI \(midi)")
            }
        }
    }

    func testTrackerIgnoresSilence() {
        XCTAssertTrue(track(silence(seconds: 2), mode: .guitar).allSatisfy { $0.frequency == nil })
        XCTAssertTrue(track(silence(seconds: 2), mode: .piano).allSatisfy { $0.frequency == nil })
    }

    func testTrackerHoldsThenClearsAfterTheNoteStops() {
        let audio = silence(seconds: 0.3) + tone(frequency: 110, seconds: 1, seed: 3) + silence(seconds: 2.5, seed: 4)
        let readings = track(audio, mode: .guitar)
        // Still on screen a moment after the sound stops, gone well before the end
        XCTAssertNotNil(readings.last { $0.time < 1.6 }?.frequency)
        let lastShown = readings.last { $0.frequency != nil }?.time ?? 0
        XCTAssertGreaterThan(lastShown, 1.3 + 0.8)
        XCTAssertLessThan(lastShown, 1.3 + 1.6)
        XCTAssertNil(readings.last?.frequency)
    }

    func testTrackerMovesToTheNextString() {
        // Low E, then A2 plucked straight after: the reading jumps to A2 instead of gliding through the notes between
        let audio = silence(seconds: 0.3) + tone(frequency: Tuning.frequency(ofMidi: 40), seconds: 1, seed: 3)
            + tone(frequency: Tuning.frequency(ofMidi: 45), seconds: 1.5, seed: 4)
        let readings = track(audio, mode: .guitar)
        let afterSwitch = readings.filter { $0.time > 1.3 }.compactMap { $0.frequency }
        let between = afterSwitch.filter { frequency in
            let toE = abs(Tuning.cents(from: Tuning.frequency(ofMidi: 40), to: frequency))
            let toA = abs(Tuning.cents(from: Tuning.frequency(ofMidi: 45), to: frequency))
            return toE > 10 && toA > 10
        }
        XCTAssertTrue(between.isEmpty, "Readings between the two strings: \(between)")
        let settled = readings.filter { $0.time > 1.3 + 0.3 }.compactMap { $0.frequency }
        XCTAssertFalse(settled.isEmpty)
        for frequency in settled {
            XCTAssertEqual(Tuning.cents(from: Tuning.frequency(ofMidi: 45), to: frequency), 0, accuracy: 1)
        }
    }

    func testTrackerWorksWithAnyHopSize() {
        // The microphone's buffers are not always the size asked for
        for hop in [1024, 4800] {
            let target = Tuning.frequency(ofMidi: 40)
            let audio = silence(seconds: 0.3) + tone(frequency: target, seconds: 2, decaying: true, seed: 5)
            let ringing = track(audio, mode: .guitar, hop: hop).filter { $0.time > 0.7 && $0.time < 2.2 }
            XCTAssertFalse(ringing.isEmpty)
            for frequency in ringing.map({ $0.frequency }) {
                XCTAssertEqual(Tuning.cents(from: target, to: frequency ?? 0), 0, accuracy: 1, "hop \(hop)")
            }
        }
    }

    // MARK: - Synthetic audio

    /// A tone with `harmonics` (weights from the fundamental up), optionally stretched as on real strings and fading
    /// as a plucked or struck one, the upper harmonics faster; with a little room noise.
    private func tone(frequency: Double, seconds: Double, harmonics: [Float] = [1, 0.7, 0.45, 0.3, 0.2, 0.12, 0.08, 0.05],
                      stretch: Double = 0, decaying: Bool = false, slowFade: Bool = false,
                      noise: Float = 0.0015, seed: UInt64 = 1) -> [Float] {
        let count = Int(seconds * sampleRate)
        var generator = TunerNoise(state: seed &* 2_654_435_761 &+ 1)
        let partials: [(frequency: Double, weight: Double, fade: Double)] = harmonics.enumerated().compactMap { index, weight in
            let n = Double(index + 1)
            let partial = n * frequency * (1 + stretch * n * n).squareRoot()
            guard partial < sampleRate / 2 else { return nil }
            let fade = decaying ? (slowFade ? 0.5 + 0.3 * n : 1.2 + 0.7 * n) : 0
            return (partial, Double(weight), fade)
        }
        return (0..<count).map { index in
            let t = Double(index) / sampleRate
            var sample = 0.0
            for partial in partials {
                sample += partial.weight * exp(-t * partial.fade) * sin(2 * .pi * partial.frequency * t)
            }
            let attack = min(1, t / 0.004)
            return Float(sample * attack) * 0.25 + generator.next() * noise
        }
    }

    private func silence(seconds: Double, seed: UInt64 = 99) -> [Float] {
        var generator = TunerNoise(state: seed)
        return (0..<Int(seconds * sampleRate)).map { _ in generator.next() * 0.0015 }
    }

    /// The pitch shown after each hop, with the time at the end of that hop.
    private func track(_ audio: [Float], mode: TunerMode, hop: Int = 2048) -> [(time: Double, frequency: Double?)] {
        var tracker = TunerPitchTracker(sampleRate: sampleRate, settings: .init(mode: mode))
        var readings: [(time: Double, frequency: Double?)] = []
        var start = 0
        while start + hop <= audio.count {
            let frequency = tracker.process(audio[start..<start + hop])
            start += hop
            readings.append((Double(start) / sampleRate, frequency))
        }
        return readings
    }
}

private struct TunerNoise {
    var state: UInt64

    mutating func next() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Float(Int32(truncatingIfNeeded: state >> 32)) / Float(Int32.max)
    }
}
