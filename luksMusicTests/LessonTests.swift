// LessonTests.swift
// luksMusicTests
//
// The course's content is musically right, and a lesson can be played from start to end.

import XCTest
@testable import luksMusic

@MainActor
final class LessonTests: XCTestCase {

    func testNotationReadsNaturalsSharpsAndFlats() {
        XCTAssertEqual(LessonNotation.pitch(from: "C4")?.midiNoteNumber, 60)
        XCTAssertEqual(LessonNotation.pitch(from: "F#4")?.midiNoteNumber, 66)
        XCTAssertEqual(LessonNotation.pitch(from: "Bb3")?.midiNoteNumber, 58)
        XCTAssertNil(LessonNotation.pitch(from: "H4"))
        XCTAssertNil(LessonNotation.pitch(from: "C"))
    }

    /// What the lessons say about where each note is written.
    func testTrebleStaffPositionsMatchTheExplanations() {
        let expected: [(String, Int)] = [
            ("C4", -6), // short line below the staff
            ("D4", -5), // just below the first line
            ("E4", -4), // first line
            ("F4", -3), // first space
            ("G4", -2), // second line
            ("A4", -1), // second space
            ("B4", 0),  // third line
            ("C5", 1),  // third space
        ]
        for (text, position) in expected {
            let pitch = LessonNotation.pitch(from: text)!
            XCTAssertEqual(Note(pitch: pitch, staff: .treble).staffPosition, position, text)
        }
    }

    func testEveryLessonIsWellFormed() {
        var ids = Set<String>()
        for lesson in LessonCatalog.allLessons {
            XCTAssertTrue(ids.insert(lesson.id).inserted, "duplicate \(lesson.id)")
            XCTAssertTrue(lesson.steps.contains { $0.isExercise }, lesson.id)
            XCTAssertNotNil(lesson.midiRange, lesson.id)
            for step in lesson.steps {
                XCTAssertEqual(step.readingSteps.count, step.notes.count, "\(lesson.id): \(step.title) has a bad note")
                XCTAssertLessThanOrEqual(step.notes.count, 8, "\(lesson.id): \(step.title) doesn't fit the staff")
                XCTAssertFalse(step.isExercise && step.notes.isEmpty, "\(lesson.id): \(step.title) has nothing to play")
                XCTAssertFalse(step.text.isEmpty)
            }
        }
    }

    func testTheScalesGoUpAndDownBetweenTheTwoCs() {
        let up = LessonCatalog.allLessons.first { $0.id == "treble-5" }!
        let down = LessonCatalog.allLessons.first { $0.id == "treble-6" }!
        let scale = [60, 62, 64, 65, 67, 69, 71, 72]
        for step in up.steps {
            XCTAssertEqual(step.readingSteps.flatMap(\.midiNotes), scale, step.title)
        }
        for step in down.steps {
            XCTAssertEqual(step.readingSteps.flatMap(\.midiNotes), Array(scale.reversed()), step.title)
        }
    }

    func testStars() {
        XCTAssertEqual(Lesson.stars(clean: 10, total: 10), 3)
        XCTAssertEqual(Lesson.stars(clean: 9, total: 10), 3)
        XCTAssertEqual(Lesson.stars(clean: 7, total: 10), 2)
        XCTAssertEqual(Lesson.stars(clean: 6, total: 10), 1)
        XCTAssertEqual(Lesson.stars(clean: 0, total: 0), 3)
    }

    func testAMistakeIsCountedAndTheKeyIsShownAfterThreeWrongTries() {
        let viewModel = LessonPlayerViewModel(lesson: LessonCatalog.allLessons[1]) // Dó, Ré, Mi
        defer { viewModel.stop() }
        viewModel.continueLesson()
        viewModel.continueLesson()
        XCTAssertEqual(viewModel.step.kind, .guided)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [60], "the first key is lit")

        viewModel.notePlayed(60)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [62], "the light moves on")
        viewModel.notePlayed(62)
        viewModel.notePlayed(64)
        XCTAssertEqual(viewModel.feedback, .stepDone(clean: 3, total: 3))

        viewModel.continueLesson()
        XCTAssertEqual(viewModel.step.kind, .alone)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [], "nothing is lit without help")

        viewModel.notePlayed(67)
        XCTAssertEqual(viewModel.feedback, .wrong("Sol4"))
        XCTAssertEqual(viewModel.wrongPitch?.midiNoteNumber, 67)
        viewModel.notePlayed(67)
        viewModel.notePlayed(67)
        XCTAssertEqual(viewModel.feedback, .revealed("Mi4"))
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [64])

        viewModel.notePlayed(64)
        viewModel.notePlayed(62)
        viewModel.notePlayed(60)
        XCTAssertEqual(viewModel.feedback, .stepDone(clean: 2, total: 3))
        XCTAssertTrue(viewModel.showsRepeat)

        // Repeating replaces the try just counted
        XCTAssertEqual(viewModel.totalNotes, 6)
        XCTAssertEqual(viewModel.cleanNotes, 5)
        viewModel.repeatStep()
        XCTAssertEqual(viewModel.totalNotes, 3)
        XCTAssertEqual(viewModel.cleanNotes, 3)
    }

    func testPlayingThroughALessonFinishesItAndOffersTheNext() {
        let lessons = LessonCatalog.allLessons
        let viewModel = LessonPlayerViewModel(lesson: lessons[0])
        defer { viewModel.stop() }
        for step in lessons[0].steps {
            for note in step.readingSteps.flatMap(\.midiNotes) where step.isExercise {
                viewModel.notePlayed(note)
            }
            viewModel.continueLesson()
        }
        XCTAssertTrue(viewModel.isFinished)
        XCTAssertEqual(viewModel.stars, 3)
        XCTAssertEqual(viewModel.nextLesson?.id, lessons[1].id)
        viewModel.open(lessons[1])
        XCTAssertFalse(viewModel.isFinished)
        XCTAssertEqual(viewModel.stepIndex, 0)
        XCTAssertEqual(viewModel.totalNotes, 0)
    }
}
