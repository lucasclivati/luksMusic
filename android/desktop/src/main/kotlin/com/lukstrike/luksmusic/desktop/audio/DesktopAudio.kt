// DesktopAudio.kt — the piano the desktop app plays: the shared synthesized piano (core/audio/synth, the same sound
// as the Android app) rendered on a dedicated thread into a javax.sound.sampled line (ALSA, PulseAudio or PipeWire
// on Linux). The line's buffer is kept small (about 20 ms) so a key sounds right away.
package com.lukstrike.luksmusic.desktop.audio

import com.lukstrike.luksmusic.core.audio.synth.AudioClock
import com.lukstrike.luksmusic.core.audio.synth.PianoRenderer
import com.lukstrike.luksmusic.core.audio.synth.SynthPiano
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import javax.sound.sampled.SourceDataLine
import kotlin.math.pow

/** What the screens use to make sound (a fake in the tests). */
interface NotePlayer {
    fun playNote(midi: Int, velocity: Int = 80, durationSeconds: Double? = null)
    fun stopNote(midi: Int)
    fun stopAllNotes()
    fun setSustain(down: Boolean)
}

class DesktopAudio(private val sampleRate: Int = 48_000) : NotePlayer {

    private val renderer = PianoRenderer(sampleRate, SynthPiano())
    @Volatile private var thread: Thread? = null
    @Volatile private var running = false

    /** Frames between a block being rendered and it being heard (the line's buffer). */
    @Volatile var latencyFrames: Int = 0
        private set

    /** Whether a sound device could be opened. */
    @Volatile var isAvailable: Boolean = true
        private set

    var volume: Float
        get() = renderer.volume
        set(value) { renderer.volume = value.coerceIn(0f, 1f) }

    init {
        renderer.reverbAmount = 0.2f
    }

    @Synchronized
    fun start() {
        if (running) return
        running = true
        thread = Thread(::renderLoop, "luksMusic-audio").apply {
            isDaemon = true
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    fun shutdown() {
        running = false
        thread?.join(500)
    }

    override fun playNote(midi: Int, velocity: Int, durationSeconds: Double?) {
        if (midi !in 0..127) return
        if (velocity <= 0) return stopNote(midi)
        start()
        renderer.noteOn(midi, 440.0 * 2.0.pow((midi - 69) / 12.0), velocity.coerceAtMost(127), durationSeconds?.takeIf { it > 0 })
    }

    override fun stopNote(midi: Int) = renderer.noteOff(midi)
    override fun stopAllNotes() = renderer.allNotesOff()
    override fun setSustain(down: Boolean) = renderer.sustain(down)

    fun addClock(clock: AudioClock) {
        start()
        renderer.addClock(clock)
    }

    fun removeClock(clock: AudioClock) = renderer.removeClock(clock)

    private fun renderLoop() {
        val format = AudioFormat(sampleRate.toFloat(), 16, 2, true, false)
        val line: SourceDataLine = try {
            (AudioSystem.getSourceDataLine(format)).apply {
                // About 20 ms: small enough to feel immediate, large enough not to crackle on the Deck
                open(format, BUFFER_FRAMES * BYTES_PER_FRAME)
                start()
            }
        } catch (e: Exception) {
            System.err.println("luksMusic: no audio output (${e.message})")
            isAvailable = false
            running = false
            return
        }
        latencyFrames = line.bufferSize / BYTES_PER_FRAME
        val block = PianoRenderer.MAX_BLOCK_FRAMES
        val floats = FloatArray(block * 2)
        val bytes = ByteArray(block * BYTES_PER_FRAME)
        try {
            while (running) {
                renderer.render(floats, block)
                Pcm.toPcm16(floats, block * 2, bytes)
                // Blocks while the line's buffer is full: the line's clock paces the renderer
                line.write(bytes, 0, bytes.size)
            }
        } finally {
            line.drain()
            line.close()
        }
    }

    private companion object {
        const val BUFFER_FRAMES = 1024
        const val BYTES_PER_FRAME = 4
    }
}

object Pcm {
    /** Converts [count] float samples (-1..1, clipped) into signed 16-bit little-endian PCM in [out]. */
    fun toPcm16(samples: FloatArray, count: Int, out: ByteArray) {
        for (i in 0 until count) {
            val value = (samples[i].coerceIn(-1f, 1f) * 32767f).toInt()
            out[2 * i] = (value and 0xFF).toByte()
            out[2 * i + 1] = ((value shr 8) and 0xFF).toByte()
        }
    }
}
