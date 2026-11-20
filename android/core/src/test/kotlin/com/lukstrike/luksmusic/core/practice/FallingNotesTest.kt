// FallingNotesTest.kt — the falling notes' clock, the bars on screen and the ones lighting their keys.
package com.lukstrike.luksmusic.core.practice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FallingNotesTest {

    private val track = FallingNoteTrack(listOf(
        FallingNote(64, 2.0, 1.0, Hand.RIGHT),
        FallingNote(60, 1.0, 1.0, Hand.RIGHT),
        FallingNote(48, 1.0, 4.0, Hand.LEFT),
        FallingNote(67, 12.0, 1.0, Hand.RIGHT),
    ))

    @Test
    fun barsAreSortedByStart() {
        assertEquals(listOf(1.0, 1.0, 2.0, 12.0), track.notes.map { it.startBeat })
    }

    @Test
    fun theClockFollowsTheTempoAndStopsAtTheHold() {
        assertEquals(3.0, FallingNoteTrack.advance(1.0, 1.0, 120.0, null), 1e-9)
        assertEquals(2.0, FallingNoteTrack.advance(1.0, 1.0, 120.0, 2.0), 1e-9)
        assertEquals(1.5, FallingNoteTrack.advance(1.0, 0.25, 120.0, 2.0), 1e-9)
    }

    @Test
    fun visibleBarsSpanTheWindow() {
        assertEquals(setOf(60, 48, 64), track.visible(1.0, 8.0).map { it.midiNote }.toSet())
        // The long bass note is still on screen after the short ones passed
        assertEquals(setOf(48, 67), track.visible(4.5, 8.0).map { it.midiNote }.toSet())
        assertTrue(track.visible(20.0, 8.0).isEmpty())
    }

    @Test
    fun hitsLightKeysPerHandWithTheirBarStart() {
        val hits = track.hits(1.0)
        assertEquals(setOf(60, 48), hits.active)
        assertEquals(setOf(48), hits.bass)
        assertEquals(setOf(60), hits.treble)
        assertEquals(1.0, hits.startBeats.getValue(60), 1e-9)
    }

    @Test
    fun aBarLightsItsKeyJustBeforeTheLineAndStopsJustBeforeItsEnd() {
        assertTrue(64 in track.hits(1.96).active)
        // C4 ends at 2.0: it stops lighting a moment before, so E4 alone is lit from the line
        assertEquals(setOf(48, 64), track.hits(1.99).active)
        assertEquals(setOf(48), track.hits(2.99).active)
        assertTrue(track.hits(5.0).active.isEmpty())
    }
}
