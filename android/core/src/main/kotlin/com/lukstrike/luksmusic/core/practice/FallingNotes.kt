// FallingNotes.kt — the timing of the falling notes above the keyboard (FallingNotesViewModel in
// Views/Practice/FallingNotesView.swift): the clock, which bars are on screen, which ones are crossing the hit line.
// The app draws them; colors are chosen there from each bar's start beat.
package com.lukstrike.luksmusic.core.practice

import kotlin.math.min

enum class Hand { RIGHT, LEFT }

/** A note as a falling bar. Beats count from 1 at the first measure, in the time signature's beat. */
data class FallingNote(
    val midiNote: Int,
    val startBeat: Double,
    val durationBeats: Double,
    val hand: Hand = Hand.RIGHT,
) {
    val endBeat: Double get() = startBeat + durationBeats
}

/** The bars crossing the hit line: their keys, per hand, and each key's bar start (for its beat color). */
data class FallingHits(
    val active: Set<Int> = emptySet(),
    val bass: Set<Int> = emptySet(),
    val treble: Set<Int> = emptySet(),
    val startBeats: Map<Int, Double> = emptyMap(),
)

/** A set of bars sorted by start, so each frame finds the ones on screen without scanning the whole piece. */
class FallingNoteTrack(notes: List<FallingNote>) {
    val notes: List<FallingNote> = notes.sortedBy { it.startBeat }
    private val starts = DoubleArray(this.notes.size) { this.notes[it].startBeat }
    private val longest = this.notes.maxOfOrNull { it.durationBeats } ?: 0.0

    /** Bars overlapping [fromBeat]..[toBeat]. */
    inline fun forEachIn(fromBeat: Double, toBeat: Double, action: (FallingNote) -> Unit) {
        for (i in firstIndexFrom(fromBeat) until notes.size) {
            val note = notes[i]
            if (note.startBeat > toBeat) break
            if (note.endBeat >= fromBeat) action(note)
        }
    }

    /** Index of the first bar that may still be sounding at [beat] (no bar is longer than the longest). */
    fun firstIndexFrom(beat: Double): Int {
        val target = beat - longest
        var low = 0
        var high = starts.size
        while (low < high) {
            val mid = (low + high) ushr 1
            if (starts[mid] < target) low = mid + 1 else high = mid
        }
        return low
    }

    /** Bars visible with the clock at [currentBeat]: from just past the hit line to [visibleBeats] above it. */
    fun visible(currentBeat: Double, visibleBeats: Double): List<FallingNote> {
        val result = mutableListOf<FallingNote>()
        forEachIn(currentBeat - VISIBLE_BELOW, currentBeat + visibleBeats) { result += it }
        return result
    }

    /** Bars striking the hit line at [currentBeat]. */
    fun hits(currentBeat: Double): FallingHits {
        val active = mutableSetOf<Int>()
        val bass = mutableSetOf<Int>()
        val treble = mutableSetOf<Int>()
        val startBeats = mutableMapOf<Int, Double>()
        forEachIn(currentBeat, currentBeat + HIT_EARLY) { note ->
            if (isHitting(note, currentBeat)) {
                active += note.midiNote
                startBeats[note.midiNote] = note.startBeat
                if (note.hand == Hand.LEFT) bass += note.midiNote else treble += note.midiNote
            }
        }
        return FallingHits(active, bass, treble, startBeats)
    }

    companion object {
        /** Beats of bar still drawn below the hit line. */
        const val VISIBLE_BELOW = 0.8
        /** A bar lights its key this many beats before it reaches the line. */
        const val HIT_EARLY = 0.05
        /** ...and stops a moment early, so a note held at the line doesn't also light the one that ends there. */
        const val HIT_END_EARLY = 0.02

        fun isHitting(note: FallingNote, currentBeat: Double): Boolean =
            currentBeat >= note.startBeat - HIT_EARLY && currentBeat < note.endBeat - HIT_END_EARLY

        /**
         * The clock after [deltaSeconds] at [tempo] BPM. [holdBeat] stops it there (guided practice waits at the
         * expected notes); nil keeps it falling.
         */
        fun advance(currentBeat: Double, deltaSeconds: Double, tempo: Double, holdBeat: Double?): Double {
            val next = currentBeat + (tempo / 60.0) * deltaSeconds
            return if (holdBeat != null) min(next, holdBeat) else next
        }
    }
}
