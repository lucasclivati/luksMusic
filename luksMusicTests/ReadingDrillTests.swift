// ReadingDrillTests.swift
// luksMusicTests
//
// The sight-reading drill's rules: steps of one hand, checking key presses, printed accidentals, note names for
// scores without them, and the keyboard window.

import XCTest
@testable import luksMusic

final class ReadingDrillTests: XCTestCase {

    private func note(_ name: NoteName, _ octave: Int, _ accidental: Accidental = .natural, beat: Double,
                      staff: Staff = .treble, duration: NoteDuration = .quarter, rest: Bool = false,
                      tieContinuation: Bool? = nil) -> Note {
        Note(pitch: Pitch(noteName: name, octave: octave, accidental: accidental), duration: duration, isRest: rest,
             staff: staff, position: NotePosition(beat: beat), isTieContinuation: tieContinuation)
    }

    // MARK: Steps

    func testStepsGroupChordsAndSkipRestsTiesAndTheOtherHand() {
        let measures = [
            Measure(number: 0, notes: [
                note(.E, 5, beat: 1),
            ], length: 1),
            Measure(number: 1, notes: [
                note(.G, 4, beat: 1), note(.C, 5, beat: 1), note(.E, 5, beat: 1),
                note(.C, 3, beat: 1, staff: .bass),
                note(.C, 5, beat: 2, rest: true),
                note(.E, 5, beat: 3, tieContinuation: true),
                note(.D, 5, beat: 4),
            ]),
        ]
        let right = ReadingDrill.steps(in: measures, hand: .right, timeSignatureTop: 4, beatUnit: 4)
        XCTAssertEqual(right.map(\.midiNotes), [[76], [67, 72, 76], [74]])
        // Measures numbered 0 (pickups, older data) count from their position, as in the exporter
        XCTAssertEqual(right.map(\.measureNumber), [1, 1, 1])
        // The pickup lasts one beat, so the next measure starts on beat 1 of the piece
        XCTAssertEqual(right.map(\.globalBeat), [0, 1, 4])
        XCTAssertEqual(right[1].notes.map(\.midiNote), [67, 72, 76], "lowest first")

        let left = ReadingDrill.steps(in: measures, hand: .left, timeSignatureTop: 4, beatUnit: 4)
        XCTAssertEqual(left.map(\.midiNotes), [[48]])
    }

    func testFurEliseRightHandOpensWithEDSharpE() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "fur-elise", withExtension: "musicxml"))
        let score = try MusicXMLParser.parse(url: url)
        let steps = ReadingDrill.steps(in: score.measures, hand: .right, timeSignatureTop: score.timeSignatureTop,
                                       beatUnit: score.timeSignatureBottom)
        XCTAssertEqual(steps.prefix(3).map(\.midiNotes), [[76], [75], [76]])
        let printed = ReadingDrill.printedAccidentals(for: Array(steps.prefix(3)), keySignature: score.keySignatureValue)
        XCTAssertEqual(printed, [[nil], [.sharp], [nil]])
        XCTAssertFalse(ReadingDrill.steps(in: score.measures, hand: .left, timeSignatureTop: score.timeSignatureTop,
                                          beatUnit: score.timeSignatureBottom).isEmpty)
    }

    // MARK: Pressing Keys

    func testWrongKeysCountUntilTheRightOneAndChordsTakeAnyOrder() {
        let steps = ReadingDrill.steps(in: [Measure(number: 1, notes: [
            note(.E, 5, beat: 1),
            note(.C, 5, beat: 2), note(.E, 5, beat: 2),
            note(.A, 4, beat: 3),
        ])], hand: .right, timeSignatureTop: 4, beatUnit: 4)
        var state = ReadingSegmentState(steps: steps)
        var outcomes: [ReadingPress] = []
        for key in [76, 77, 76, 76, 72] {
            outcomes.append(state.press(key))
        }
        XCTAssertEqual(outcomes, [.correct(stepDone: true), .wrong, .correct(stepDone: false),
                                  .ignored, .correct(stepDone: true)], "E5; a wrong F5; the chord's keys in any order")
        state.reveal()
        let last = state.press(69)
        XCTAssertEqual(last, .correct(stepDone: true))
        XCTAssertTrue(state.isComplete)
        let afterEnd = state.press(69)
        XCTAssertEqual(afterEnd, .ignored)

        XCTAssertEqual(state.results.map(\.isClean), [true, false, false])
        XCTAssertEqual(state.results[1].mistakes, 1)
        XCTAssertTrue(state.results[2].revealed)
        XCTAssertEqual(state.cleanCount, 1)
    }

    // MARK: Segments

    func testSequentialSegmentsAndRandomStarts() {
        XCTAssertEqual(ReadingDrill.segmentCount(stepCount: 10, size: 3), 4)
        XCTAssertEqual(ReadingDrill.segment(startingAt: 9, size: 3, stepCount: 10), 9..<10)
        XCTAssertEqual(ReadingDrill.segment(startingAt: 3, size: 3, stepCount: 10), 3..<6)

        var generator = SeededGenerator(seed: 7)
        var previous: Int? = nil
        for _ in 0..<200 {
            let start = ReadingDrill.randomStart(stepCount: 10, size: 3, avoiding: previous, using: &generator)
            XCTAssertTrue((0...7).contains(start))
            XCTAssertNotEqual(start, previous)
            previous = start
        }
        XCTAssertEqual(ReadingDrill.randomStart(stepCount: 2, size: 3, avoiding: 0, using: &generator), 0)
    }

    // MARK: Accidentals and Names

    func testAccidentalsArePrintedAgainstTheKeySignatureAndCarryThroughTheMeasure() {
        // G major: F♯ comes from the key; F natural needs ♮ once per measure; C♯ needs ♯
        let measures = [
            Measure(number: 1, notes: [
                note(.F, 5, .sharp, beat: 1), note(.F, 5, beat: 2), note(.F, 5, beat: 3), note(.C, 5, .sharp, beat: 4),
            ]),
            Measure(number: 2, notes: [note(.F, 5, .sharp, beat: 1), note(.F, 5, beat: 2)]),
        ]
        let steps = ReadingDrill.steps(in: measures, hand: .right, timeSignatureTop: 4, beatUnit: 4)
        XCTAssertEqual(ReadingDrill.printedAccidentals(for: steps, keySignature: 1),
                       [[nil], [.natural], [nil], [.sharp], [nil], [.natural]])
        // F major: B♭ from the key
        XCTAssertEqual(ReadingDrill.keyAlteration(of: .B, keySignature: -1), -1)
        XCTAssertEqual(ReadingDrill.keyAlteration(of: .E, keySignature: -1), 0)
        XCTAssertEqual(ReadingDrill.keyAlteration(of: .C, keySignature: 2), 1)
    }

    func testNotesWithOnlyMIDINumbersAreNamedForTheirKey() {
        func spelled(_ midi: Int, _ key: Int) -> String {
            ReadingDrill.name(of: ReadingDrill.spelledPitch(midi: midi, keySignature: key))
        }
        XCTAssertEqual(spelled(66, 1), "Fá♯4")
        XCTAssertEqual(spelled(66, -1), "Sol♭4")
        XCTAssertEqual(spelled(70, 0), "Si♭4")
        XCTAssertEqual(spelled(61, 0), "Dó♯4")
        XCTAssertEqual(spelled(63, 2), "Ré♯4")
        XCTAssertEqual(spelled(60, 0), "Dó4")
        // C♭ belongs to the octave above the B it sounds as
        XCTAssertEqual(ReadingDrill.spelledPitch(midi: 71, keySignature: -7).displayName, "C♭5")
        XCTAssertEqual(ReadingDrill.spelledPitch(midi: 71, keySignature: -7).midiNoteNumber, 71)
        XCTAssertEqual(ReadingDrill.spelledPitch(midi: 72, keySignature: 7).displayName, "B♯4")

        let gMajor = [67, 69, 71, 72, 74, 76, 78, 79, 78, 74]
        XCTAssertEqual(ReadingDrill.estimatedKeySignature(midiNotes: gMajor), 1)
        let fMajor = [65, 67, 69, 70, 72, 74, 76, 77, 70, 70]
        XCTAssertEqual(ReadingDrill.estimatedKeySignature(midiNotes: fMajor), -1)
        XCTAssertEqual(ReadingDrill.estimatedKeySignature(midiNotes: [60, 62, 64, 65, 67, 69, 71]), 0)
        XCTAssertEqual(ReadingDrill.estimatedKeySignature(midiNotes: []), 0)

        let renamed = ReadingDrill.respelled([Measure(number: 1, notes: gMajor.enumerated().map { index, midi in
            Note(pitch: Pitch(noteName: .G, octave: 4).withMIDI(midi), position: NotePosition(beat: Double(index % 4) + 1))
        })])
        XCTAssertEqual(renamed.keySignature, 1)
        XCTAssertEqual(renamed.measures[0].notes[6].pitch.displayName, "F♯5")
        XCTAssertEqual(renamed.measures[0].notes.map { Int($0.midiNote) }, gMajor)

        let chord = ReadingDrill.steps(in: [Measure(number: 1, notes: [note(.C, 5, beat: 1), note(.E, 5, .flat, beat: 1)])],
                                       hand: .right, timeSignatureTop: 4, beatUnit: 4)[0]
        XCTAssertEqual(ReadingDrill.name(of: chord), "Mi♭5 · Dó5")
    }

    // MARK: Keyboard Window

    func testKeyboardShowsTheWholeHandWhenItFits() {
        let range = ReadingDrill.keyboardRange(segment: 64...67, hand: 60...76, whiteKeys: 15, current: nil)
        XCTAssertEqual(range, 57...81)
        XCTAssertEqual(ReadingDrill.whiteCount(range.lowerBound, range.upperBound), 15)
    }

    func testKeyboardFollowsTheSegmentWhenTheHandIsWider() {
        let first = ReadingDrill.keyboardRange(segment: 74...76, hand: 40...90, whiteKeys: 15, current: nil)
        XCTAssertEqual(first, 60...84, "starts on the C that centers the segment best")

        // Stays put while the next segment fits
        XCTAssertEqual(ReadingDrill.keyboardRange(segment: 79...83, hand: 40...90, whiteKeys: 15, current: first), first)

        let moved = ReadingDrill.keyboardRange(segment: 86...88, hand: 40...90, whiteKeys: 15, current: first)
        XCTAssertTrue(moved.contains(86) && moved.contains(88))
        XCTAssertEqual(ReadingDrill.whiteCount(moved.lowerBound, moved.upperBound), 15)
        XCTAssertTrue(ReadingDrill.isWhite(moved.lowerBound) && ReadingDrill.isWhite(moved.upperBound))

        // A segment wider than the screen gets every key it needs
        XCTAssertEqual(ReadingDrill.keyboardRange(segment: 36...84, hand: 30...90, whiteKeys: 15, current: nil), 36...84)

        // Never past the piano's last key
        let top = ReadingDrill.keyboardRange(segment: 105...108, hand: 40...108, whiteKeys: 15, current: nil)
        XCTAssertEqual(top.upperBound, 108)
        XCTAssertEqual(ReadingDrill.whiteCount(top.lowerBound, top.upperBound), 15)
    }
}

/// Reproducible random numbers for the random segments (SplitMix64).
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private extension Pitch {
    /// Any pitch with this MIDI number (the drill renames it).
    func withMIDI(_ midi: Int) -> Pitch {
        let names: [(NoteName, Accidental)] = [
            (.C, .natural), (.C, .sharp), (.D, .natural), (.D, .sharp), (.E, .natural), (.F, .natural),
            (.F, .sharp), (.G, .natural), (.G, .sharp), (.A, .natural), (.A, .sharp), (.B, .natural)
        ]
        let (name, accidental) = names[midi % 12]
        return Pitch(noteName: name, octave: midi / 12 - 1, accidental: accidental)
    }
}
