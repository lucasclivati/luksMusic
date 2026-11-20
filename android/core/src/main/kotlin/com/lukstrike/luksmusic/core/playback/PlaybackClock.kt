// PlaybackClock.kt — the score player's clock at the barline (iOS ScoreViewModel.clockStep / ClockStep / LoopMode),
// kept apart from the timer so it can be tested.
package com.lukstrike.luksmusic.core.playback

import kotlin.math.floor

/**
 * What the player repeats at a barline: nothing, the measure the cursor is in (so moving the cursor moves the loop,
 * like the web player), or the whole piece.
 */
enum class LoopMode {
    OFF, MEASURE, PIECE;

    /** The mode the dock's button switches to. */
    val next: LoopMode
        get() = when (this) {
            OFF -> MEASURE
            MEASURE -> PIECE
            PIECE -> OFF
        }
}

/** Where the playback clock stands after one tick, and the beat whose metronome click fell due in it. */
data class ClockStep(
    val measure: Int,
    val beat: Double,
    /** The tick passed the barline, into the next measure or back to the start of a repeated one. */
    val crossedBarline: Boolean,
    /** Beat 1 is the first of the measure and gets the accented click; null when no beat was crossed. */
    val clickBeat: Int?,
)

object PlaybackClock {

    /**
     * Moves the clock [beats] on from [beat] (1-based) in measure [measure], which lasts [measureLength] beats. Past the
     * barline the remainder carries into the next measure, into the same one when repeating it, or into the first
     * when repeating the piece; null when the piece ends.
     */
    fun step(
        measure: Int,
        beat: Double,
        beats: Double,
        measureLength: Double,
        measureCount: Int,
        loopMode: LoopMode,
    ): ClockStep? {
        val newBeat = beat + beats
        val barline = measureLength + 1
        if (newBeat < barline) {
            val crossed = floor(newBeat).toInt()
            return ClockStep(
                measure = measure,
                beat = newBeat,
                crossedBarline = false,
                clickBeat = if (crossed > floor(beat).toInt()) crossed else null,
            )
        }
        val next = when (loopMode) {
            LoopMode.MEASURE -> measure
            LoopMode.PIECE -> if (measure + 1 < measureCount) measure + 1 else 0
            LoopMode.OFF -> if (measure + 1 < measureCount) measure + 1 else return null
        }
        return ClockStep(measure = next, beat = 1 + (newBeat - barline), crossedBarline = true, clickBeat = 1)
    }
}
