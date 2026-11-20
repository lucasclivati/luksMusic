// TunerPitchTracker.kt — the tuner's ear (port of iOS Services/Audio/TunerPitchTracker.swift): a steady pitch from
// the microphone, hop after hop. Unlike the practice screens, which want the moment a key is struck, the tuner follows
// a note while it rings. The audio is low-passed (room hiss scattered the period of a fading low string by tens of
// cents), each window is read with YIN, quiet hops are ignored, and the pitch shown is the median of the last few
// readings, eased toward, so one stray reading (an octave error, the pluck's scrape) never moves the needle.
package com.lukstrike.luksmusic.core.pitch

import com.lukstrike.luksmusic.core.model.TunerMode
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.log2
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/** Not thread safe: use it from one thread (the microphone's). */
class TunerPitchTracker(val sampleRate: Double, val settings: Settings) {

    /** The pitches listened for, in hertz. */
    data class Settings(val lowest: Double, val highest: Double) {
        constructor(mode: TunerMode) : this(mode.lowestFrequency, mode.highestFrequency)
    }

    /** Samples read at once: about four periods of the lowest pitch (4096 for the guitar, 8192 for the piano at 48 kHz). */
    val windowSize: Int = run {
        val periods = 4 * sampleRate / maxOf(settings.lowest, 1.0)
        maxOf(1024, 1 shl ceil(log2(periods)).toInt())
    }

    /** Never treat as sound anything quieter than this (RMS). */
    var minimumGate = 0.002f
    /** A reading this clear or better is a pitch; below it, noise or a chord. */
    var minimumClarity = 0.75
    /** How far the shown pitch moves toward each new median, while the note stays the same. */
    var easing = 0.35
    /** How long the last pitch stays on screen after the sound stops. */
    var holdSeconds = 1.2

    /** Level of the last hop (RMS). */
    var level = 0f
        private set
    /** The pitch shown, null before the first note and after the hold. */
    var frequency: Double? = null
        private set

    private val window = FloatArray(windowSize)
    private var filled = 0
    // Well above the highest pitch listened for, so its own level is untouched
    private val filter = LowPass(minOf(settings.highest * 1.1, sampleRate * 0.4), sampleRate)
    private var noiseFloor = 0.002f
    /** Recent readings, as log2 of the frequency. */
    private val recent = ArrayList<Double>()
    private var shown: Double? = null
    private var quietSeconds = 0.0
    private var hop = FloatArray(0)

    /** Forgets everything heard (when listening restarts, or after the app played a reference tone). */
    fun reset() {
        window.fill(0f)
        filled = 0
        filter.reset()
        recent.clear()
        shown = null
        frequency = null
        quietSeconds = 0.0
        level = 0f
    }

    /** Takes the next hop of audio ([count] samples of [samples] from [offset]) and returns the pitch to show (null when
     *  nothing is heard). */
    fun process(samples: FloatArray, offset: Int = 0, count: Int = samples.size - offset): Double? {
        if (count <= 0) return frequency
        if (hop.size < count) hop = FloatArray(count)
        var sumOfSquares = 0f
        for (index in 0 until count) {
            val sample = samples[offset + index]
            sumOfSquares += sample * sample
            hop[index] = filter.process(sample)
        }
        level = sqrt(sumOfSquares / count)
        // The quietest level heard lately: falls at once, rises slowly while sound goes on
        noiseFloor = if (level < noiseFloor) maxOf(level, 0.0001f) else noiseFloor * 1.0015f

        if (count >= windowSize) {
            System.arraycopy(hop, count - windowSize, window, 0, windowSize)
        } else {
            System.arraycopy(window, count, window, 0, windowSize - count)
            System.arraycopy(hop, 0, window, windowSize - count, count)
        }
        filled = minOf(windowSize, filled + count)

        val hopSeconds = count / sampleRate
        val gate = maxOf(minimumGate, noiseFloor * 3)
        if (filled < windowSize || level < gate) return heardNothing(hopSeconds)
        val estimate = PitchDetector.estimate(window, sampleRate, settings.lowest, settings.highest)
        if (estimate == null || estimate.clarity < minimumClarity ||
            estimate.frequency < settings.lowest * 0.97 || estimate.frequency > settings.highest * 1.03
        ) {
            return heardNothing(hopSeconds)
        }

        quietSeconds = 0.0
        recent.add(log2(estimate.frequency))
        while (recent.size > RECENT_COUNT) recent.removeAt(0)
        if (recent.size < READINGS_TO_SHOW) return frequency

        val median = recent.sorted()[recent.size / 2]
        val current = shown
        shown = if (current != null && abs(median - current) * 1200 < NEW_NOTE_CENTS) {
            current + easing * (median - current)
        } else {
            median
        }
        frequency = shown?.let { 2.0.pow(it) }
        return frequency
    }

    private fun heardNothing(seconds: Double): Double? {
        quietSeconds += seconds
        // A gap ends the note: the next one starts from fresh readings
        if (quietSeconds > 0.15) recent.clear()
        if (quietSeconds > holdSeconds) {
            shown = null
            frequency = null
        }
        return frequency
    }

    private companion object {
        const val RECENT_COUNT = 5
        /** Readings needed before a new note is shown. */
        const val READINGS_TO_SHOW = 3
        /** A median this far from the shown pitch is a new note: jump to it instead of easing. */
        const val NEW_NOTE_CENTS = 40.0
    }
}

/** Two second-order Butterworth low-pass sections (24 dB per octave). */
private class LowPass(cutoff: Double, sampleRate: Double) {
    private class Section {
        var x1 = 0.0; var x2 = 0.0; var y1 = 0.0; var y2 = 0.0
    }

    private val b0: Double
    private val b1: Double
    private val b2: Double
    private val a1: Double
    private val a2: Double
    private var first = Section()
    private var second = Section()

    init {
        val omega = 2 * PI * cutoff / sampleRate
        val alpha = sin(omega) / (2 * sqrt(0.5))
        val cosine = cos(omega)
        val a0 = 1 + alpha
        b0 = (1 - cosine) / 2 / a0
        b1 = (1 - cosine) / a0
        b2 = b0
        a1 = -2 * cosine / a0
        a2 = (1 - alpha) / a0
    }

    fun reset() {
        first = Section()
        second = Section()
    }

    fun process(sample: Float): Float = run(run(sample.toDouble(), first), second).toFloat()

    private fun run(value: Double, section: Section): Double {
        val output = b0 * value + b1 * section.x1 + b2 * section.x2 - a1 * section.y1 - a2 * section.y2
        section.x2 = section.x1
        section.x1 = value
        section.y2 = section.y1
        section.y1 = output
        return output
    }
}
