// PracticeEngineTest.kt — Modo Estudo's rules: the notes it expects in each mode, how it judges and moves on, the
// streaks, the falling notes' bars and how they follow practice.
package com.lukstrike.luksmusic.core.practice

import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.PracticeMode
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.Staff
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PracticeEngineTest {

    private fun note(midi: Int, beat: Double, staff: Staff = Staff.TREBLE, duration: NoteDuration = NoteDuration.QUARTER) =
        Note(pitch = Pitch.fromMidi(midi), beat = beat, staff = staff, duration = duration)

    /**
     * 4/4 at 100 BPM. Measure 1: C4 then a C-E chord on beat 2 with a bass C3, rest of the measure empty.
     * Measure 2: bass G2 on beat 1, treble G4 on beat 3. Measure 3: only a rest.
     */
    private fun score() = Score(
        title = "Test", tempo = 100,
        measures = listOf(
            Measure(number = 1, notes = listOf(
                note(60, 1.0), note(60, 2.0), note(64, 2.0), note(48, 2.0, Staff.BASS),
            )),
            Measure(number = 2, notes = listOf(note(43, 1.0, Staff.BASS), note(67, 3.0))),
            Measure(number = 3, notes = listOf(Note.rest(beat = 1.0))),
        ),
    )

    @Test
    fun guidedStartsOnTheFirstNote() {
        val engine = PracticeEngine(score())
        engine.start()
        assertEquals(setOf(60), engine.targets)
        assertEquals(0, engine.currentMeasureIndex)
        assertEquals(1.0, engine.cursorBeat, 1e-9)
    }

    @Test
    fun guidedWaitsForEveryNoteOfTheChord() {
        val engine = PracticeEngine(score())
        engine.start()
        assertTrue(engine.notePlayed(60))
        assertEquals(setOf(60, 64, 48), engine.targets)
        assertTrue(engine.notePlayed(64))
        assertTrue(engine.notePlayed(48))
        assertEquals("waits until the chord is complete", setOf(60, 64, 48), engine.targets)
        assertEquals(2.0, engine.currentBeat, 1e-9)
        // The chord is done once its last key is played: practice is on the next measure's first note
        assertTrue(engine.notePlayed(60))
        assertEquals(1, engine.currentMeasureIndex)
        assertEquals(setOf(43), engine.targets)
    }

    @Test
    fun aWrongNoteDoesNotMoveOnAndEndsTheStreak() {
        val engine = PracticeEngine(score())
        engine.start()
        assertTrue(engine.notePlayed(60))
        assertFalse(engine.notePlayed(61))
        assertEquals(setOf(60, 64, 48), engine.targets)
        assertEquals(PracticeTally(totalNotesPlayed = 2, correctNotes = 1, incorrectNotes = 1, currentStreak = 0, longestStreak = 1), engine.tally)
        assertEquals(50.0, engine.tally.accuracy, 1e-9)
    }

    @Test
    fun guidedWrapsBackToTheStartAfterTheLastNote() {
        val engine = PracticeEngine(score())
        engine.start()
        listOf(60, 60, 64, 48, 43).forEach { engine.notePlayed(it) }
        assertEquals(setOf(67), engine.targets)
        engine.notePlayed(67)
        // Measure 3 has only a rest: back to the first note of the piece
        assertEquals(0, engine.currentMeasureIndex)
        assertEquals(setOf(60), engine.targets)
    }

    @Test
    fun handsSeparateExpectsOneHand() {
        val right = PracticeEngine(score(), PracticeMode.HANDS_SEPARATE_RIGHT)
        right.seek(0, 2.0)
        assertEquals(setOf(60, 64), right.targets)
        val left = PracticeEngine(score(), PracticeMode.HANDS_SEPARATE_LEFT)
        left.seek(0, 2.0)
        assertEquals(setOf(48), left.targets)
        // Timed: the left hand has nothing at beat 1 of measure 1
        left.seek(0, 1.0)
        assertTrue(left.targets.isEmpty())
    }

    @Test
    fun slowPracticeStartsAt70PercentButNotBelow40() {
        assertEquals(70, PracticeEngine(score(), PracticeMode.SLOW_PRACTICE).tempoBpm)
        assertEquals(40, PracticeEngine(score().copy(tempo = 50), PracticeMode.SLOW_PRACTICE).tempoBpm)
        assertEquals(100, PracticeEngine(score(), PracticeMode.FREE_PLAY).tempoBpm)
    }

    @Test
    fun timedModesMoveOnBySixteenthsAndLoop() {
        val engine = PracticeEngine(score(), PracticeMode.FREE_PLAY)
        assertTrue(engine.isTimed)
        assertEquals(0.15, engine.timerStepSeconds, 1e-9)
        engine.start()
        assertEquals(setOf(60), engine.targets)
        // One step early, beat 2's chord is already expected
        repeat(3) { engine.advanceTimedStep() }
        assertEquals(1.75, engine.currentBeat, 1e-9)
        assertEquals(setOf(60, 64, 48), engine.targets)
        // A 4/4 measure is 16 steps
        repeat(13) { engine.advanceTimedStep() }
        assertEquals(1, engine.currentMeasureIndex)
        assertEquals(1.0, engine.currentBeat, 1e-9)
        assertEquals(setOf(43), engine.targets)
        // Two more measures and practice loops to the start
        repeat(32) { engine.advanceTimedStep() }
        assertEquals(0, engine.currentMeasureIndex)
    }

    @Test
    fun timedModesDoNotMoveOnWhenANoteIsPlayed() {
        val engine = PracticeEngine(score(), PracticeMode.FREE_PLAY)
        engine.start()
        engine.notePlayed(60)
        assertEquals(1.0, engine.currentBeat, 1e-9)
        assertEquals(setOf(60), engine.targets)
    }

    @Test
    fun aRestOnlyMeasureExpectsNothingInTimedModes() {
        val engine = PracticeEngine(score(), PracticeMode.FREE_PLAY)
        engine.seek(2, 1.0)
        assertTrue(engine.targets.isEmpty())
        assertEquals(1.0, engine.cursorBeat, 1e-9)
        // A measure that does not exist is ignored
        engine.seek(5, 1.0)
        assertEquals(2, engine.currentMeasureIndex)
    }

    @Test
    fun startResetsTheTally() {
        val engine = PracticeEngine(score())
        engine.notePlayed(60)
        engine.notePlayed(60)
        engine.start()
        assertEquals(PracticeTally(), engine.tally)
        assertTrue(engine.isPlaying)
        engine.pause()
        assertFalse(engine.isPlaying)
        assertTrue(engine.resume())
        assertFalse("already playing", engine.resume())
    }

    @Test
    fun longestStreakKeepsTheBest() {
        var tally = PracticeTally()
        listOf(true, true, true, false, true).forEach { tally = tally.recording(it) }
        assertEquals(1, tally.currentStreak)
        assertEquals(3, tally.longestStreak)
        assertEquals(80.0, tally.accuracy, 1e-9)
        assertEquals(0.0, PracticeTally().accuracy, 1e-9)
    }

    @Test
    fun fallingBarsCountBeatsFromTheFirstMeasure() {
        val pickup = Score(
            measures = listOf(
                Measure(number = 0, length = 1.0, notes = listOf(note(67, 1.0))),
                Measure(number = 1, notes = listOf(
                    note(60, 1.0, duration = NoteDuration.HALF),
                    note(48, 1.0, Staff.BASS),
                    note(60, 3.0).copy(isTieContinuation = true),
                )),
            ),
        )
        val bars = PracticeEngine(pickup).fallingNotes
        assertEquals(3, bars.size)
        assertEquals(FallingNote(67, 1.0, 1.0, Hand.RIGHT), bars[0])
        // The pickup counts one beat
        assertEquals(FallingNote(60, 2.0, 2.0, Hand.RIGHT), bars[1])
        assertEquals(FallingNote(48, 2.0, 1.0, Hand.LEFT), bars[2])
    }

    @Test
    fun guidedHoldsTheFallingNotesAtTheExpectedNotes() {
        val engine = PracticeEngine(score())
        engine.start()
        engine.notePlayed(60) // now waiting on beat 2
        assertEquals(2.0, engine.absoluteBeat, 1e-9)
        val behind = engine.fallingSync(1.5)
        assertTrue(behind.isPlaying)
        assertEquals(2.0, behind.holdBeat!!, 1e-9)
        assertNull("less than a beat behind: they catch up", behind.seekTo)
        assertEquals(2.0, engine.fallingSync(0.5).seekTo!!, 1e-9)
        assertEquals(2.0, engine.fallingSync(2.2).seekTo!!, 1e-9)
    }

    @Test
    fun timedModesOnlySnapAfterAJump() {
        val engine = PracticeEngine(score(), PracticeMode.FREE_PLAY)
        engine.start()
        assertNull(engine.fallingSync(1.0).holdBeat)
        assertNull(engine.fallingSync(1.4).seekTo)
        engine.seek(1, 3.0)
        assertEquals(7.0, engine.fallingSync(1.4).seekTo!!, 1e-9)
    }

    @Test
    fun sessionRecordsTheTally() {
        val engine = PracticeEngine(score())
        engine.start()
        engine.notePlayed(60)
        engine.notePlayed(62)
        val session = engine.session(startTime = 1_000, endTime = 61_000)
        assertEquals(2, session.totalNotesPlayed)
        assertEquals(1, session.correctNotes)
        assertEquals(1, session.incorrectNotes)
        assertEquals(1, session.sectionsCompleted)
        assertEquals(100, session.tempoUsed)
        assertEquals(PracticeMode.GUIDED, session.practiceMode)
        assertEquals(60.0, session.durationSeconds, 1e-9)
    }
}
