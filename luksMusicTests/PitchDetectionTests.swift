// PitchDetectionTests.swift
// luksMusicTests
//
// The microphone analysis against synthetic piano tones (harmonics that fade at different speeds, stretched
// slightly as on real strings, with a little room noise), and the decoding of USB keyboard messages.

import XCTest
@testable import luksMusic

final class PitchDetectionTests: XCTestCase {

    private let sampleRate = 48_000.0

    private func frequency(_ midi: Int) -> Double {
        440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
    }

    /// A struck string: `amplitudes` per harmonic, the upper ones fading faster.
    private func tone(_ midi: Int, seconds: Double, amplitude: Float = 0.25,
                      harmonics: [Float] = [1, 0.7, 0.45, 0.3, 0.2, 0.12, 0.08, 0.05]) -> [Float] {
        let f0 = frequency(midi)
        let count = Int(seconds * sampleRate)
        var generator = SeededNoise(state: UInt64(midi) &* 2_654_435_761 &+ 1)
        return (0..<count).map { index in
            let t = Double(index) / sampleRate
            var sample = 0.0
            for (h, weight) in harmonics.enumerated() {
                let n = Double(h + 1)
                let stretched = n * f0 * sqrt(1 + 0.0004 * n * n)
                guard stretched < sampleRate / 2 else { continue }
                sample += Double(weight) * exp(-t * (1.2 + 0.7 * n)) * sin(2 * .pi * stretched * t)
            }
            let attack = min(1, t / 0.004)
            return Float(sample * attack) * amplitude + generator.next() * 0.0015
        }
    }

    private func silence(seconds: Double) -> [Float] {
        var generator = SeededNoise(state: 99)
        return (0..<Int(seconds * sampleRate)).map { _ in generator.next() * 0.0015 }
    }

    private func notes(in samples: [Float], chunk: Int = 2048) -> [Int] {
        var reader = MicrophoneNoteReader(sampleRate: sampleRate)
        var result: [Int] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + chunk)
            samples[start..<end].withUnsafeBufferPointer { result += reader.read($0) }
            start = end
        }
        return result
    }

    func testEveryPianoNoteLessonsUseIsReadInTheRightOctave() {
        for midi in 36...96 {
            let window = Array(tone(midi, seconds: 0.25)[2400..<6496])
            let estimate = PitchDetector.estimate(samples: window, sampleRate: sampleRate)
            XCTAssertEqual(estimate?.midiNote, midi, "MIDI \(midi)")
        }
    }

    func testLowNotesWithAWeakFundamentalStayInTheirOctave() {
        for midi in [36, 40, 45, 48] {
            let window = Array(tone(midi, seconds: 0.25, harmonics: [0.15, 1, 0.8, 0.5, 0.3, 0.2])[2400..<6496])
            XCTAssertEqual(PitchDetector.estimate(samples: window, sampleRate: sampleRate)?.midiNote, midi, "MIDI \(midi)")
        }
    }

    func testAHeldNoteCountsOnce() {
        XCTAssertEqual(notes(in: silence(seconds: 0.2) + tone(60, seconds: 1.5)), [60])
    }

    func testTheSameNoteStruckTwiceCountsTwice() {
        let audio = silence(seconds: 0.2) + tone(60, seconds: 0.5) + tone(60, seconds: 0.5)
        XCTAssertEqual(notes(in: audio), [60, 60])
    }

    func testAScaleWithNotesRingingIntoEachOtherIsReadInOrder() {
        let scale = [60, 62, 64, 65, 67, 69, 71, 72]
        for played in [scale, Array(scale.reversed())] {
            // Each note starts 0.45 s after the last and keeps sounding under the next ones
            var audio = silence(seconds: 0.2 + 0.45 * Double(played.count) + 1.2)
            for (index, midi) in played.enumerated() {
                let start = Int((0.2 + 0.45 * Double(index)) * sampleRate)
                for (offset, sample) in tone(midi, seconds: 1.2).enumerated() {
                    audio[start + offset] += sample
                }
            }
            XCTAssertEqual(notes(in: audio), played)
        }
    }

    func testChunkSizeDoesNotChangeTheResult() {
        let audio = silence(seconds: 0.2) + tone(64, seconds: 0.6) + tone(67, seconds: 0.6)
        XCTAssertEqual(notes(in: audio, chunk: 4800), [64, 67])
        XCTAssertEqual(notes(in: audio, chunk: 512), [64, 67])
    }

    func testSilenceAndNoiseAreNotNotes() {
        XCTAssertEqual(notes(in: silence(seconds: 1)), [])
        var generator = SeededNoise(state: 5)
        let hiss = (0..<48_000).map { _ in generator.next() * 0.2 }
        XCTAssertEqual(notes(in: hiss), [])
    }

    private func chord(_ notes: [Int], seconds: Double = 0.7) -> [Float] {
        var audio = silence(seconds: 0.3 + seconds)
        let start = Int(0.2 * sampleRate)
        for midi in notes {
            for (offset, sample) in tone(midi, seconds: seconds, amplitude: 0.15).enumerated() {
                audio[start + offset] += sample
            }
        }
        return audio
    }

    private func readChord(_ audio: [Float], expecting expected: Set<Int>) -> (notes: [Int], missed: Int) {
        var reader = MicrophoneNoteReader(sampleRate: sampleRate)
        reader.expectedChord = expected
        var result: [Int] = []
        var start = 0
        while start < audio.count {
            let end = min(audio.count, start + 2048)
            audio[start..<end].withUnsafeBufferPointer { result += reader.read($0) }
            start = end
        }
        return (result, reader.missedChords)
    }

    func testAChordIsHeardOnlyWhenAllItsNotesSound() {
        let cMajor: Set<Int> = [60, 64, 67]
        XCTAssertEqual(readChord(chord([60, 64, 67]), expecting: cMajor).notes, [60, 64, 67])

        let wrongChord = readChord(chord([65, 69, 72]), expecting: cMajor)
        XCTAssertEqual(wrongChord.notes, [])
        XCTAssertEqual(wrongChord.missed, 1)

        let incomplete = readChord(chord([60, 64]), expecting: cMajor)
        XCTAssertEqual(incomplete.notes, [])
        XCTAssertEqual(incomplete.missed, 1)
    }

    func testUSBKeyboardMessagesAreDecoded() {
        // Universal MIDI Packet words: type 2, group 0, then status/channel, note, velocity
        XCTAssertEqual(MIDIService.messages(in: [0x2090_3C64]), [.noteOn(note: 60, velocity: 100, channel: 0)])
        XCTAssertEqual(MIDIService.messages(in: [0x2080_3C00]), [.noteOff(note: 60, channel: 0)])
        XCTAssertEqual(MIDIService.messages(in: [0x2090_3C00]), [.noteOff(note: 60, channel: 0)], "velocity 0 releases")
        XCTAssertEqual(MIDIService.messages(in: [0x20B0_407F]), [.controlChange(controller: 64, value: 127, channel: 0)])
        // A chord in one packet, with a clock message between the notes
        XCTAssertEqual(MIDIService.messages(in: [0x2090_3C64, 0x10F8_0000, 0x2090_4064]),
                       [.noteOn(note: 60, velocity: 100, channel: 0), .noteOn(note: 64, velocity: 100, channel: 0)])
        // A two-word message's second word is not read as a note
        XCTAssertEqual(MIDIService.messages(in: [0x3001_7E00, 0x2090_3C64]), [])
    }
}

private struct SeededNoise {
    var state: UInt64

    mutating func next() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Float(Int32(truncatingIfNeeded: state >> 32)) / Float(Int32.max)
    }
}
