// PianoRenderer.kt — the mixer that runs on the audio thread: it takes the note events the app sends (any thread),
// keeps up to 32 piano voices (stealing the quietest when a 33rd key comes), handles the dampers and the sustain
// pedal, plays the metronome click at an exact sample, and sends the sum through the reverb, the master volume and
// the limiter. Nothing here allocates or blocks for long once the audio runs.
package com.lukstrike.luksmusic.core.audio.synth

import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

/** Something that keeps time on the audio thread (the metronome): it may schedule clicks inside each block. */
interface AudioClock {
    /** Called on the audio thread before rendering the [frames] that start at absolute frame [blockStart]. */
    fun onBlock(blockStart: Long, frames: Int, sampleRate: Int, clicks: ClickScheduler)
}

fun interface ClickScheduler {
    /** Starts a click [offset] frames into the current block. */
    fun click(offset: Int, accent: Boolean)
}

class PianoRenderer(val sampleRate: Int, sound: PianoSound) {

    private val voices = Array(MAX_VOICES + FADE_SLOTS) { sound.createVoice(sampleRate) }
    private val slotMidi = IntArray(voices.size)
    private val slotKeyDown = BooleanArray(voices.size)
    private val slotHeld = BooleanArray(voices.size)
    private val slotFading = BooleanArray(voices.size)
    private val slotReleaseAt = LongArray(voices.size) { -1 }
    private var sustain = false

    private val left = FloatArray(MAX_BLOCK_FRAMES)
    private val right = FloatArray(MAX_BLOCK_FRAMES)
    private val reverb = Reverb(sampleRate)
    private val limiter = Limiter(sampleRate)

    /** Master volume and reverb amount, set from any thread. */
    @Volatile var volume = 0.8f
    @Volatile var reverbAmount = 0.25f

    /** Frames rendered so far: the audio clock the metronome counts in. */
    @Volatile var framePosition = 0L
        private set
    private var lastSoundFrame = 0L

    // Metronome clicks: a tone that dies away in about 40 ms, like the web player's click (iOS clickBuffer)
    private val accentClick = clickSound(1000.0, 0.6f)
    private val beatClick = clickSound(750.0, 0.45f)
    private var click: FloatArray? = null
    private var clickPosition = 0
    private var pendingClick: FloatArray? = null
    private var pendingClickOffset = -1
    private val clickScheduler = ClickScheduler { offset, accent ->
        pendingClick = if (accent) accentClick else beatClick
        pendingClickOffset = offset
    }

    @Volatile private var clocks: Array<AudioClock> = emptyArray()
    private val events = EventQueue()
    private val drained = EventQueue.Batch()

    // Called from any thread

    fun noteOn(midi: Int, frequency: Double, velocity: Int, durationSeconds: Double?) =
        events.push(NOTE_ON, midi, velocity, frequency, durationSeconds?.let { (it * sampleRate).toLong() } ?: -1)

    fun noteOff(midi: Int) = events.push(NOTE_OFF, midi)
    fun allNotesOff() = events.push(ALL_OFF)
    fun sustain(down: Boolean) = events.push(SUSTAIN, if (down) 1 else 0)
    fun click(accent: Boolean) = events.push(CLICK, if (accent) 1 else 0)

    @Synchronized fun addClock(clock: AudioClock) {
        if (clock !in clocks) clocks = clocks + clock
    }

    @Synchronized fun removeClock(clock: AudioClock) {
        clocks = clocks.filter { it !== clock }.toTypedArray()
    }

    /** Nothing sounds, nothing is waiting and no clock runs: the output can pause until the next event. */
    val isIdle: Boolean
        get() = clocks.isEmpty() && events.isEmpty && framePosition - lastSoundFrame > sampleRate * IDLE_SECONDS

    // Audio thread

    /** Renders [frames] (≤ [MAX_BLOCK_FRAMES]) interleaved stereo frames into [output]. */
    fun render(output: FloatArray, frames: Int) {
        val blockStart = framePosition
        handleEvents()
        handleTimedReleases(blockStart)
        for (clock in clocks) clock.onBlock(blockStart, frames, sampleRate, clickScheduler)

        java.util.Arrays.fill(left, 0, frames, 0f)
        java.util.Arrays.fill(right, 0, frames, 0f)
        var sounding = false
        for (index in voices.indices) {
            val voice = voices[index]
            if (!voice.isActive) continue
            voice.render(left, right, frames)
            sounding = true
        }
        reverb.amount = reverbAmount
        reverb.process(left, right, left, right, frames)

        val gain = volume.coerceIn(0f, 1f)
        for (f in 0 until frames) {
            if (f == pendingClickOffset) {
                // A new click cuts the one still sounding (iOS schedules it with .interrupts)
                click = pendingClick
                clickPosition = 0
                pendingClick = null
                pendingClickOffset = -1
            }
            var clickSample = 0f
            val current = click
            if (current != null) {
                clickSample = current[clickPosition++]
                if (clickPosition == current.size) click = null
                sounding = true
            }
            left[f] = (left[f] + clickSample) * gain
            right[f] = (right[f] + clickSample) * gain
        }
        // A click scheduled past this block's end (never by the metronome) starts with the next block
        if (pendingClickOffset >= frames) pendingClickOffset = 0
        limiter.process(left, right, frames)

        for (f in 0 until frames) {
            output[2 * f] = left[f]
            output[2 * f + 1] = right[f]
        }
        if (sounding) lastSoundFrame = blockStart + frames
        framePosition = blockStart + frames
    }

    private fun handleEvents() {
        events.drainTo(drained)
        for (index in 0 until drained.count) {
            when (drained.type[index]) {
                NOTE_ON -> startNote(drained.a[index], drained.frequency[index], drained.b[index], drained.duration[index])
                NOTE_OFF -> releaseKey(drained.a[index])
                ALL_OFF -> for (slot in voices.indices) {
                    slotKeyDown[slot] = false
                    slotHeld[slot] = false
                    slotReleaseAt[slot] = -1
                    if (voices[slot].isActive) voices[slot].release()
                }
                SUSTAIN -> setSustain(drained.a[index] == 1)
                CLICK -> clickScheduler.click(0, drained.a[index] == 1)
            }
        }
    }

    private fun startNote(midi: Int, frequency: Double, velocity: Int, durationFrames: Long) {
        // A key struck again hits the same strings: the sound still ringing gives way to the new blow
        var busy = 0
        for (slot in voices.indices) {
            if (!voices[slot].isActive || slotFading[slot]) continue
            if (slotMidi[slot] == midi) fade(slot) else busy += 1
        }
        if (busy >= MAX_VOICES) stealVoice()

        var free = -1
        for (slot in voices.indices) if (!voices[slot].isActive) { free = slot; break }
        if (free < 0) {
            // Every slot is busy, fading included: reuse the quietest one at once
            free = 0
            for (slot in voices.indices) if (voices[slot].loudness < voices[free].loudness) free = slot
        }
        slotMidi[free] = midi
        slotKeyDown[free] = true
        slotHeld[free] = false
        slotFading[free] = false
        slotReleaseAt[free] = if (durationFrames > 0) framePosition + durationFrames else -1
        // The keyboard spread across the stereo field, as heard from the bench: bass to the left
        val pan = ((midi - 64) / 64f * 0.35f).coerceIn(-0.6f, 0.6f)
        voices[free].start(midi, frequency, velocity, pan)
    }

    /** Fades out the quietest voice, preferring one whose key is already up. */
    private fun stealVoice() {
        var victim = -1
        var victimReleased = false
        for (slot in voices.indices) {
            if (!voices[slot].isActive || slotFading[slot]) continue
            val released = !slotKeyDown[slot]
            val better = victim < 0 || (released && !victimReleased) ||
                (released == victimReleased && voices[slot].loudness < voices[victim].loudness)
            if (better) {
                victim = slot
                victimReleased = released
            }
        }
        if (victim >= 0) fade(victim)
    }

    private fun fade(slot: Int) {
        slotFading[slot] = true
        slotKeyDown[slot] = false
        slotHeld[slot] = false
        voices[slot].fadeOut()
    }

    private fun releaseKey(midi: Int) {
        for (slot in voices.indices) {
            if (slotMidi[slot] != midi || !slotKeyDown[slot] || slotFading[slot] || !voices[slot].isActive) continue
            releaseSlot(slot)
        }
    }

    private fun releaseSlot(slot: Int) {
        slotKeyDown[slot] = false
        slotReleaseAt[slot] = -1
        if (sustain) slotHeld[slot] = true else voices[slot].release()
    }

    private fun handleTimedReleases(now: Long) {
        for (slot in voices.indices) {
            val at = slotReleaseAt[slot]
            if (at in 0..now && slotKeyDown[slot] && voices[slot].isActive) releaseSlot(slot)
        }
    }

    private fun setSustain(down: Boolean) {
        sustain = down
        if (down) return
        for (slot in voices.indices) {
            if (!slotHeld[slot]) continue
            slotHeld[slot] = false
            if (voices[slot].isActive && !slotFading[slot]) voices[slot].release()
        }
    }

    private fun clickSound(frequency: Double, amplitude: Float): FloatArray {
        val frames = (sampleRate * 0.05).toInt()
        return FloatArray(frames) { frame ->
            val time = frame.toDouble() / sampleRate
            (sin(2 * PI * frequency * time) * exp(-time * 120)).toFloat() * amplitude
        }
    }

    companion object {
        const val MAX_BLOCK_FRAMES = 256
        /** Voices heard at once; a 33rd key fades out the quietest. */
        const val MAX_VOICES = 32
        /** Extra slots where stolen voices finish their few milliseconds of fade. */
        private const val FADE_SLOTS = 8
        /** How long after the last sound (the reverb's tail) the output may pause. */
        private const val IDLE_SECONDS = 3

        private const val NOTE_ON = 1
        private const val NOTE_OFF = 2
        private const val ALL_OFF = 3
        private const val SUSTAIN = 4
        private const val CLICK = 5
    }
}

/** Events from the app's threads to the audio thread: a small ring the audio thread empties at each block. */
private class EventQueue {
    class Batch {
        val type = IntArray(CAPACITY)
        val a = IntArray(CAPACITY)
        val b = IntArray(CAPACITY)
        val frequency = DoubleArray(CAPACITY)
        val duration = LongArray(CAPACITY)
        var count = 0
    }

    private val pending = Batch()

    val isEmpty: Boolean get() = synchronized(this) { pending.count == 0 }

    @Synchronized
    fun push(type: Int, a: Int = 0, b: Int = 0, frequency: Double = 0.0, duration: Long = -1) {
        // A burst larger than the ring (thousands of events in 5 ms) drops the newest rather than blocking the caller
        val index = pending.count
        if (index == CAPACITY) return
        pending.type[index] = type
        pending.a[index] = a
        pending.b[index] = b
        pending.frequency[index] = frequency
        pending.duration[index] = duration
        pending.count = index + 1
    }

    /** Moves every waiting event into [batch]; the lock is held only for the copy. */
    @Synchronized
    fun drainTo(batch: Batch) {
        val count = pending.count
        System.arraycopy(pending.type, 0, batch.type, 0, count)
        System.arraycopy(pending.a, 0, batch.a, 0, count)
        System.arraycopy(pending.b, 0, batch.b, 0, count)
        System.arraycopy(pending.frequency, 0, batch.frequency, 0, count)
        System.arraycopy(pending.duration, 0, batch.duration, 0, count)
        batch.count = count
        pending.count = 0
    }

    private companion object {
        const val CAPACITY = 1024
    }
}
