// PlaybackClockTest.kt — port of luksMusicTests/PlaybackClockTests.swift. The score player's clock at the barline:
// on to the next measure, the same measure again or back to the first, and the metronome's beat in each case.
// Steps are fractions of a beat a binary Double holds exactly.
package com.lukstrike.luksmusic.core.playback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.fail
import org.junit.Test

class PlaybackClockTest {

    /** One tick in a piece of three 4/4 measures unless told otherwise. */
    private fun step(
        measure: Int = 0, beat: Double, by: Double, length: Double = 4.0, count: Int = 3, loop: LoopMode = LoopMode.OFF,
    ): ClockStep? = PlaybackClock.step(measure, beat, by, length, count, loop)

    @Test
    fun insideTheMeasureTheClockOnlyMoves() {
        assertEquals(ClockStep(0, 1.75, false, null), step(beat = 1.5, by = 0.25))
        assertEquals("crossing a beat clicks it", ClockStep(0, 2.125, false, 2), step(beat = 1.875, by = 0.25))
    }

    @Test
    fun theBarlineLeadsToTheNextMeasureCarryingTheRest() {
        for (loop in listOf(LoopMode.OFF, LoopMode.PIECE)) {
            assertEquals("$loop", ClockStep(2, 1.125, true, 1), step(measure = 1, beat = 4.875, by = 0.25, loop = loop))
        }
    }

    @Test
    fun thePieceEndsAtTheLastBarlineWithoutRepeat() {
        assertNull(step(measure = 2, beat = 4.875, by = 0.25))
        assertNull("an empty piece", step(measure = 0, beat = 1.0, by = 4.0, count = 0))
    }

    @Test
    fun repeatingTheMeasureGoesBackToItsFirstBeat() {
        for (measure in 0 until 3) {
            assertEquals(
                "measure ${measure + 1}, the last one too",
                ClockStep(measure, 1.125, true, 1),
                step(measure = measure, beat = 4.875, by = 0.25, loop = LoopMode.MEASURE),
            )
        }
    }

    @Test
    fun repeatingThePieceGoesBackToTheFirstMeasure() {
        assertEquals(ClockStep(0, 1.125, true, 1), step(measure = 2, beat = 4.875, by = 0.25, loop = LoopMode.PIECE))
    }

    @Test
    fun aShortMeasureEndsAfterItsOwnBeats() {
        // A pickup of a beat and a half
        assertEquals(ClockStep(0, 1.125, true, 1), step(beat = 2.375, by = 0.25, length = 1.5, loop = LoopMode.MEASURE))
        assertEquals(ClockStep(0, 2.375, false, null), step(beat = 2.25, by = 0.125, length = 1.5))
    }

    /** Two measures' worth of 50 Hz ticks on a repeated 3/4 measure: it never moves on and every pass starts with
     *  the accented click. */
    @Test
    fun aRepeatedMeasureKeepsCountingItsBeats() {
        var measure = 1
        var beat = 1.0
        val clicks = mutableListOf<Int>()
        repeat(2 * 3 * 32) {
            val next = step(measure = measure, beat = beat, by = 1.0 / 32, length = 3.0, loop = LoopMode.MEASURE)
                ?: return fail("a repeated measure never ends")
            measure = next.measure
            beat = next.beat
            next.clickBeat?.let { clicks += it }
        }
        assertEquals(1, measure)
        assertEquals(1.0, beat, 0.0)
        assertEquals(listOf(2, 3, 1, 2, 3, 1), clicks)
    }

    @Test
    fun theButtonCyclesOffMeasurePiece() {
        assertEquals(LoopMode.MEASURE, LoopMode.OFF.next)
        assertEquals(LoopMode.PIECE, LoopMode.MEASURE.next)
        assertEquals(LoopMode.OFF, LoopMode.PIECE.next)
    }
}
