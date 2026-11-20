// StrikeAnalyzer.kt — port of StrikeAnalyzer and ChordMatcher in iOS Services/Audio/PitchDetection.swift.
package com.lukstrike.luksmusic.core.pitch

import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Which note a strike added. It is the note whose harmonics gained energy from just before the strike to just after
 * it, so notes still ringing (or held by the pedal) stay out of the answer. A pitch reading of the whole sound hears
 * two ringing notes as their common lower octave, which was the wrong note the lessons reported.
 */
object StrikeAnalyzer {
    /** The notes considered, A0 sharp to E7. */
    val notes = 28..100
    private const val HARMONICS = 6
    private const val HIGHEST_FREQUENCY = 5000.0
    private const val FFT_SIZE = 16_384

    /** The best note must stand this far above the typical note: noise lifts every note alike. */
    private const val PEAK_RATIO = 6f
    /** The expected note is taken when it gained at least this share of what the best note gained. */
    private const val EXPECTED_SHARE = 0.6f
    /** Energy gained against the energy the note already had. The expected note may be ringing already (a key
     *  played again), so it needs less. */
    private const val FRESH_EXPECTED = 0.4f
    private const val FRESH_OTHER = 1f
    /** The note's new energy as a share of all the sound after the strike. */
    private const val MINIMUM_SHARE = 0.03f
    /** Energy gained on the note's harmonics against energy gained halfway between them. */
    private const val HARMONIC_RATIO = 3f
    /** A struck note's lowest partials are its strongest; a pick carried by upper partials only is another note's
     *  harmonic that happens to coincide. */
    private const val FUNDAMENTAL_SHARE = 0.25f

    class Spectrum(
        /** Power of each harmonic of each note in [notes]. */
        val harmonicPowers: Array<FloatArray>,
        /** Power halfway between the note's harmonics, from the first to the fifth. */
        val betweenPowers: Array<FloatArray>,
        /** All the sound's power, on the same scale. */
        val totalPower: Float,
    )

    private fun noteFrequency(midi: Int) = 440.0 * 2.0.pow((midi - 69.0) / 12.0)

    /** Strings are a little stiff, so their upper harmonics run sharp. */
    private fun stretchedHarmonic(number: Int, fundamental: Double): Double {
        val n = number.toDouble()
        return n * fundamental * sqrt(1 + 0.0004 * n * n)
    }

    fun spectrum(samples: FloatArray, sampleRate: Double): Spectrum {
        val count = minOf(samples.size, FFT_SIZE)
        val noteCount = notes.count()
        if (count <= 0) {
            return Spectrum(Array(noteCount) { FloatArray(HARMONICS) }, Array(noteCount) { FloatArray(HARMONICS - 1) }, 0f)
        }

        val window = Dsp.hann(count)
        val real = DoubleArray(FFT_SIZE)
        val imaginary = DoubleArray(FFT_SIZE)
        val start = samples.size - count
        for (index in 0 until count) real[index] = (samples[start + index] * window[index]).toDouble()
        Fft.of(FFT_SIZE).transform(real, imaginary)

        val half = FFT_SIZE / 2
        val power = FloatArray(half + 1)
        var sum = 0.0
        for (bin in 0..half) {
            power[bin] = (real[bin] * real[bin] + imaginary[bin] * imaginary[bin]).toFloat()
            sum += if (bin == 0 || bin == half) power[bin].toDouble() else 2.0 * power[bin]
        }
        // Parseval: the window's energy, on the same scale as the bins, whatever scale the transform uses
        val total = (sum / FFT_SIZE * count / 2).toFloat()

        val binsPerHertz = FFT_SIZE / sampleRate
        val top = minOf(HIGHEST_FREQUENCY, sampleRate / 2 * 0.98)
        fun strongest(frequency: Double, tolerance: Double): Float {
            if (frequency > top) return 0f
            val low = maxOf(1, floor(frequency * (1 - tolerance) * binsPerHertz).toInt())
            val high = minOf(half, maxOf(low, ceil(frequency * (1 + tolerance) * binsPerHertz).toInt()))
            var best = 0f
            for (bin in low..high) best = maxOf(best, power[bin])
            return best
        }

        val harmonicPowers = Array(noteCount) { FloatArray(HARMONICS) }
        val betweenPowers = Array(noteCount) { FloatArray(HARMONICS - 1) }
        for ((index, midi) in notes.withIndex()) {
            val fundamental = noteFrequency(midi)
            for (number in 1..HARMONICS) {
                harmonicPowers[index][number - 1] = strongest(stretchedHarmonic(number, fundamental), 0.01)
            }
            for (number in 1 until HARMONICS) {
                betweenPowers[index][number - 1] = strongest((number + 0.5) * fundamental, 0.0)
            }
        }
        return Spectrum(harmonicPowers, betweenPowers, total)
    }

    /** The note struck between [before] and [after], or null when nothing clearly new is sounding. */
    fun struckNote(before: Spectrum, after: Spectrum, expected: Int?): Int? {
        val count = notes.count()
        val gains = Array(count) { FloatArray(HARMONICS) }
        val score = FloatArray(count)
        val fresh = FloatArray(count)
        for (index in 0 until count) {
            var gained = 0f
            var had = 0f
            for (number in 0 until HARMONICS) {
                gains[index][number] = maxOf(0f, after.harmonicPowers[index][number] - before.harmonicPowers[index][number])
                gained += gains[index][number] / (number + 1)
                had += before.harmonicPowers[index][number] / (number + 1)
            }
            score[index] = gained
            fresh[index] = gained / maxOf(had, 1e-12f)
        }
        var best = 0
        for (index in 1 until count) if (score[index] > score[best]) best = index
        val top = score[best]
        if (!(top > 1e-9f)) return null
        if (top < PEAK_RATIO * score.sortedArray()[count / 2]) return null

        fun isNote(index: Int): Boolean {
            if (score[index] < MINIMUM_SHARE * after.totalPower) return false
            var between = 0f
            var onHarmonics = 0f
            for (number in 0 until HARMONICS - 1) {
                between += maxOf(0f, after.betweenPowers[index][number] - before.betweenPowers[index][number]) / (number + 1)
                onHarmonics += gains[index][number] / (number + 1)
            }
            return onHarmonics >= HARMONIC_RATIO * between
        }

        if (expected != null && expected in notes) {
            val index = expected - notes.first
            if (score[index] >= EXPECTED_SHARE * top && fresh[index] >= FRESH_EXPECTED && isNote(index)) return expected
        }
        if (fresh[best] < FRESH_OTHER || !isNote(best)) return null
        val midi = notes.first + best
        // Low notes reach a phone's microphone mostly through their second harmonic
        val lowest = gains[best][0] + (if (midi < 48) gains[best][1] else 0f)
        if (lowest < FUNDAMENTAL_SHARE * gains[best].sum()) return null
        return midi
    }

    /** The energy of a note's harmonics in a short window, to notice the moment it starts while others ring. */
    fun energy(midi: Int, samples: FloatArray, sampleRate: Double): Float {
        val shaped = Dsp.windowed(samples)
        val fundamental = noteFrequency(midi)
        var total = 0f
        for (number in 1..HARMONICS) {
            val frequency = stretchedHarmonic(number, fundamental)
            if (frequency >= sampleRate / 2 * 0.98) break
            total += maxOf(
                Dsp.goertzel(shaped, frequency * 0.99, sampleRate),
                Dsp.goertzel(shaped, frequency, sampleRate),
                Dsp.goertzel(shaped, frequency * 1.01, sampleRate),
            )
        }
        return total
    }
}

/**
 * Whether the notes a chord should have are all sounding. Telling several notes apart from nothing is hard, but
 * checking for known ones is not: each expected fundamental must stand out in the spectrum.
 */
object ChordMatcher {
    /** Below this share of the strongest note's energy, a note isn't considered present. */
    private const val PRESENCE_RATIO = 0.06f

    fun matches(samples: FloatArray, sampleRate: Double, expected: Set<Int>): Boolean {
        if (expected.isEmpty() || samples.size < 2048) return false
        val shaped = Dsp.windowed(samples)
        var strongest = 0f
        for (midi in 33..100) strongest = maxOf(strongest, energy(midi, shaped, sampleRate))
        if (!(strongest > 0)) return false
        return expected.all { energy(it, shaped, sampleRate) >= strongest * PRESENCE_RATIO }
    }

    /** The energy around a note's fundamental, allowing for a slightly out-of-tune instrument. */
    private fun energy(midi: Int, samples: FloatArray, sampleRate: Double): Float {
        val frequency = 440.0 * 2.0.pow((midi - 69.0) / 12.0)
        return maxOf(
            Dsp.goertzel(samples, frequency * 0.985, sampleRate),
            Dsp.goertzel(samples, frequency, sampleRate),
            Dsp.goertzel(samples, frequency * 1.015, sampleRate),
        )
    }
}
