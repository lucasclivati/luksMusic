// Dsp.kt — the few signal-processing building blocks the pitch code needs, standing in for Apple's Accelerate
// (vDSP) on iOS: a radix-2 FFT, the Hann window, RMS and the Goertzel filter.
package com.lukstrike.luksmusic.core.pitch

import java.util.concurrent.ConcurrentHashMap
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** An in-place complex FFT of a power-of-two [size]; the tables are made once per size and shared (read only). */
class Fft private constructor(val size: Int) {
    private val levels = Integer.numberOfTrailingZeros(size)
    private val cosTable = DoubleArray(size / 2) { cos(2 * PI * it / size) }
    private val sinTable = DoubleArray(size / 2) { sin(2 * PI * it / size) }
    private val reversed = IntArray(size) { Integer.reverse(it) ushr (32 - levels) }

    /** Forward transform (e^-i), or the inverse without the 1/size scale. */
    fun transform(real: DoubleArray, imaginary: DoubleArray, inverse: Boolean = false) {
        for (index in 0 until size) {
            val other = reversed[index]
            if (other > index) {
                var swap = real[index]; real[index] = real[other]; real[other] = swap
                swap = imaginary[index]; imaginary[index] = imaginary[other]; imaginary[other] = swap
            }
        }
        val sign = if (inverse) 1.0 else -1.0
        var half = 1
        while (half < size) {
            val step = size / (half * 2)
            var start = 0
            while (start < size) {
                var k = 0
                for (offset in start until start + half) {
                    val c = cosTable[k]
                    val s = sign * sinTable[k]
                    val pair = offset + half
                    val tr = real[pair] * c - imaginary[pair] * s
                    val ti = real[pair] * s + imaginary[pair] * c
                    real[pair] = real[offset] - tr
                    imaginary[pair] = imaginary[offset] - ti
                    real[offset] += tr
                    imaginary[offset] += ti
                    k += step
                }
                start += half * 2
            }
            half *= 2
        }
    }

    companion object {
        private val plans = ConcurrentHashMap<Int, Fft>()

        fun of(size: Int): Fft {
            require(size >= 2 && size and (size - 1) == 0) { "FFT size must be a power of two: $size" }
            return plans.getOrPut(size) { Fft(size) }
        }

        fun nextPowerOfTwo(value: Int): Int {
            var size = 2
            while (size < value) size *= 2
            return size
        }
    }
}

internal object Dsp {

    /** vDSP's Hann window: 0.5 (1 - cos(2πn/N)) for n in 0 until N. The scale never matters here (ratios only). */
    fun hann(count: Int): FloatArray =
        FloatArray(count) { (0.5 * (1 - cos(2 * PI * it / count))).toFloat() }

    /** [samples] multiplied by a Hann window of the same length. */
    fun windowed(samples: FloatArray): FloatArray {
        val window = hann(samples.size)
        return FloatArray(samples.size) { samples[it] * window[it] }
    }

    fun rms(samples: FloatArray, offset: Int = 0, count: Int = samples.size): Float {
        if (count <= 0) return 0f
        var sum = 0.0
        for (index in offset until offset + count) sum += samples[index].toDouble() * samples[index]
        return sqrt(sum / count).toFloat()
    }

    /** Power of [samples] at [frequency] (one DFT bin at any frequency). */
    fun goertzel(samples: FloatArray, frequency: Double, sampleRate: Double): Float {
        val coefficient = (2 * cos(2 * PI * frequency / sampleRate)).toFloat()
        var previous = 0f
        var beforePrevious = 0f
        for (sample in samples) {
            val current = sample + coefficient * previous - beforePrevious
            beforePrevious = previous
            previous = current
        }
        return previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious
    }

    /** Swift's `suffix`: the last [count] of the first [size] values of [values], or all of them when fewer. */
    fun suffix(values: FloatArray, size: Int, count: Int): FloatArray =
        values.copyOfRange(size - minOf(size, count), size)

    /** The last [count] of the first [size] values of [values], zero-padded in front when there are fewer. */
    fun paddedSuffix(values: FloatArray, size: Int, count: Int): FloatArray {
        val result = FloatArray(count)
        val taken = minOf(size, count)
        System.arraycopy(values, size - taken, result, count - taken, taken)
        return result
    }
}
