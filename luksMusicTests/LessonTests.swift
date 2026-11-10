// LessonTests.swift
// luksMusicTests
//
// The course's content is musically right, and a lesson can be played from start to end.

import XCTest
@testable import luksMusic

@MainActor
final class LessonTests: XCTestCase {

    private func lesson(_ id: String) -> Lesson {
        LessonCatalog.allLessons.first { $0.id == id }!
    }

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
        let step = LessonStep(.learn, "t", "x", notes: "C3+E4 C4/b", grand: true)
        let events = step.readingSteps
        XCTAssertEqual(events[0].notes.map(\.staff), [.bass, .treble])
        XCTAssertEqual(events[1].notes.map(\.staff), [.bass])
    }

    func testTheKeySignaturePrintsNoSignOnItsOwnNotes() {
        let gMajor = LessonStep(.read, "t", "x", notes: "G5 F#5 F5", key: 1)
        XCTAssertEqual(ReadingDrill.printedAccidentals(for: gMajor.readingSteps, keySignature: 1), [[nil], [nil], [.natural]])
        let natural = LessonStep(.read, "t", "x", notes: "F#4 F#4 F4")
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

    func testDrillsBringTheNewNotesMoreOften() {
        var generator = SystemRandomNumberGenerator()
        let pool = ["C4", "D4", "E4", "F4", "G4"]
        let focus = ["F4", "G4"]
        var favored = 0
        var total = 0
        for _ in 0..<300 {
            let drawn = LessonNotation.draw(count: 10, from: pool, favoring: focus, using: &generator)
            XCTAssertTrue(drawn.contains("F4") && drawn.contains("G4"), "every new note comes up: \(drawn)")
            for (first, second) in zip(drawn, drawn.dropFirst()) {
                XCTAssertNotEqual(first, second)
            }
            favored += drawn.filter(focus.contains).count
            total += drawn.count
        }
        // Two notes of five, weighted twice: about 4 in 7 draws
        XCTAssertGreaterThan(Double(favored) / Double(total), 0.48)
    }

    func testLongStepsArePagedByWholeMeasures() {
        let piece = lesson("treble-2").steps[3]
        XCTAssertTrue(piece.isPiece)
        // Two measures of 3 notes, a measure of eight eighths, a last measure of 3
        XCTAssertEqual(LessonNotation.pages(of: piece.readingSteps, measured: true), [0..<6, 6..<14, 14..<17])
        let drill = LessonStep(.read, "t", "x", notes: "C4 D4 E4 C4 D4 E4 C4 D4 E4 C4")
        XCTAssertEqual(LessonNotation.pages(of: drill.readingSteps, measured: false), [0..<5, 5..<10])
        let sixteen = LessonStep(.read, "t", "x", notes: Array(repeating: "C4", count: 16).joined(separator: " "))
        XCTAssertEqual(LessonNotation.pages(of: sixteen.readingSteps, measured: false), [0..<8, 8..<16])
        XCTAssertEqual(LessonNotation.pages(of: Array(drill.readingSteps.prefix(3)), measured: false), [0..<3])
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

    func testAChordIsLearnedOneKeyAtATime() {
        let viewModel = LessonPlayerViewModel(lesson: lesson("chord-1"))
        defer { viewModel.stop() }
        XCTAssertEqual(viewModel.step.kind, .learn)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [60, 64, 67])
        viewModel.notePlayed(64)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [60, 67], "the keys already found go out")
        viewModel.notePlayed(60)
        viewModel.notePlayed(67)
        XCTAssertTrue(viewModel.isStepDone)
        XCTAssertEqual(viewModel.totalNotes, 0, "learning isn't scored")
    }

    func testKeysAreIgnoredBeforeATimedStepStarts() {
        let viewModel = LessonPlayerViewModel(lesson: lesson("rhy-1"))
        defer { viewModel.stop() }
        XCTAssertEqual(viewModel.step.kind, .rhythm)
        XCTAssertEqual(viewModel.timedPhase, .ready)
        XCTAssertEqual(viewModel.feedback, .readyToStart)
        viewModel.notePlayed(60)
        XCTAssertEqual(viewModel.segment.current, 0)
    }

    func testEveryLessonIsWellFormed() {
        var ids = Set<String>()
        for lesson in LessonCatalog.allLessons {
            XCTAssertTrue(ids.insert(lesson.id).inserted, "duplicate \(lesson.id)")
            XCTAssertNotNil(lesson.midiRange, lesson.id)
            XCTAssertTrue(lesson.steps.last?.isScored == true, "\(lesson.id) ends with practice")
            for step in lesson.steps {
                XCTAssertEqual(step.readingSteps.count, step.notes.count, "\(lesson.id): \(step.title) has a bad note")
                XCTAssertFalse(step.notes.isEmpty && step.pool == nil, "\(lesson.id): \(step.title) has nothing to play")
                XCTAssertFalse(step.kind == .learn && step.pool != nil, "\(lesson.id): \(step.title) learns from a draw")
                XCTAssertEqual((step.pool ?? []).compactMap(LessonNotation.pitch(from:)).count, step.pool?.count ?? 0, "\(lesson.id): bad note in the pool")
                XCTAssertTrue(Set(step.focus).isSubset(of: Set(step.pool ?? [])), "\(lesson.id): \(step.title) favors a note it can't draw")
                XCTAssertLessThanOrEqual(step.pool == nil ? 0 : step.drawCount, 16, "\(lesson.id): \(step.title) is too long")
                XCTAssertFalse(step.text.isEmpty)
                if step.isTimed {
                    XCTAssertNotNil(step.meter, "\(lesson.id): \(step.title) needs a meter")
                }
                // Every page fits the staff
                for page in LessonNotation.pages(of: step.readingSteps, measured: step.meter != nil) {
                    XCTAssertLessThanOrEqual(page.count, 8, "\(lesson.id): \(step.title) has a page of \(page.count)")
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
        let scale = [60, 62, 64, 65, 67, 69, 71, 72]
        for step in lesson("treble-5").steps.prefix(2) {
            XCTAssertEqual(step.readingSteps.flatMap(\.midiNotes), scale, step.title)
        }
        for step in lesson("treble-6").steps.prefix(2) {
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

    func testANewNoteIsLearnedByPlayingItAndADrillShowsTheKeyAfterTwoMistakes() {
        let viewModel = LessonPlayerViewModel(lesson: lesson("treble-2")) // Dó, Ré, Mi
        defer { viewModel.stop() }
        XCTAssertEqual(viewModel.step.kind, .learn)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [62], "the new note's key is lit")

        viewModel.notePlayed(62)
        XCTAssertTrue(viewModel.isStepDone)
        XCTAssertEqual(viewModel.stepIndex, 0, "a finished step waits for Continuar")
        XCTAssertTrue(viewModel.showsContinue)
        XCTAssertFalse(viewModel.showsRepeat, "learning can't go wrong")
        XCTAssertEqual(viewModel.nextStepTitle, "Nota nova: Mi")

        viewModel.continueLesson()
        viewModel.notePlayed(64)
        viewModel.continueLesson()

        // The drill: ten notes drawn from Dó, Ré and Mi, the new ones at least once
        XCTAssertTrue(viewModel.step.isDrill)
        let drawn = viewModel.segment.steps.flatMap(\.midiNotes)
        XCTAssertEqual(drawn.count, 10)
        XCTAssertTrue(Set(drawn).isSubset(of: [60, 62, 64]))
        XCTAssertTrue(drawn.contains(62) && drawn.contains(64))
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [], "nothing is lit without help")
        XCTAssertEqual(viewModel.pages, [0..<5, 5..<10])

        let first = drawn[0]
        viewModel.notePlayed(67)
        XCTAssertEqual(viewModel.feedback, .wrong("Sol4"))
        XCTAssertEqual(viewModel.wrongPitch?.midiNoteNumber, 67)
        viewModel.notePlayed(67)
        XCTAssertEqual(viewModel.keyboard.targetNoteKeys, [first], "the key is shown after two mistakes")
        if case .revealed = viewModel.feedback {} else { XCTFail("expected the answer shown, got \(viewModel.feedback)") }

        for (index, note) in drawn.enumerated() {
            viewModel.notePlayed(note)
            if index == 4 {
                XCTAssertEqual(viewModel.page, 5..<10, "the staff turns to the next page")
                XCTAssertEqual(viewModel.visibleCurrent, 0)
            }
        }
        XCTAssertEqual(viewModel.feedback, .stepDone(clean: 9, total: 10))
        XCTAssertTrue(viewModel.showsRepeat)
        XCTAssertEqual(viewModel.totalNotes, 10, "only practice counts")
        XCTAssertEqual(viewModel.cleanNotes, 9)

        // Repeating replaces the try just counted
        viewModel.repeatStep()
        XCTAssertEqual(viewModel.totalNotes, 0)
        XCTAssertEqual(viewModel.cleanNotes, 0)
        XCTAssertEqual(viewModel.segment.current, 0)
    }

    func testPlayingThroughALessonFinishesItAndOffersTheNext() {
        let lessons = LessonCatalog.allLessons
        let viewModel = LessonPlayerViewModel(lesson: lessons[0])
        defer { viewModel.stop() }
        var steps = 0
        while !viewModel.isFinished && steps < 20 {
            for step in viewModel.segment.steps where !step.isRest {
                for note in step.midiNotes {
                    viewModel.notePlayed(note)
                }
            }
            XCTAssertTrue(viewModel.isStepDone, viewModel.step.title)
            viewModel.continueLesson()
            steps += 1
        }
        XCTAssertTrue(viewModel.isFinished)
        XCTAssertEqual(viewModel.stars, 3)
        XCTAssertEqual(viewModel.totalNotes, 3, "the three Dós of the last step")
        XCTAssertEqual(viewModel.nextLesson?.id, lessons[1].id)
        viewModel.open(lessons[1])
        XCTAssertFalse(viewModel.isFinished)
        XCTAssertEqual(viewModel.stepIndex, 0)
        XCTAssertEqual(viewModel.totalNotes, 0)
    }

    func testAnEarStepShowsEachNoteOnlyOnceFound() async throws {
        let viewModel = LessonPlayerViewModel(lesson: lesson("ear-1"))
        defer { viewModel.stop() }
        XCTAssertEqual(viewModel.step.kind, .listen)
        XCTAssertEqual(viewModel.segment.steps.count, 3)
        XCTAssertTrue(viewModel.visibleSteps.isEmpty, "nothing is written before it is found")
        XCTAssertEqual(viewModel.feedback, .listening)

        // The app plays the three notes first, and keys are ignored meanwhile
        var waited = 0
        while viewModel.feedback == .listening && waited < 60 {
            try await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
        XCTAssertEqual(viewModel.feedback, .yourTurn)
        let notes = viewModel.segment.steps.flatMap(\.midiNotes)
        viewModel.notePlayed(notes[0])
        XCTAssertEqual(viewModel.visibleSteps.flatMap(\.midiNotes), [notes[0]])
    }
}
