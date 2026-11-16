// ClefTests.swift
// luksMusicTests
//
// Where each clef writes a pitch, its key signatures, and the clef the reading drill picks by itself.

import XCTest
@testable import luksMusic

final class ClefTests: XCTestCase {

    private func pitch(_ text: String) -> Pitch {
        LessonNotation.pitch(from: text)!
    }

    func testMiddleCInEachClef() {
        XCTAssertEqual(Clef.treble.position(of: pitch("C4")), -6, "first ledger line below")
        XCTAssertEqual(Clef.bass.position(of: pitch("C4")), 6, "first ledger line above")
        XCTAssertEqual(Clef.alto.position(of: pitch("C4")), 0, "the middle line, where the C clef points")
        XCTAssertEqual(Clef.alto.position(of: pitch("F3")), -4, "bottom line")
        XCTAssertEqual(Clef.alto.position(of: pitch("G4")), 4, "top line")
    }

    func testTrebleAndBassAgreeWithTheScoreStaves() {
        for octave in 1...6 {
            for name in NoteName.allCases {
                let pitch = Pitch(noteName: name, octave: octave)
                XCTAssertEqual(Clef.treble.position(of: pitch), Note(pitch: pitch, staff: .treble).staffPosition)
                XCTAssertEqual(Clef.bass.position(of: pitch), Note(pitch: pitch, staff: .bass).staffPosition)
            }
        }
    }

    func testLedgerLines() {
        XCTAssertEqual(Clef.treble.ledgerLines(for: pitch("C4")), 1)
        XCTAssertEqual(Clef.treble.ledgerLines(for: pitch("A3")), 2)
        XCTAssertEqual(Clef.treble.ledgerLines(for: pitch("D4")), 0, "the space below the staff")
        XCTAssertEqual(Clef.bass.ledgerLines(for: pitch("E2")), 1)
        XCTAssertEqual(Clef.alto.ledgerLines(for: pitch("C4")), 0)
        XCTAssertEqual(Clef.alto.ledgerLines(for: pitch("C5")), 1, "above the first ledger line")
        XCTAssertEqual(Clef.alto.ledgerLines(for: pitch("D5")), 2)
    }

    /// Each sharp or flat of a key signature sits on a line or space of the note it alters.
    func testKeySignaturesSitOnTheirNotes() {
        let sharps: [NoteName] = [.F, .C, .G, .D, .A, .E, .B]
        let flats: [NoteName] = [.B, .E, .A, .D, .G, .C, .F]
        for clef in Clef.allCases {
            let bottomLine = clef.middleLine - 4
            for (steps, names) in [(clef.keySignatureSteps(sharps: true), sharps), (clef.keySignatureSteps(sharps: false), flats)] {
                XCTAssertEqual(steps.map { ((bottomLine + $0) % 7 + 7) % 7 }, names.map(\.diatonicIndex), "\(clef)")
                XCTAssertTrue(steps.allSatisfy { (-1...9).contains($0) }, "\(clef) stays on the staff")
            }
        }
    }

    func testFewestLedgerLines() {
        let lowRightHand = ["A3", "C4", "E4"].map(pitch)
        XCTAssertEqual(Clef.fewestLedgerLines(for: lowRightHand, usual: .treble, usesAlto: true), .alto)
        // Treble and bass need three ledger lines each, so the hand keeps its usual clef
        XCTAssertEqual(Clef.fewestLedgerLines(for: lowRightHand, usual: .treble, usesAlto: false), .treble)
        XCTAssertEqual(Clef.fewestLedgerLines(for: ["E5", "G5"].map(pitch), usual: .bass, usesAlto: true), .treble)
        XCTAssertEqual(Clef.fewestLedgerLines(for: ["E2", "G2"].map(pitch), usual: .treble, usesAlto: true), .bass)
        XCTAssertEqual(Clef.fewestLedgerLines(for: [], usual: .bass, usesAlto: true), .bass)
    }
}
