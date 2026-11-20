// Effects.kt — the master effects after the piano voices: a light hall reverb (iOS uses AVAudioUnitReverb's medium
// hall at 25 % wet) and a soft limiter, so a ten-note chord with the pedal down never clips. Audio thread only.
package com.lukstrike.luksmusic.core.audio.synth

import kotlin.math.abs
import kotlin.math.exp

/** A small Schroeder/Freeverb-style stereo reverb: four damped combs and two allpasses per channel. */
internal class Reverb(sampleRate: Int) {
    private val scale = sampleRate / 44_100.0
    private val left = Channel(0)
    private val right = Channel(STEREO_SPREAD)

    /** 0 dry … 1 very wet (0.25 is the app's default, like the iOS concert hall setting). */
    var amount = 0.25f

    fun reset() {
        left.reset(); right.reset()
    }

    /** Adds the reverb of [inLeft]/[inRight] into [outLeft]/[outRight] (the dry signal is left as is). */
    fun process(inLeft: FloatArray, inRight: FloatArray, outLeft: FloatArray, outRight: FloatArray, frames: Int) {
        val wet = amount * WET_SCALE
        if (wet <= 0f) return
        for (f in 0 until frames) {
            val input = (inLeft[f] + inRight[f]) * INPUT_GAIN
            outLeft[f] += left.process(input) * wet
            outRight[f] += right.process(input) * wet
        }
    }

    private inner class Channel(spread: Int) {
        private val combs = COMB_LENGTHS.map { Comb(((it + spread) * scale).toInt()) }.toTypedArray()
        private val allpasses = ALLPASS_LENGTHS.map { Allpass(((it + spread) * scale).toInt()) }.toTypedArray()

        fun reset() {
            combs.forEach { it.reset() }; allpasses.forEach { it.reset() }
        }

        fun process(input: Float): Float {
            var sum = 0f
            for (comb in combs) sum += comb.process(input)
            for (allpass in allpasses) sum = allpass.process(sum)
            return sum
        }
    }

    private class Comb(length: Int) {
        private val buffer = FloatArray(maxOf(1, length))
        private var index = 0
        private var filtered = 0f

        fun reset() { buffer.fill(0f); filtered = 0f }

        fun process(input: Float): Float {
            val output = buffer[index]
            filtered = output * (1 - DAMPING) + filtered * DAMPING
            buffer[index] = input + filtered * FEEDBACK
            if (++index == buffer.size) index = 0
            return output
        }
    }

    private class Allpass(length: Int) {
        private val buffer = FloatArray(maxOf(1, length))
        private var index = 0

        fun reset() { buffer.fill(0f) }

        fun process(input: Float): Float {
            val delayed = buffer[index]
            buffer[index] = input + delayed * 0.5f
            if (++index == buffer.size) index = 0
            return delayed - input
        }
    }

    private companion object {
        // Freeverb's tunings (samples at 44.1 kHz), mutually prime so the echoes never line up
        val COMB_LENGTHS = intArrayOf(1116, 1277, 1422, 1557).toList()
        val ALLPASS_LENGTHS = intArrayOf(556, 441).toList()
        const val STEREO_SPREAD = 23
        /** A medium hall: about 1.8 s to fade. */
        const val FEEDBACK = 0.82f
        /** The walls soak up the treble. */
        const val DAMPING = 0.35f
        const val INPUT_GAIN = 0.03f
        const val WET_SCALE = 1.6f
    }
}

/**
 * Keeps the mix under full scale: a peak follower with a fast attack and a slow release turns the level down when
 * the sum of the voices grows, and a soft clipper rounds any peak that slips through. Below the threshold the sound is
 * untouched.
 */
internal class Limiter(sampleRate: Int) {
    private val attack = exp(-1.0 / (0.001 * sampleRate)).toFloat()
    private val release = exp(-1.0 / (0.25 * sampleRate)).toFloat()
    private var envelope = 0f

    fun process(left: FloatArray, right: FloatArray, frames: Int) {
        var env = envelope
        for (f in 0 until frames) {
            val peak = maxOf(abs(left[f]), abs(right[f]))
            env = if (peak > env) peak + (env - peak) * attack else peak + (env - peak) * release
            val gain = if (env > THRESHOLD) THRESHOLD / env else 1f
            left[f] = softClip(left[f] * gain)
            right[f] = softClip(right[f] * gain)
        }
        envelope = if (env < 1e-9f) 0f else env
    }

    /** Linear up to the knee, then bends smoothly toward ±1 without ever reaching it. */
    private fun softClip(x: Float): Float {
        val magnitude = abs(x)
        if (magnitude <= KNEE) return x
        val over = magnitude - KNEE
        val bent = KNEE + (1 - KNEE) * over / (over + (1 - KNEE))
        return if (x < 0) -bent else bent
    }

    private companion object {
        const val THRESHOLD = 0.7f
        const val KNEE = 0.8f
    }
}
