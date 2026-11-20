// LessonTest.kt — port of luksMusicTests/LessonTests.swift.
//
// The course's content is musically right, and a lesson can be played from start to end. The iOS tests drive
// LessonPlayerViewModel; here they drive LessonSession, which holds the same rules without Android.
package com.lukstrike.luksmusic.core.lessons

import com.lukstrike.luksmusic.core.lessons.LessonStep.Kind
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Staff
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class LessonTest {

    /** Records what the session asks for; demonstrations and timed steps are run by hand. */
    private class FakeEffects : LessonEffects {
        var demo: LessonSession.DemoPlan? = null
        var finished: Pair<String, Int>? = null
        override fun playNote(midi: Int, velocity: Int, durationSeconds: Double) {}
        override fun click(accent: Boolean) {}
        override fun expect(notes: Set<Int>?) {}
        override fun ignoreInput(seconds: Double) {}
        override fun flash(note: Int, correct: Boolean) {}
        override fun runDemo(plan: LessonSession.DemoPlan) { demo = plan }
        override fun runTimed(token: Int) {}
        override fun lessonFinished(lessonId: String, stars: Int) { finished = lessonId to stars }
    }

    private fun lesson(id: String): Lesson = LessonCatalog.allLessons.first { it.id == id }

    private fun session(lesson: Lesson, effects: LessonEffects = FakeEffects()) =
        LessonSession(lesson, effects, usesLetters = { false })

    private fun step(kind: Kind, notes: String, grand: Boolean = false, key: Int = 0, meter: Int? = null) =
        LessonStep(kind, LessonText.verbatim("t"), LessonText.verbatim("x"), notes = notes, grand = grand, key = key, meter = meter)

    @Test
    fun notationReadsNaturalsSharpsAndFlats() {
        assertEquals(60, LessonNotation.pitch("C4")?.midiNoteNumber)
        assertEquals(66, LessonNotation.pitch("F#4")?.midiNoteNumber)
        assertEquals(58, LessonNotation.pitch("Bb3")?.midiNoteNumber)
        assertNull(LessonNotation.pitch("H4"))
        assertNull(LessonNotation.pitch("C"))
    }

    /** What the lessons say about where each note is written. */
    @Test
    fun trebleStaffPositionsMatchTheExplanations() {
        val expected = listOf(
            "C4" to -6, // short line below the staff
            "D4" to -5, // just below the first line
            "E4" to -4, // first line
            "F4" to -3, // first space
            "G4" to -2, // second line
            "A4" to -1, // second space
            "B4" to 0,  // third line
            "C5" to 1,  // third space
        )
        for ((text, position) in expected) {
            assertEquals(text, position, Note(pitch = LessonNotation.pitch(text)!!, staff = Staff.TREBLE).staffPosition)
        }
    }

    @Test
    fun notationReadsValuesRestsChordsAndForcedStaves() {
        assertEquals(NoteDuration.QUARTER, LessonNotation.event("C4")?.duration)
        assertEquals(NoteDuration.DOTTED_HALF, LessonNotation.event("D4:h.")?.duration)
        assertEquals(NoteDuration.EIGHTH, LessonNotation.event("E4:e")?.duration)
        val rest = LessonNotation.event("R:w")
        assertEquals(true, rest?.isRest)
        assertEquals(NoteDuration.WHOLE, rest?.duration)
        assertEquals(listOf(60, 64, 67), LessonNotation.event("C4+E4+G4:w")?.pitches?.map { it.midiNoteNumber })
        assertEquals(Staff.BASS, LessonNotation.event("C4/b")?.forcedStaff)
        assertNull(LessonNotation.event("C4:x"))
        assertNull(LessonNotation.event("C4+H4"))
    }

    /** What the lessons say about where each note is written in the bass clef. */
    @Test
    fun bassStaffPositionsMatchTheExplanations() {
        val expected = listOf(
            "C4" to 6,   // short line above the staff
            "B3" to 5,   // just above the fifth line
            "A3" to 4,   // fifth line
            "G3" to 3,   // fourth space
            "F3" to 2,   // fourth line, between the clef's dots
            "E3" to 1,   // third space
            "D3" to 0,   // third line
            "C3" to -1,  // second space
            "B2" to -2,  // second line
            "A2" to -3,  // first space
            "G2" to -4,  // first line
            "F2" to -5,  // just below the first line
            "E2" to -6,  // short line below
            "C2" to -8,  // second short line
        )
        for ((text, position) in expected) {
            assertEquals(text, position, Note(pitch = LessonNotation.pitch(text)!!, staff = Staff.BASS).staffPosition)
        }
    }

    @Test
    fun upperTrebleNotesMatchTheExplanations() {
        val expected = listOf("D5" to 2, "E5" to 3, "F5" to 4, "G5" to 5, "A5" to 6, "B5" to 7, "C6" to 8)
        for ((text, position) in expected) {
            assertEquals(text, position, Note(pitch = LessonNotation.pitch(text)!!, staff = Staff.TREBLE).staffPosition)
        }
    }

    @Test
    fun grandStaffPutsNotesOnTheRightStaff() {
        val events = step(Kind.LEARN, "C3+E4 C4/b", grand = true).readingSteps
        assertEquals(listOf(Staff.BASS, Staff.TREBLE), events[0].notes.map { it.staff })
        assertEquals(listOf(Staff.BASS), events[1].notes.map { it.staff })
    }

    @Test
    fun theKeySignaturePrintsNoSignOnItsOwnNotes() {
        val gMajor = step(Kind.READ, "G5 F#5 F5", key = 1)
        assertEquals(listOf(listOf(null), listOf(null), listOf(Accidental.NATURAL)), ReadingDrill.printedAccidentals(gMajor.readingSteps, 1))
        val natural = step(Kind.READ, "F#4 F#4 F4")
        assertEquals(listOf(listOf(Accidental.SHARP), listOf(null), listOf(Accidental.NATURAL)), ReadingDrill.printedAccidentals(natural.readingSteps, 0))
    }

    @Test
    fun randomExercisesDrawFromThePoolWithoutRepeatingANote() {
        val pool = listOf("C4", "D4", "E4")
        val drawn = LessonNotation.draw(200, pool)
        assertEquals(200, drawn.size)
        assertEquals(pool.toSet(), drawn.toSet())
        for ((first, second) in drawn.zipWithNext()) assertNotEquals(first, second)
    }

    @Test
    fun drillsBringTheNewNotesMoreOften() {
        val pool = listOf("C4", "D4", "E4", "F4", "G4")
        val focus = listOf("F4", "G4")
        var favored = 0
        var total = 0
        repeat(300) {
            val drawn = LessonNotation.draw(10, pool, focus)
            assertTrue("every new note comes up: $drawn", "F4" in drawn && "G4" in drawn)
            for ((first, second) in drawn.zipWithNext()) assertNotEquals(first, second)
            favored += drawn.count { it in focus }
            total += drawn.size
        }
        // Two notes of five, weighted twice: about 4 in 7 draws
        assertTrue(favored.toDouble() / total > 0.48)
    }

    @Test
    fun longStepsArePagedByWholeMeasures() {
        val piece = lesson("treble-2").steps[3]
        assertTrue(piece.isPiece)
        // Two measures of 3 notes, a measure of eight eighths, a last measure of 3
        assertEquals(listOf(0 until 6, 6 until 14, 14 until 17), LessonNotation.pages(piece.readingSteps, measured = true))
        val drill = step(Kind.READ, "C4 D4 E4 C4 D4 E4 C4 D4 E4 C4")
        assertEquals(listOf(0 until 5, 5 until 10), LessonNotation.pages(drill.readingSteps, measured = false))
        val sixteen = step(Kind.READ, List(16) { "C4" }.joinToString(" "))
        assertEquals(listOf(0 until 8, 8 until 16), LessonNotation.pages(sixteen.readingSteps, measured = false))
        assertEquals(listOf(0 until 3), LessonNotation.pages(drill.readingSteps.take(3), measured = false))
    }

    @Test
    fun restsArePassedOverAndNotScored() {
        val state = ReadingSegmentState(step(Kind.RHYTHM, "R:q C4:q R:q D4:q", meter = 4).readingSteps)
        assertEquals("a leading rest is skipped", 1, state.current)
        assertEquals(2, state.playableCount)
        assertEquals(ReadingPress.Correct(true), state.press(60))
        assertEquals("the rest between the notes is skipped", 3, state.current)
        state.miss()
        assertTrue(state.isComplete)
        assertEquals("rests don't count and the missed note isn't clean", 1, state.cleanCount)
    }

    @Test
    fun timingJudgesEachKeyAroundItsBeat() {
        val timing = RhythmTiming(step(Kind.RHYTHM, "C4:q C4:q C4:h", meter = 4).readingSteps, secondsPerBeat = 1.0)
        assertEquals(listOf(0.0, 1.0, 2.0), timing.times)
        assertEquals(RhythmTiming.Verdict.ON_TIME, timing.verdict(1, 1.1))
        assertEquals(RhythmTiming.Verdict.EARLY, timing.verdict(1, 0.7))
        assertEquals(RhythmTiming.Verdict.LATE, timing.verdict(1, 1.3))
        assertFalse("a late key counts until the next note is due", timing.isOverdue(0, 0.7))
        assertTrue(timing.isOverdue(0, 0.8))
        assertFalse(timing.isOverdue(2, 2.5))
        assertTrue(timing.isOverdue(2, 2.7))

        // Fast notes get a window that can't reach their neighbors
        val fast = RhythmTiming(step(Kind.RHYTHM, "C4:e C4:e C4:e C4:e C4:h", meter = 4).readingSteps, secondsPerBeat = 0.5)
        assertEquals(0.1125, fast.tolerances[0], 0.0001)
    }

    @Test
    fun aFinishedLessonIsSavedAndOpensTheNext() {
        var progress = LessonProgress()
        val lessons = LessonCatalog.allLessons
        assertTrue(progress.isOpen(lessons[0], lessons))
        assertFalse(progress.isOpen(lessons[1], lessons))
        progress = progress.recording(lessons[0].id, 2)
        assertTrue(progress.isOpen(lessons[1], lessons))
        progress = progress.recording(lessons[0].id, 1)
        assertEquals("keeps the best result", 2, progress.stars[lessons[0].id])
        assertFalse(progress.isOpen(lessons[5], lessons))
        progress = progress.copy(unlocksEverything = true)
        assertTrue(progress.isOpen(lessons[5], lessons))
    }

    @Test
    fun aChordIsLearnedOneKeyAtATime() {
        val session = session(lesson("chord-1"))
        assertEquals(Kind.LEARN, session.step.kind)
        assertEquals(setOf(60, 64, 67), session.targetKeys)
        session.notePlayed(64)
        assertEquals("the keys already found go out", setOf(60, 67), session.targetKeys)
        session.notePlayed(60)
        session.notePlayed(67)
        assertTrue(session.isStepDone)
        assertEquals("learning isn't scored", 0, session.totalNotes)
    }

    @Test
    fun keysAreIgnoredBeforeATimedStepStarts() {
        val session = session(lesson("rhy-1"))
        assertEquals(Kind.RHYTHM, session.step.kind)
        assertEquals(LessonSession.TimedPhase.READY, session.timedPhase)
        assertEquals(LessonSession.Feedback.ReadyToStart, session.feedback)
        session.notePlayed(60)
        assertEquals(0, session.segment.current)
    }

    @Test
    fun aTimedStepJudgesKeysByTheClock() {
        var now = 100.0
        val session = LessonSession(lesson("rhy-1"), FakeEffects(), usesLetters = { false }, clock = { now })
        session.startTimedStep(makesSound = true)
        // 72 bpm, four beats of count-in plus 0.2 s
        val start = 100.0 + 4 * 60.0 / 72 + 0.2
        now = 100.5
        assertTrue(session.timedTick(1))
        assertTrue(session.feedback is LessonSession.Feedback.CountIn)
        now = start + 0.05
        session.timedTick(1)
        assertEquals(LessonSession.Feedback.Playing, session.feedback)
        session.notePlayed(60)
        assertEquals(LessonSession.Feedback.OnTime, session.feedback)
        // The second note goes by unplayed
        now = start + 2 * 60.0 / 72
        session.timedTick(1)
        assertEquals(LessonSession.Feedback.Missed, session.feedback)
        assertEquals(2, session.segment.current)

        // Leaving the screen mid-step: it starts over, waiting for "Começar"
        session.stop()
        assertEquals(LessonSession.TimedPhase.READY, session.timedPhase)
        assertEquals(LessonSession.Feedback.ReadyToStart, session.feedback)
        assertEquals(0, session.segment.current)
        assertFalse(session.timedTick(1))
    }

    @Test
    fun anInterruptedDemonstrationGivesTheTurnBack() {
        val effects = FakeEffects()
        val session = session(lesson("ear-1"), effects)
        assertEquals(LessonSession.Feedback.Listening, session.feedback)
        session.stop()
        assertEquals(LessonSession.Feedback.YourTurn, session.feedback)
        assertFalse("the cancelled demonstration plays no more", session.demoReached(effects.demo!!, 0))
    }

    @Test
    fun everyLessonIsWellFormed() {
        val ids = HashSet<String>()
        for (lesson in LessonCatalog.allLessons) {
            assertTrue("duplicate ${lesson.id}", ids.add(lesson.id))
            assertNotNull(lesson.id, lesson.midiRange)
            assertTrue("${lesson.id} ends with practice", lesson.steps.last().isScored)
            for (step in lesson.steps) {
                val name = "${lesson.id}: ${step.title.key}"
                assertTrue(step.text.key.isNotEmpty())
                if (step.isIntro) {
                    assertTrue("$name: intro step shouldn't require notes", step.notes.isEmpty() && step.pool == null)
                    assertNotNull("$name: intro step needs its introduction", step.intro)
                    assertFalse(step.isScored)
                    continue
                }
                assertEquals("$name has a bad note", step.notes.size, step.readingSteps.size)
                assertFalse("$name has nothing to play", step.notes.isEmpty() && step.pool == null)
                assertFalse("$name learns from a draw", step.kind == Kind.LEARN && step.pool != null)
                assertEquals("$name: bad note in the pool", step.pool?.size ?: 0, (step.pool ?: emptyList()).mapNotNull(LessonNotation::pitch).size)
                assertTrue("$name favors a note it can't draw", (step.pool ?: emptyList()).containsAll(step.focus))
                assertTrue("$name is too long", (if (step.pool == null) 0 else step.drawCount) <= 16)
                if (step.isTimed) assertNotNull("$name needs a meter", step.meter)
                // Every page fits the staff
                for (page in LessonNotation.pages(step.readingSteps, measured = step.meter != null)) {
                    assertTrue("$name has a page of ${page.count()}", page.count() <= 8)
                }
                // A written meter must come out in whole measures
                val meter = step.meter
                val last = step.readingSteps.lastOrNull()
                if (meter != null && last != null) {
                    val total = last.globalBeat + last.heldBeats
                    val remainder = total % meter
                    assertTrue("$name has $total beats", remainder < 0.001 || abs(remainder - meter) < 0.001)
                }
            }
        }
    }

    @Test
    fun everyTextIsAStringResourceName() {
        val pattern = Regex("learn_[a-z0-9_]+")
        for (module in LessonCatalog.modules) {
            assertTrue(pattern.matches(module.title.key) && pattern.matches(module.summary.key))
            for (lesson in module.lessons) {
                for (text in listOf(lesson.title, lesson.summary) + lesson.steps.flatMap { listOf(it.title, it.text) }) {
                    if (text.isVerbatim) continue
                    assertTrue(text.key, pattern.matches(text.key))
                    text.suffixKey?.let { assertTrue(it, pattern.matches(it)) }
                }
            }
        }
    }

    @Test
    fun introScriptClimbsOneOctaveFromMiddleCWithTwoOctaveKeyboard() {
        assertEquals(60..84, LessonIntroScript.keyboardRange)
        assertEquals("two octaves from C4 to C6", 15, ReadingDrill.whiteCount(60, 84))

        val spawned = LessonIntroScript.presses(LessonIntro.TREBLE_OCTAVE).filter { it.spawnsNote }
        assertEquals(listOf(60, 62, 64, 65, 67, 69, 71, 72), spawned.map { it.midi })
        assertEquals(listOf(-6, -5, -4, -3, -2, -1, 0, 1), spawned.map { it.staffPosition })

        val ptNames = spawned.map { LessonIntroScript.shortNoteName(it.token, usesLetters = false) }
        val enNames = spawned.map { LessonIntroScript.shortNoteName(it.token, usesLetters = true) }
        assertEquals(listOf("Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si", "Dó"), ptNames)
        assertEquals(listOf("C", "D", "E", "F", "G", "A", "B", "C"), enNames)

        val startSnap = LessonIntroScript.snapshot(LessonIntro.TREBLE_OCTAVE, 0.0, usesLetters = false)
        assertTrue(startSnap.notes.isEmpty())
        val linesSnap = LessonIntroScript.snapshot(LessonIntro.TREBLE_OCTAVE, 4.0, usesLetters = false)
        assertEquals(listOf(1.0, 1.0, 1.0, 1.0, 1.0), linesSnap.lineProgress)
        val octaveSnap = LessonIntroScript.snapshot(LessonIntro.TREBLE_OCTAVE, 36.0, usesLetters = false)
        assertEquals(8, octaveSnap.notes.size)

        // Its texts are string resource names of strings_intro.xml
        val pattern = Regex("intro_[a-z0-9_]+")
        val cues = LessonIntroScript.cues(LessonIntro.TREBLE_OCTAVE)
        val texts = cues.flatMap { listOf(it.phaseLabel, it.title, it.subtitle) } + spawned.mapNotNull { it.positionCallout }
        assertEquals(8, spawned.mapNotNull { it.positionCallout }.size)
        for (text in texts) assertTrue(text.key, pattern.matches(text.key))
        assertEquals("the chapters cover the whole video", LessonIntroScript.duration(LessonIntro.TREBLE_OCTAVE), cues.last().endTime, 1e-9)

        // The keyboard's white slots line up with the C major scale
        assertEquals(0.0, LessonIntroScript.whiteSlot(60.0), 1e-9)
        assertEquals(7.0, LessonIntroScript.whiteSlot(72.0), 1e-9)
        assertEquals(14.0, LessonIntroScript.whiteSlot(84.0), 1e-9)
    }

    @Test
    fun anIntroStepAsksForNothingAndContinuesOn() {
        val session = session(lesson("treble-1"))
        assertTrue(session.step.isIntro)
        assertEquals(LessonSession.Feedback.None, session.feedback)
        assertEquals(emptySet<Int>(), session.targetKeys)
        assertNull("the microphone expects nothing", session.expectedNotes)
        session.notePlayed(60)
        assertEquals(0, session.totalNotes)
        session.continueLesson()
        assertEquals(1, session.stepIndex)
        assertEquals(Kind.LEARN, session.step.kind)
    }

    @Test
    fun theScalesGoUpAndDownBetweenTheTwoCs() {
        val scale = listOf(60, 62, 64, 65, 67, 69, 71, 72)
        for (step in lesson("treble-5").steps.take(2)) {
            assertEquals(step.title.key, scale, step.readingSteps.flatMap { it.midiNotes })
        }
        for (step in lesson("treble-6").steps.take(2)) {
            assertEquals(step.title.key, scale.reversed(), step.readingSteps.flatMap { it.midiNotes })
        }
    }

    @Test
    fun stars() {
        assertEquals(3, Lesson.stars(10, 10))
        assertEquals(3, Lesson.stars(9, 10))
        assertEquals(2, Lesson.stars(7, 10))
        assertEquals(1, Lesson.stars(6, 10))
        assertEquals(3, Lesson.stars(0, 0))
    }

    @Test
    fun aNewNoteIsLearnedByPlayingItAndADrillShowsTheKeyAfterTwoMistakes() {
        val session = session(lesson("treble-2")) // Dó, Ré, Mi
        assertEquals(Kind.LEARN, session.step.kind)
        assertEquals("the new note's key is lit", setOf(62), session.targetKeys)

        session.notePlayed(62)
        assertTrue(session.isStepDone)
        assertEquals("a finished step waits for Continuar", 0, session.stepIndex)
        assertTrue(session.showsContinue)
        assertFalse("learning can't go wrong", session.showsRepeat)
        assertEquals("learn_l_treble_2_s2_title", session.nextStepTitle?.key) // "Nota nova: Mi"

        session.continueLesson()
        session.notePlayed(64)
        session.continueLesson()

        // The drill: ten notes drawn from Dó, Ré and Mi, the new ones at least once
        assertTrue(session.step.isDrill)
        val drawn = session.segment.steps.flatMap { it.midiNotes }
        assertEquals(10, drawn.size)
        assertTrue(setOf(60, 62, 64).containsAll(drawn))
        assertTrue(62 in drawn && 64 in drawn)
        assertEquals("nothing is lit without help", emptySet<Int>(), session.targetKeys)
        assertEquals(listOf(0 until 5, 5 until 10), session.pages)

        val first = drawn[0]
        session.notePlayed(67)
        assertEquals(LessonSession.Feedback.Wrong("Sol4"), session.feedback)
        assertEquals(67, session.wrongPitch?.midiNoteNumber)
        session.notePlayed(67)
        assertEquals("the key is shown after two mistakes", setOf(first), session.targetKeys)
        assertTrue("expected the answer shown, got ${session.feedback}", session.feedback is LessonSession.Feedback.Revealed)

        drawn.forEachIndexed { index, note ->
            session.notePlayed(note)
            if (index == 4) {
                assertEquals("the staff turns to the next page", 5 until 10, session.page)
                assertEquals(0, session.visibleCurrent)
            }
        }
        assertEquals(LessonSession.Feedback.StepDone(clean = 9, total = 10), session.feedback)
        assertTrue(session.showsRepeat)
        assertEquals("only practice counts", 10, session.totalNotes)
        assertEquals(9, session.cleanNotes)

        // Repeating replaces the try just counted
        session.repeatStep()
        assertEquals(0, session.totalNotes)
        assertEquals(0, session.cleanNotes)
        assertEquals(0, session.segment.current)
    }

    @Test
    fun playingThroughALessonFinishesItAndOffersTheNext() {
        val lessons = LessonCatalog.allLessons
        val effects = FakeEffects()
        val session = session(lessons[0], effects)
        assertTrue(lessons[0].hasIntro)
        assertTrue(lessons[0].steps.last().isChallenge)
        var steps = 0
        while (!session.isFinished && steps < 20) {
            if (session.step.isIntro) {
                session.continueLesson()
                steps += 1
                continue
            }
            for (step in session.segment.steps.filter { !it.isRest }) {
                for (note in step.midiNotes) session.notePlayed(note)
            }
            assertTrue(session.step.title.key, session.isStepDone)
            session.continueLesson()
            steps += 1
        }
        assertTrue(session.isFinished)
        assertEquals(3, session.stars)
        assertEquals("the 6-note song opening plus the 11-note full song challenge", 17, session.totalNotes)
        assertEquals(lessons[0].id to 3, effects.finished)
        assertEquals(lessons[1].id, session.nextLesson?.id)
        session.open(lessons[1])
        assertFalse(session.isFinished)
        assertEquals(0, session.stepIndex)
        assertEquals(0, session.totalNotes)
    }

    @Test
    fun anEarStepShowsEachNoteOnlyOnceFound() {
        val effects = FakeEffects()
        val session = session(lesson("ear-1"), effects)
        assertEquals(Kind.LISTEN, session.step.kind)
        assertEquals(3, session.segment.steps.size)
        assertTrue("nothing is written before it is found", session.visibleSteps.isEmpty())
        assertEquals(LessonSession.Feedback.Listening, session.feedback)

        // The app plays the three notes first, and keys are ignored meanwhile
        val plan = effects.demo!!
        val notes = session.segment.steps.flatMap { it.midiNotes }
        session.notePlayed(notes[0])
        assertEquals(0, session.segment.current)
        plan.steps.indices.forEach { assertTrue(session.demoReached(plan, it)) }
        session.demoEnded(plan)
        assertEquals(LessonSession.Feedback.YourTurn, session.feedback)
        session.notePlayed(notes[0])
        assertEquals(listOf(notes[0]), session.visibleSteps.flatMap { it.midiNotes })
    }
}
