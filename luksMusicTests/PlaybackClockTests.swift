// PlaybackClockTests.swift
// luksMusicTests
//
// The score player's clock at the barline: on to the next measure, the same measure again or back to the first,
// and the metronome's beat in each case. Steps are fractions of a beat a binary Double holds exactly.

import XCTest
@testable import luksMusic

final class PlaybackClockTests: XCTestCase {

    private typealias Step = ScoreViewModel.ClockStep

    /// One tick in a piece of three 4/4 measures unless told otherwise.
    private func step(measure: Int = 0, beat: Double, by beats: Double, length: Double = 4, count: Int = 3,
                      loop: ScoreViewModel.LoopMode = .off) -> Step? {
        ScoreViewModel.clockStep(measure: measure, beat: beat, advancingBy: beats, measureLength: length,
                                 measureCount: count, loopMode: loop)
    }

    func testInsideTheMeasureTheClockOnlyMoves() {
        XCTAssertEqual(step(beat: 1.5, by: 0.25), Step(measure: 0, beat: 1.75, crossedBarline: false, clickBeat: nil))
        XCTAssertEqual(step(beat: 1.875, by: 0.25), Step(measure: 0, beat: 2.125, crossedBarline: false, clickBeat: 2),
                       "crossing a beat clicks it")
    }

    func testTheBarlineLeadsToTheNextMeasureCarryingTheRest() {
        for loop in [ScoreViewModel.LoopMode.off, .piece] {
            XCTAssertEqual(step(measure: 1, beat: 4.875, by: 0.25, loop: loop),
                           Step(measure: 2, beat: 1.125, crossedBarline: true, clickBeat: 1), "\(loop)")
        }
    }

    func testThePieceEndsAtTheLastBarlineWithoutRepeat() {
        XCTAssertNil(step(measure: 2, beat: 4.875, by: 0.25))
        XCTAssertNil(step(measure: 0, beat: 1, by: 4, count: 0), "an empty piece")
    }

    func testRepeatingTheMeasureGoesBackToItsFirstBeat() {
        for measure in 0..<3 {
            XCTAssertEqual(step(measure: measure, beat: 4.875, by: 0.25, loop: .measure),
                           Step(measure: measure, beat: 1.125, crossedBarline: true, clickBeat: 1),
                           "measure \(measure + 1), the last one too")
        }
    }

    func testRepeatingThePieceGoesBackToTheFirstMeasure() {
        XCTAssertEqual(step(measure: 2, beat: 4.875, by: 0.25, loop: .piece),
                       Step(measure: 0, beat: 1.125, crossedBarline: true, clickBeat: 1))
    }

    func testAShortMeasureEndsAfterItsOwnBeats() {
        // A pickup of a beat and a half
        XCTAssertEqual(step(beat: 2.375, by: 0.25, length: 1.5, loop: .measure),
                       Step(measure: 0, beat: 1.125, crossedBarline: true, clickBeat: 1))
        XCTAssertEqual(step(beat: 2.25, by: 0.125, length: 1.5),
                       Step(measure: 0, beat: 2.375, crossedBarline: false, clickBeat: nil))
    }

    /// Two measures' worth of 50 Hz ticks on a repeated 3/4 measure: it never moves on and every pass starts
    /// with the accented click.
    func testARepeatedMeasureKeepsCountingItsBeats() {
        var measure = 1
        var beat = 1.0
        var clicks: [Int] = []
        for _ in 0..<(2 * 3 * 32) {
            guard let next = step(measure: measure, beat: beat, by: 1.0 / 32, length: 3, loop: .measure) else {
                return XCTFail("a repeated measure never ends")
            }
            measure = next.measure
            beat = next.beat
            if let click = next.clickBeat {
                clicks.append(click)
            }
        }
        XCTAssertEqual(measure, 1)
        XCTAssertEqual(beat, 1.0)
        XCTAssertEqual(clicks, [2, 3, 1, 2, 3, 1])
    }

    func testTheButtonCyclesOffMeasurePiece() {
        XCTAssertEqual(ScoreViewModel.LoopMode.off.next, .measure)
        XCTAssertEqual(ScoreViewModel.LoopMode.measure.next, .piece)
        XCTAssertEqual(ScoreViewModel.LoopMode.piece.next, .off)
    }
}
