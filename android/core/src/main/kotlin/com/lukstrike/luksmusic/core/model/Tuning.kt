// Tuning.kt — the tuner's music theory, apart from the microphone so it can be tested: frequency to the nearest note
// and how many cents off it is, for any A4 reference, and the guitar's standard tuning (iOS Models/Tuning.swift).
package com.lukstrike.luksmusic.core.model

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.log2
import kotlin.math.pow

/** What the tuner tunes: the six guitar strings, or any piano key (chromatic). [key] is the saved value. */
enum class TunerMode(val key: String) {
    GUITAR("guitar"),
    PIANO("piano");

    /** The lowest pitch the microphone listens for: below drop D on the guitar, the piano's A0. */
    val lowestFrequency: Double
        get() = when (this) {
            GUITAR -> 60.0
            PIANO -> 26.0
        }

    /** The highest pitch the microphone listens for: the 12th fret of the high E string, the piano's C8. */
    val highestFrequency: Double
        get() = when (this) {
            GUITAR -> 1_400.0
            PIANO -> 4_300.0
        }

    companion object {
        fun fromKey(key: String?): TunerMode = entries.firstOrNull { it.key == key } ?: GUITAR
    }
}

/** How far the heard pitch is from a note. */
data class TuningReading(
    /** The note the pitch is compared with. */
    val midi: Int,
    /** Negative is flat (below the note), positive is sharp. */
    val cents: Double,
    /** The pitch heard. */
    val frequency: Double,
    /** The note's exact pitch at the chosen A4. */
    val targetFrequency: Double,
) {
    val isInTune: Boolean get() = abs(cents) <= IN_TUNE_CENTS
    val isFlat: Boolean get() = cents < -IN_TUNE_CENTS
    val isSharp: Boolean get() = cents > IN_TUNE_CENTS

    companion object {
        /** Within ±5 cents counts as in tune. */
        const val IN_TUNE_CENTS = 5.0
    }
}

object Tuning {

    const val DEFAULT_A4 = 440.0

    /** The reference A can be set from baroque pitch (415) to a semitone above 440 (466). */
    val a4Range = 415.0..466.0

    /** The piano's keys, A0 to C8. */
    val pianoRange = 21..108

    /** Standard guitar tuning, low to high: E2 A2 D3 G3 B3 E4. */
    val guitarStrings = listOf(40, 45, 50, 55, 59, 64)

    private val solfegeNames = listOf("Dó", "Dó♯", "Ré", "Ré♯", "Mi", "Fá", "Fá♯", "Sol", "Sol♯", "Lá", "Lá♯", "Si")
    private val letterNames = listOf("C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B")

    /** The exact pitch of a MIDI note when A4 (MIDI 69) is [a4] Hz. */
    fun frequency(midi: Int, a4: Double = DEFAULT_A4): Double = a4 * 2.0.pow((midi - 69.0) / 12.0)

    /** Cents from [target] to [frequency] (100 cents to a semitone, 1200 to an octave). */
    fun cents(target: Double, frequency: Double): Double = 1200.0 * log2(frequency / target)

    /**
     * The nearest note to [frequency] within [range], and how far off it is. Null when the pitch is outside the range
     * by more than half a semitone, or isn't a pitch.
     */
    fun nearestNote(frequency: Double, a4: Double = DEFAULT_A4, range: IntRange = pianoRange): TuningReading? {
        if (!(frequency > 0) || !frequency.isFinite() || !(a4 > 0)) return null
        val exact = 69.0 + 12.0 * log2(frequency / a4)
        val midi = swiftRound(exact)
        if (midi !in range) return null
        val target = frequency(midi, a4)
        return TuningReading(midi, cents(target, frequency), frequency, target)
    }

    /** Index in [guitarStrings] of the string whose pitch is closest to [frequency]. */
    fun nearestGuitarString(frequency: Double, a4: Double = DEFAULT_A4): Int? {
        if (!(frequency > 0) || !frequency.isFinite()) return null
        return guitarStrings.indices.minByOrNull { abs(cents(frequency(guitarStrings[it], a4), frequency)) }
    }

    /** The heard pitch against one guitar string, however far off it is (a string can be tuned up from far below). */
    fun reading(frequency: Double, string: Int, a4: Double = DEFAULT_A4): TuningReading? {
        if (!(frequency > 0) || !frequency.isFinite() || string !in guitarStrings.indices) return null
        val midi = guitarStrings[string]
        val target = frequency(midi, a4)
        return TuningReading(midi, cents(target, frequency), frequency, target)
    }

    /** The note's name without its octave: "Mi" in Portuguese, "E" in English. */
    fun noteName(midi: Int, letters: Boolean): String =
        (if (letters) letterNames else solfegeNames)[Math.floorMod(midi, 12)]

    /** The note's octave in scientific pitch notation (middle C is C4). */
    fun octave(midi: Int): Int = floor(midi / 12.0).toInt() - 1

    /** The A4 reference kept inside the allowed range, in whole hertz. */
    fun clampedA4(value: Double): Double =
        minOf(a4Range.endInclusive, maxOf(a4Range.start, swiftRound(value).toDouble()))

    /** Swift's `rounded()`: halves away from zero (Kotlin's roundToInt rounds halves up, -0.5 to 0). */
    private fun swiftRound(value: Double): Int =
        if (value >= 0) floor(value + 0.5).toInt() else -floor(-value + 0.5).toInt()
}
