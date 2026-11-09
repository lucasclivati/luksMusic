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

    func testNotationReadsValuesRestsChordsAndForcedStaves() {
        let quarter = LessonNotation.event(from: "C4")
        XCTAssertEqual(quarter?.duration, .quarter)
        XCTAssertEqual(LessonNotation.event(from: "D4:h.")?.duration, .dottedHalf)
        XCTAssertEqual(LessonNotation.event(from: "E4:e")?.duration, .eighth)
        let rest = LessonNotation.event(from: "R:w")
        XCTAssertEqual(rest?.isRest, true)
        XCTAssertEqual(rest?.duration, .whole)
        XCTAssertEqual(LessonNotation.event(from: "C4+E4+G4:w")?.pitches.map(\.midiNoteNumber), [60, 64, 67])
        XCTAssertEqual(LessonNotation.event(from: "C4/b")?.forcedStaff, .bass)
        XCTAssertNil(LessonNotation.event(from: "C4:x"))
        XCTAssertNil(LessonNotation.event(from: "C4+H4"))
    }

    /// What the lessons say about where each note is written in the bass clef.
    func testBassStaffPositionsMatchTheExplanations() {
        let expected: [(String, Int)] = [
            ("C4", 6),   // short line above the staff
            ("B3", 5),   // just above the fifth line
            ("A3", 4),   // fifth line
            ("G3", 3),   // fourth space
            ("F3", 2),   // fourth line, between the clef's dots
            ("E3", 1),   // third space
            ("D3", 0),   // third line
            ("C3", -1),  // second space
            ("B2", -2),  // second line
            ("A2", -3),  // first space
            ("G2", -4),  // first line
            ("F2", -5),  // just below the first line
            ("E2", -6),  // short line below
            ("C2", -8),  // second short line
        ]
        for (text, position) in expected {
            let pitch = LessonNotation.pitch(from: text)!
            XCTAssertEqual(Note(pitch: pitch, staff: .bass).staffPosition, position, text)
        }
    }

    func testUpperTrebleNotesMatchTheExplanations() {
        let expected: [(String, Int)] = [("D5", 2), ("E5", 3), ("F5", 4), ("G5", 5), ("A5", 6), ("B5", 7), ("C6", 8)]
        for (text, position) in expected {
            XCTAssertEqual(Note(pitch: LessonNotation.pitch(from: text)!, staff: .treble).staffPosition, position, text)
        }
    }

    func testGrandStaffPutsNotesOnTheRightStaff() {
        let step = LessonStep(.guided, "t", "x", notes: "C3+E4 C4/b", grand: true)
        let events = step.readingSteps
        XCTAssertEqual(events[0].notes.map(\.staff), [.bass, .treble])
        XCTAssertEqual(events[1].notes.map(\.staff), [.bass])
    }

    func testTheKeySignaturePrintsNoSignOnItsOwnNotes() {
        let gMajor = LessonStep(.alone, "t", "x", notes: "G5 F#5 F5", key: 1)
        XCTAssertEqual(ReadingDrill.printedAccidentals(for: gMajor.readingSteps, keySignature: 1), [[nil], [nil], [.natural]])
        let natural = LessonStep(.alone, "t", "x", notes: "F#4 F#4 F4")
        XCTAssertEqual(ReadingDrill.printedAccidentals(for: natural.readingSteps, keySignature: 0), [[.sharp], [nil], [.natural]])
    }

    func testRandomExercisesDrawFromThePoolWithoutRepeatingANote() {
        var generator = SystemRandomNumberGenerator()
        let pool = ["C4", "D4", "E4"]
        let drawn = LessonNotation.draw(count: 200, from: pool, using: &generator)
        XCTAssertEqual(drawn.count, 200)
        XCTAssertEqual(Set(drawn), Set(pool))
        for (first, second) in zip(drawn, drawn.dropFirst()) {
            XCTAssertNotEqual(first, second)
        }
    }

    func testRestsArePassedOverAndNotScored() {
        let step = LessonStep(.rhythm, "t", "x", notes: "R:q C4:q R:q D4:q", meter: 4)
        var state = ReadingSegmentState(steps: step.readingSteps)
        XCTAssertEqual(state.current, 1, "a leading rest is skipped")
        XCTAssertEqual(state.playableCount, 2)
        XCTAssertEqual(state.press(60), .correct(stepDone: true))
        XCTAssertEqual(state.current, 3, "the rest between the notes is skipped")
        state.miss()
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.cleanCount, 1, "rests don't count and the missed note isn't clean")
    }

    func testTimingJudgesEachKeyAroundItsBeat() {
        let step = LessonStep(.rhythm, "t", "x", notes: "C4:q C4:q C4:h", meter: 4)
        let timing = RhythmTiming(steps: step.readingSteps, secondsPerBeat: 1)
        XCTAssertEqual(timing.times, [0, 1, 2])
        XCTAssertEqual(timing.verdict(step: 1, elapsed: 1.1), .onTime)
        XCTAssertEqual(timing.verdict(step: 1, elapsed: 0.7), .early)
        XCTAssertEqual(timing.verdict(step: 1, elapsed: 1.3), .late)
        XCTAssertFalse(timing.isOverdue(step: 0, elapsed: 0.7), "a late key counts until the next note is due")
        XCTAssertTrue(timing.isOverdue(step: 0, elapsed: 0.8))
        XCTAssertFalse(timing.isOverdue(step: 2, elapsed: 2.5))
        XCTAssertTrue(timing.isOverdue(step: 2, elapsed: 2.7))

        // Fast notes get a window that can't reach their neighbors
        let eighths = LessonStep(.rhythm, "t", "x", notes: "C4:e C4:e C4:e C4:e C4:h", meter: 4)
        let fast = RhythmTiming(steps: eighths.readingSteps, secondsPerBeat: 0.5)
        XCTAssertEqual(fast.tolerances[0], 0.1125, accuracy: 0.0001)
    }

    func testAFinishedLessonIsSavedAndOpensTheNext() {
        let defaults = UserDefaults(suiteName: "lessons-test")!
        defaults.removePersistentDomain(forName: "lessons-test")
        let progress = LessonProgress(defaults: defaults)
        let lessons = LessonCatalog.allLessons
        XCTAssertTrue(progress.isOpen(lessons[0], in: lessons))
        XCTAssertFalse(progress.isOpen(lessons[1], in: lessons))
        progress.record(lessonID: lessons[0].id, stars: 2)
        XCTAssertTrue(progress.isOpen(lessons[1], in: lessons))
        progress.record(lessonID: lessons[0].id, stars: 1)
        XCTAssertEqual(progress.stars[lessons[0].id], 2, "keeps the best result")
        XCTAssertFalse(progress.isOpen(lessons[5], in: lessons))
        progress.setUnlocksEverything(true)
        XCTAssertTrue(progress.isOpen(lessons[5], in: lessons))
    }

    func testAChordCanBePlayedOneKeyAtATime() {
        let chords = LessonCatalog.allLessons.first { $0.id == "chord-1" }!
        let viewModel = LessonPlayerViewModel(lesson: chords)
        defer { viewModel.stop() }
        viewModel.continueLesson()
        XCTAssertEqual(viewModel.step.kind, .guided)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [60, 64, 67])
        viewModel.notePlayed(64)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [60, 67], "the keys already found go out")
        viewModel.notePlayed(60)
        viewModel.notePlayed(67)
        XCTAssertEqual(viewModel.feedback, .stepDone(clean: 1, total: 1))
    }

    func testKeysAreIgnoredBeforeATimedStepStarts() {
        let lesson = LessonCatalog.allLessons.first { $0.id == "rhy-1" }!
        let viewModel = LessonPlayerViewModel(lesson: lesson)
        defer { viewModel.stop() }
        viewModel.continueLesson()
        XCTAssertEqual(viewModel.timedPhase, .ready)
        XCTAssertEqual(viewModel.feedback, .readyToStart)
        viewModel.notePlayed(60)
        XCTAssertEqual(viewModel.segment.current, 0)
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
                XCTAssertLessThanOrEqual(step.pool == nil ? 0 : step.drawCount, 8, "\(lesson.id): \(step.title) doesn't fit the staff")
                XCTAssertFalse(step.isExercise && step.notes.isEmpty && step.pool == nil, "\(lesson.id): \(step.title) has nothing to play")
                XCTAssertEqual((step.pool ?? []).compactMap(LessonNotation.pitch(from:)).count, step.pool?.count ?? 0, "\(lesson.id): bad note in the pool")
                XCTAssertFalse(step.text.isEmpty)
                if step.isTimed {
                    XCTAssertNotNil(step.meter, "\(lesson.id): \(step.title) needs a meter")
                }
                // A written meter must come out in whole measures
                if let meter = step.meter, let last = step.readingSteps.last {
                    let total = last.globalBeat + last.heldBeats
                    XCTAssertEqual(total.truncatingRemainder(dividingBy: Double(meter)), 0, accuracy: 0.001, "\(lesson.id): \(step.title) has \(total) beats")
                }
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
