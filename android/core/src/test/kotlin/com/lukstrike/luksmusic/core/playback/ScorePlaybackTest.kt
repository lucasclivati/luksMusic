// ScorePlaybackTest.kt — what the player strikes and shows from a score (iOS ScoreViewModel's triggerNotes,
// refreshActiveNotes, noteNames and the timeline): ties and rests stay silent, muted hands too, held lengths follow the
// tempo, and transposition moves the keys, their names and the key text.
package com.lukstrike.luksmusic.core.playback

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.NoteName
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.Staff
import org.junit.Assert.assertEquals
import org.junit.Test

class ScorePlaybackTest {

    private val c4 = Note(id = "c4", pitch = Pitch(NoteName.C, 4), duration = NoteDuration.HALF, beat = 1.0)
    private val e4 = Note(id = "e4", pitch = Pitch(NoteName.E, 4), beat = 3.0)
    private val fSharp4 = Note(id = "f#4", pitch = Pitch(NoteName.F, 4, Accidental.SHARP), beat = 4.0)
    private val c3 = Note(id = "c3", pitch = Pitch(NoteName.C, 3), duration = NoteDuration.WHOLE, staff = Staff.BASS, beat = 1.0)
    private val tiedC4 = Note(id = "tie", pitch = Pitch(NoteName.C, 4), beat = 1.0, isTieContinuation = true)
    private val rest = Note.rest(beat = 2.0, staff = Staff.BASS)

    private val score = Score(
        tempo = 60,
        measures = listOf(
            Measure(number = 1, notes = listOf(c4, e4, fSharp4, c3)),
            Measure(number = 2, notes = listOf(tiedC4, rest)),
            Measure(number = 3, length = 2.0),
        ),
    )
    private val playback = ScorePlayback(score)

    @Test
    fun timelineCountsAPickupByItsOwnBeats() {
        assertEquals(10.0, playback.totalSeconds, 1e-9)
        assertEquals(5.5, playback.elapsedSeconds(1, 2.5), 1e-9)
        assertEquals(2.0, playback.measureLength(2), 0.0)
        assertEquals(listOf(1.0, 3.0, 4.0), playback.onsets(0))
    }

    @Test
    fun aTickStrikesTheOnsetsItCrosses() {
        val struck = playback.notesBetween(0, 0.95, 1.02, HandsMixer(), 0, 60.0)
        assertEquals(listOf("c4", "c3"), struck.map { it.noteId })
        assertEquals(2.0, struck[0].durationSeconds, 1e-9)
        assertEquals((80 * 0.95).toInt(), struck[0].velocity)
        assertEquals(emptyList<StruckNote>(), playback.notesBetween(0, 1.02, 2.98, HandsMixer(), 0, 60.0))
    }

    @Test
    fun tiesRestsAndMutedHandsStaySilent() {
        assertEquals(emptyList<StruckNote>(), playback.notesAround(1, 1.0, HandsMixer(), 0, 60.0))
        val leftOnly = playback.notesAround(0, 1.0, HandsMixer(trebleMuted = true), 0, 60.0)
        assertEquals(listOf("c3"), leftOnly.map { it.noteId })
    }

    @Test
    fun fastNotesRingAtLeastAShortMoment() {
        val struck = playback.notesAround(0, 3.0, HandsMixer(), 0, 1000.0)
        assertEquals(0.12, struck.single().durationSeconds, 0.0)
    }

    @Test
    fun transpositionMovesTheKeys() {
        assertEquals(listOf(62), playback.notesAround(0, 3.0, HandsMixer(), -2, 60.0).map { it.midi })
    }

    @Test
    fun cursorNotesIncludeTheOnesStillRinging() {
        val notes = playback.cursorNotes(0, 3.2, 0, usesLetters = false)
        assertEquals(3.0, notes.cursorBeat, 0.0)
        assertEquals(setOf(64), notes.trebleMidi)
        assertEquals(setOf(48), notes.bassMidi)
        assertEquals("Mi4", notes.trebleNames)
        assertEquals("Dó3", notes.bassNames)
    }

    @Test
    fun namesAreSpelledFromTheScoreUnlessTransposed() {
        assertEquals("C4, F♯4", ScorePlayback.noteNames(listOf(fSharp4, c4), 0, usesLetters = true))
        assertEquals("Dó4, Fá♯4", ScorePlayback.noteNames(listOf(c4, fSharp4, c4), 0, usesLetters = false))
        assertEquals("E♭4", ScorePlayback.noteNames(listOf(c4), 3, usesLetters = true))
        assertEquals("Si♭3", ScorePlayback.noteNames(listOf(c4), -2, usesLetters = false))
    }

    @Test
    fun keyTextFollowsTheTransposition() {
        assertEquals("C, a", ScorePlayback.keyText(0, 0))
        assertEquals("D, b", ScorePlayback.keyText(0, 2))
        assertEquals(2, ScorePlayback.keySignature(0, 2))
        assertEquals("F, d", ScorePlayback.keyText(-1, 0))
        assertEquals("E♭, c", ScorePlayback.keyText(-1, -2))
        assertEquals(-3, ScorePlayback.keySignature(-1, -2))
    }
}
