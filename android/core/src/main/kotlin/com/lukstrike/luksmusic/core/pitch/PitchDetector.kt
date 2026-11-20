// PitchDetector.kt — the pitch of a window of samples (port of PitchDetector in iOS Services/Audio/PitchDetection.swift).
// YIN: the first strong dip of the normalized difference function, which avoids the octave errors of picking the
// strongest autocorrelation peak on a piano's harmonics.
package com.lukstrike.luksmusic.core.pitch

import kotlin.math.log2

object PitchDetector {

    data class Estimate(
        val frequency: Double,
        /** 0 (noise) to 1 (perfectly periodic). */
        val clarity: Double,
    ) {
        val midiNote: Int get() = swiftRound(69.0 + 12.0 * log2(frequency / 440.0))
    }

    const val LOWEST_FREQUENCY = 50.0 // below A1
    const val HIGHEST_FREQUENCY = 4300.0 // above C8

    /** A dip must go below this to count as the period. */
    private const val DIP_THRESHOLD = 0.15

    /**
     * The window should hold at least two periods of the lowest note: 4096 samples at 44.1 or 48 kHz.
     * [lowest] and [highest] narrow the pitches looked for (the tuner goes down to the piano's A0).
     */
    fun estimate(
        samples: FloatArray,
        sampleRate: Double,
        lowest: Double = LOWEST_FREQUENCY,
        highest: Double = HIGHEST_FREQUENCY,
    ): Estimate? {
        val maxLag = minOf(samples.size / 2, (sampleRate / lowest).toInt())
        val minLag = maxOf(2, (sampleRate / highest).toInt())
        if (maxLag <= minLag + 2) return null

        val difference = differenceFunction(samples, maxLag)

        // d'(lag) = d(lag) / mean of d(1...lag): removes the bias toward short lags
        val normalized = DoubleArray(maxLag + 1) { 1.0 }
        var running = 0.0
        for (lag in 1..maxLag) {
            running += difference[lag]
            normalized[lag] = if (running > 0) difference[lag] * lag / running else 1.0
        }

        // The first dip under the threshold is the period; multiples of it are deeper or equal but an octave low
        var lag = minLag
        var found: Int? = null
        while (lag < maxLag) {
            if (normalized[lag] < DIP_THRESHOLD) {
                while (lag + 1 < maxLag && normalized[lag + 1] < normalized[lag]) lag += 1
                found = lag
                break
            }
            lag += 1
        }
        // No dip under the threshold (a real room's echo, a bright piano tone): take the first dip close to the
        // deepest one, as long as the deepest is clearly periodic
        if (found == null) {
            var deepest = Double.MAX_VALUE
            for (index in minLag until maxLag) deepest = minOf(deepest, normalized[index])
            if (deepest < 0.3) {
                lag = minLag + 1
                while (lag < maxLag) {
                    if (normalized[lag] <= deepest + 0.05 && normalized[lag] <= normalized[lag - 1] &&
                        normalized[lag] <= normalized[lag + 1]
                    ) {
                        found = lag
                        break
                    }
                    lag += 1
                }
            }
        }
        val best = found ?: return null
        if (best <= 0 || best >= maxLag) return null

        // The dip's exact place between two lags, from a parabola through the raw difference: the normalized one
        // leans with its running mean, which pulled high notes a few cents sharp
        val before = difference[best - 1]
        val center = difference[best]
        val after = difference[best + 1]
        val curvature = before - 2 * center + after
        val shift = if (curvature > 0) (before - after) / (2 * curvature) else 0.0
        val refined = best + shift.coerceIn(-1.0, 1.0)
        if (refined <= 0) return null
        val clarity = (1 - normalized[best]).coerceIn(0.0, 1.0)
        return Estimate(sampleRate / refined, clarity)
    }

    /**
     * d(lag) = sum over the first `size - maxLag` samples of (x[i] - x[i + lag])², for lag 0...maxLag.
     *
     * iOS sums it lag by lag with vDSP's SIMD. Here it is expanded as energy(start) + energy(lag) - 2 · correlation,
     * the correlation taken with one FFT pair: the same values (in double precision) for a fraction of the work, which
     * matters because the tuner reads an 8192-sample window about 23 times a second.
     */
    internal fun differenceFunction(samples: FloatArray, maxLag: Int): DoubleArray {
        val count = samples.size
        val window = count - maxLag
        val size = Fft.nextPowerOfTwo(count)
        val work = workspace.get().ensure(size)
        val real = work.real
        val imaginary = work.imaginary
        // a = the first `window` samples in the real part, b = all the samples in the imaginary part
        for (index in 0 until size) {
            real[index] = if (index < window) samples[index].toDouble() else 0.0
            imaginary[index] = if (index < count) samples[index].toDouble() else 0.0
        }
        val fft = Fft.of(size)
        fft.transform(real, imaginary)
        // Split the two spectra, then conj(A) · B; no wrap-around since a's lag never runs past b's end
        val productReal = work.productReal
        val productImaginary = work.productImaginary
        for (k in 0 until size) {
            val mirror = (size - k) and (size - 1)
            val zr = real[k]
            val zi = imaginary[k]
            val mr = real[mirror]
            val mi = -imaginary[mirror]
            val ar = (zr + mr) / 2
            val ai = (zi + mi) / 2
            val br = (zi - mi) / 2
            val bi = -(zr - mr) / 2
            productReal[k] = ar * br + ai * bi
            productImaginary[k] = ar * bi - ai * br
        }
        fft.transform(productReal, productImaginary, inverse = true)

        var startEnergy = 0.0
        for (index in 0 until window) startEnergy += samples[index].toDouble() * samples[index]
        val prefix = work.prefix
        prefix[0] = 0.0
        for (index in 0 until count) prefix[index + 1] = prefix[index] + samples[index].toDouble() * samples[index]

        val difference = DoubleArray(maxLag + 1)
        for (lag in 1..maxLag) {
            val shiftedEnergy = prefix[lag + window] - prefix[lag]
            val correlation = productReal[lag] / size
            difference[lag] = maxOf(0.0, startEnergy + shiftedEnergy - 2 * correlation)
        }
        return difference
    }

    /** Buffers reused from one window to the next on each thread (the microphone reads on its own thread). */
    private class Workspace {
        var real = DoubleArray(0); var imaginary = DoubleArray(0)
        var productReal = DoubleArray(0); var productImaginary = DoubleArray(0)
        var prefix = DoubleArray(0)

        fun ensure(size: Int): Workspace {
            if (real.size < size) {
                real = DoubleArray(size); imaginary = DoubleArray(size)
                productReal = DoubleArray(size); productImaginary = DoubleArray(size)
                prefix = DoubleArray(size + 1)
            }
            return this
        }
    }

    private val workspace = ThreadLocal.withInitial { Workspace() }
}

/** Swift's `rounded()`: halves away from zero. */
internal fun swiftRound(value: Double): Int =
    if (value >= 0) kotlin.math.floor(value + 0.5).toInt() else -kotlin.math.floor(-value + 0.5).toInt()
