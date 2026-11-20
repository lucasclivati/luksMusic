// Metronome.kt — port of Services/Audio/MetronomeService.swift. Each screen that needs one makes its own.
//
// It clicks the beats of a measure, the first one accented, at a tempo that can change while it runs. iOS ticks on a
// strict GCD timer; here the beats are counted in audio frames on the audio thread itself, so every click lands on
// its exact sample whatever the screen is doing (no drift, no jitter). Each beat is reported on the main thread when
// its click comes out of the speaker.
//
// PUBLIC API — other features use these members; keep their signatures stable.
package com.lukstrike.luksmusic.audio

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.lukstrike.luksmusic.core.audio.synth.AudioClock
import com.lukstrike.luksmusic.core.audio.synth.ClickScheduler

class Metronome(private val audio: AudioEngine) {

    /** [index] is 0-based within the measure; [isAccent] on the first beat; [isSilent] when its click was left out. */
    data class Beat(val index: Int, val isAccent: Boolean, val isSilent: Boolean = false)

    /** Called on the main thread at each beat. Set and read on the main thread only. */
    var onBeat: ((Beat) -> Unit)? = null

    /** Main thread only. */
    var isRunning: Boolean = false
        private set

    /** Clicks are silent (only [onBeat] fires) when true. */
    @Volatile var isMuted: Boolean = false

    /**
     * While the microphone listens, a click it would hear from the speaker is left out (it would take it for a note);
     * the beat is still reported. Checked at every beat, so plugging headphones in brings the sound back.
     */
    @Volatile var silentWithoutHeadphones: Boolean = false

    private val mainHandler = Handler(Looper.getMainLooper())
    /** Changes on every start and stop (main thread), so a beat still on its way after a stop is dropped. */
    private var run = 0

    // Shared with the audio thread, under `lock`
    private val lock = Any()
    private var framesPerBeat = 0.0
    private var beatsPerMeasure = 4
    private var nextBeat = 1
    /** Absolute frame of the next click; negative = at the start of the next block. */
    private var nextClickFrame = -1.0
    private var lastClickFrame = -1.0
    private var tempoChanged = false
    private var clockRun = 0
    private var secondsPerBeat = 0.5

    private val clock = object : AudioClock {
        override fun onBlock(blockStart: Long, frames: Int, sampleRate: Int, clicks: ClickScheduler) {
            synchronized(lock) {
                framesPerBeat = secondsPerBeat * sampleRate
                if (nextClickFrame < 0) nextClickFrame = blockStart.toDouble()
                if (tempoChanged) {
                    tempoChanged = false
                    // The next click comes one new beat after the last, at once if that has passed
                    if (lastClickFrame >= 0) nextClickFrame = maxOf(blockStart.toDouble(), lastClickFrame + framesPerBeat)
                }
                val blockEnd = blockStart + frames
                while (nextClickFrame < blockEnd) {
                    val offset = (nextClickFrame - blockStart).toInt().coerceIn(0, frames - 1)
                    click(offset, sampleRate, clicks)
                    lastClickFrame = nextClickFrame
                    nextClickFrame += framesPerBeat
                }
            }
        }
    }

    /** Starts on beat 1 of a measure of [beatsPerMeasure] beats. */
    fun start(bpm: Int, beatsPerMeasure: Int) {
        if (isRunning) return
        isRunning = true
        run += 1
        synchronized(lock) {
            secondsPerBeat = beatLength(bpm)
            this.beatsPerMeasure = maxOf(1, beatsPerMeasure)
            nextBeat = 1
            nextClickFrame = -1.0
            lastClickFrame = -1.0
            tempoChanged = false
            clockRun = run
        }
        audio.addClock(clock)
    }

    fun stop() {
        if (!isRunning) return
        isRunning = false
        run += 1
        audio.removeClock(clock)
    }

    /** A new tempo applies at once: the next click comes one new beat after the last (at once if that has passed),
     *  keeping the place in the measure. */
    fun setTempo(bpm: Int) {
        val interval = beatLength(bpm)
        synchronized(lock) {
            if (interval == secondsPerBeat) return
            secondsPerBeat = interval
            tempoChanged = true
        }
    }

    /** On the audio thread, under `lock`. */
    private fun click(offset: Int, sampleRate: Int, clicks: ClickScheduler) {
        val number = nextBeat
        nextBeat = number % beatsPerMeasure + 1
        val isSilent = isMuted || (silentWithoutHeadphones && !audio.hasHeadphones)
        if (!isSilent) clicks.click(offset, accent = number == 1)
        // Shown when the click is heard: its place in the block plus what the output still has queued
        val delayMs = (offset + audio.outputLatencyFrames) * 1000L / sampleRate
        val beat = Beat(index = number - 1, isAccent = number == 1, isSilent = isSilent)
        val beatRun = clockRun
        mainHandler.postAtTime({
            if (run == beatRun) onBeat?.invoke(beat)
        }, SystemClock.uptimeMillis() + delayMs)
    }

    private fun beatLength(bpm: Int): Double = 60.0 / maxOf(1, bpm)
}
