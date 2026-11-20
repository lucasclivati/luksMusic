// Metronome.kt — the Android app's Metronome (audio/Metronome.kt) on the desktop audio: the beats are counted in
// audio frames on the audio thread, so each click lands on its exact sample, and each beat is reported to the screen
// when its click is heard.
package com.lukstrike.luksmusic.desktop.audio

import com.lukstrike.luksmusic.core.audio.synth.AudioClock
import com.lukstrike.luksmusic.core.audio.synth.ClickScheduler
import com.lukstrike.luksmusic.desktop.study.BeatClock
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.swing.SwingUtilities

class Metronome(private val audio: DesktopAudio) : BeatClock {

    /** [index] is 0-based within the measure; [isAccent] on the first beat. Called on the UI thread. */
    var onBeat: ((index: Int, isAccent: Boolean) -> Unit)? = null

    @Volatile override var isRunning = false
        private set

    private val lock = Any()
    private var secondsPerBeat = 0.5
    private var beatsPerMeasure = 4
    private var nextBeat = 1
    private var nextClickFrame = -1.0
    private var lastClickFrame = -1.0
    private var tempoChanged = false
    @Volatile private var run = 0

    private val clock = object : AudioClock {
        override fun onBlock(blockStart: Long, frames: Int, sampleRate: Int, clicks: ClickScheduler) {
            synchronized(lock) {
                val framesPerBeat = secondsPerBeat * sampleRate
                if (nextClickFrame < 0) nextClickFrame = blockStart.toDouble()
                if (tempoChanged) {
                    tempoChanged = false
                    if (lastClickFrame >= 0) nextClickFrame = maxOf(blockStart.toDouble(), lastClickFrame + framesPerBeat)
                }
                val blockEnd = blockStart + frames
                while (nextClickFrame < blockEnd) {
                    val offset = (nextClickFrame - blockStart).toInt().coerceIn(0, frames - 1)
                    val number = nextBeat
                    nextBeat = number % beatsPerMeasure + 1
                    clicks.click(offset, accent = number == 1)
                    report(number - 1, number == 1, (offset + audio.latencyFrames) * 1000L / sampleRate)
                    lastClickFrame = nextClickFrame
                    nextClickFrame += framesPerBeat
                }
            }
        }
    }

    override fun start(bpm: Int, beatsPerMeasure: Int) {
        if (isRunning) return
        isRunning = true
        synchronized(lock) {
            secondsPerBeat = 60.0 / maxOf(1, bpm)
            this.beatsPerMeasure = maxOf(1, beatsPerMeasure)
            nextBeat = 1
            nextClickFrame = -1.0
            lastClickFrame = -1.0
            tempoChanged = false
            run += 1
        }
        audio.addClock(clock)
    }

    override fun stop() {
        if (!isRunning) return
        isRunning = false
        synchronized(lock) { run += 1 }
        audio.removeClock(clock)
    }

    /** The next click comes one new beat after the last, keeping the place in the measure. */
    override fun setTempo(bpm: Int) {
        synchronized(lock) {
            val interval = 60.0 / maxOf(1, bpm)
            if (interval == secondsPerBeat) return
            secondsPerBeat = interval
            tempoChanged = true
        }
    }

    private fun report(index: Int, accent: Boolean, delayMs: Long) {
        val beatRun = run
        scheduler.schedule({
            SwingUtilities.invokeLater { if (run == beatRun && isRunning) onBeat?.invoke(index, accent) }
        }, delayMs, TimeUnit.MILLISECONDS)
    }

    private companion object {
        val scheduler = Executors.newSingleThreadScheduledExecutor { r -> Thread(r, "luksMusic-beat").apply { isDaemon = true } }
    }
}
