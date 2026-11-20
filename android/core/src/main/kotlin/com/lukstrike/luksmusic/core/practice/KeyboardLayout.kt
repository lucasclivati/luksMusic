// KeyboardLayout.kt — where each key of the on-screen piano is, shared by the keyboard (drawing and touch) and the
// falling notes above it so their lanes line up (PianoKeyboardView.swift / FallingNotesView.swift position helpers).
// Positions are in white-key widths from the keyboard's left edge, so the same layout serves any size.
package com.lukstrike.luksmusic.core.practice

import kotlin.math.ceil
import kotlin.math.floor

object PianoKeys {
    private val blackIndices = setOf(1, 3, 6, 8, 10)

    fun isBlack(midi: Int): Boolean = Math.floorMod(midi, 12) in blackIndices

    /**
     * The keyboard Modo Estudo shows for a piece (PracticeView.onAppear): whole octaves from C covering its notes,
     * at least C3–C6 and at most C1–C8.
     */
    fun practiceRange(midiNotes: Collection<Int>): IntRange {
        val minPitch = midiNotes.minOrNull() ?: 48
        val maxPitch = midiNotes.maxOrNull() ?: 84
        val start = maxOf(24, minOf(48, (minPitch / 12) * 12))
        val end = minOf(108, maxOf(84, ceil((maxPitch + 1) / 12.0).toInt() * 12))
        return start..end
    }
}

class KeyboardLayout(val rangeStart: Int, val rangeEnd: Int) {
    /** The white keys, low to high. */
    val whiteKeys: List<Int> = (rangeStart..rangeEnd).filterNot(PianoKeys::isBlack)
    val blackKeys: List<Int> = (rangeStart..rangeEnd).filter(PianoKeys::isBlack)
    val whiteKeyCount: Int get() = whiteKeys.size

    /** White keys from the start of the range up to (not including) [midi]. */
    fun whiteKeysBefore(midi: Int): Int {
        // whiteKeys is sorted: the insertion point is the count below
        val index = whiteKeys.binarySearch(midi)
        return if (index >= 0) index else -index - 1
    }

    /** The middle of [midi]'s key, which is also its falling-note lane. A black key sits on the line between two white keys. */
    fun centerX(midi: Int): Double {
        val before = whiteKeysBefore(midi).toDouble()
        return if (PianoKeys.isBlack(midi)) before else before + 0.5
    }

    /** Left edge of black key [midi], [blackWidth] wide (in white-key widths). */
    fun blackKeyLeft(midi: Int, blackWidth: Double): Double {
        val before = whiteKeysBefore(midi)
        // No white key below it (a range starting on a black key): flush with the left edge, like iOS
        return if (before == 0) 0.0 else before - blackWidth / 2
    }

    /**
     * The key under a touch at [x] (white-key widths) and [yFraction] (0 = top, 1 = bottom of the keys). Black keys
     * cover the top [blackHeight] of the white keys and win where they overlap. Null outside the keyboard.
     */
    fun keyAt(x: Double, yFraction: Double, blackWidth: Double = BLACK_WIDTH, blackHeight: Double = BLACK_HEIGHT): Int? {
        if (whiteKeys.isEmpty() || x < 0 || x >= whiteKeyCount || yFraction < 0 || yFraction > 1) return null
        if (yFraction < blackHeight) {
            // At most the two black keys beside this white key can be under the touch
            val white = floor(x).toInt()
            for (candidate in listOfNotNull(whiteKeys.getOrNull(white)?.minus(1), whiteKeys.getOrNull(white)?.plus(1))) {
                if (candidate !in rangeStart..rangeEnd || !PianoKeys.isBlack(candidate)) continue
                val left = blackKeyLeft(candidate, blackWidth)
                if (x >= left && x < left + blackWidth) return candidate
            }
        }
        return whiteKeys[floor(x).toInt().coerceIn(0, whiteKeyCount - 1)]
    }

    companion object {
        /** Ratio of black key width to white key width. */
        const val BLACK_WIDTH = 0.6
        /** Ratio of black key height to white key height. */
        const val BLACK_HEIGHT = 0.62
    }
}
