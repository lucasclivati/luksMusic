// AudioEngine.kt — the piano sound, the metronome click and the tuner's reference tone (port of
// Services/Audio/AudioEngineService.swift). One instance for the whole app, from AppContainer.audio.
//
// iOS plays Apple's sampler piano through AVAudioEngine; here a synthesized piano (synth/SynthPiano) is mixed on a
// low-latency AudioTrack (AudioOutput). Every method is cheap and callable from any thread: it only queues an event
// for the audio thread.
//
// PUBLIC API — other features call these methods; keep their signatures stable.
package com.lukstrike.luksmusic.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.lukstrike.luksmusic.core.audio.synth.AudioClock
import com.lukstrike.luksmusic.core.audio.synth.PianoRenderer
import com.lukstrike.luksmusic.core.audio.synth.SynthPiano
import kotlin.math.pow

class AudioEngine(private val context: Context) {

    /** Master volume, 0..1. */
    var volume: Float = 0.8f
        set(value) {
            field = value.coerceIn(0f, 1f)
            output?.renderer?.volume = field
        }

    /** Reverb amount, 0..1 (the score player's "concert hall" setting sets 0.25 or 0). */
    var reverb: Float = 0.25f
        set(value) {
            field = value.coerceIn(0f, 1f)
            output?.renderer?.reverbAmount = field
        }

    /** Whether the app's sound goes to headphones, out of the microphone's hearing. Callable from any thread. */
    @Volatile var hasHeadphones: Boolean = false
        private set

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var output: AudioOutput? = null
    private var receiversRegistered = false

    /** Starts the audio output. Safe to call more than once. */
    fun start() {
        val current = output ?: synchronized(this) {
            output ?: AudioOutput(context) { rate -> PianoRenderer(rate, SynthPiano()) }.also { created ->
                created.renderer.volume = volume
                created.renderer.reverbAmount = reverb
                output = created
            }
        }
        current.start()
        registerReceivers()
    }

    /** Stops the audio output and releases it (app going to background for good). */
    fun release() {
        val current = synchronized(this) { output.also { output = null } }
        current?.stop()
        unregisterReceivers()
    }

    /** Strikes [midiNote] (0–127). With [durationSeconds], releases it on its own after that time. */
    fun playNote(midiNote: Int, velocity: Int = 80, durationSeconds: Double? = null) {
        strike(midiNote, frequency(midiNote, 440.0), velocity, durationSeconds)
    }

    /** Releases [midiNote] (the sound fades out like a piano damper). */
    fun stopNote(midiNote: Int) {
        send { it.noteOff(midiNote) }
    }

    fun stopAllNotes() {
        send { it.allNotesOff() }
    }

    /** Sustain pedal: while down, released notes keep ringing. */
    fun setSustain(down: Boolean) {
        send { it.sustain(down) }
    }

    /**
     * The tuner's reference: [midiNote] tuned to [a4] Hz instead of 440. Each voice has its own pitch here, so unlike
     * iOS (which retunes the whole sampler for a while) nothing else playing changes pitch.
     */
    fun playReferenceTone(midiNote: Int, a4: Double, durationSeconds: Double) {
        strike(midiNote, frequency(midiNote, a4), velocity = 90, durationSeconds = durationSeconds)
    }

    /** Metronome click (higher and louder on the first beat). */
    fun playClick(accent: Boolean) {
        send { it.click(accent) }
    }

    // Internal: the metronome keeps time on the audio thread

    internal val sampleRate: Int get() = output?.sampleRate ?: 48_000

    /** Frames between a block being rendered and it being heard. */
    internal val outputLatencyFrames: Int get() = output?.latencyFrames ?: 0

    internal fun addClock(clock: AudioClock) {
        start()
        output?.let {
            it.renderer.addClock(clock)
            it.wake()
        }
    }

    internal fun removeClock(clock: AudioClock) {
        output?.renderer?.removeClock(clock)
    }

    // Private

    private fun strike(midiNote: Int, frequency: Double, velocity: Int, durationSeconds: Double?) {
        if (midiNote !in 0..127 || velocity <= 0) {
            if (velocity <= 0) stopNote(midiNote) // MIDI's note-on with velocity 0 is a release
            return
        }
        send { it.noteOn(midiNote, frequency, velocity.coerceAtMost(127), durationSeconds?.takeIf { d -> d > 0 }) }
    }

    private inline fun send(event: (PianoRenderer) -> Unit) {
        // Started on demand too, so a note played before the app's own start() still sounds
        if (output == null) start()
        val current = output ?: return
        event(current.renderer)
        current.wake()
    }

    private fun frequency(midi: Int, a4: Double) = a4 * 2.0.pow((midi - 69) / 12.0)

    // Route: headphones unplugged stop the notes (as iOS does), and the metronome asks whether headphones are on

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) stopAllNotes()
        }
    }

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) = updateHeadphones()
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) = updateHeadphones()
    }

    private fun updateHeadphones() {
        val headphoneTypes = buildSet {
            add(AudioDeviceInfo.TYPE_WIRED_HEADPHONES)
            add(AudioDeviceInfo.TYPE_WIRED_HEADSET)
            add(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)
            add(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)
            add(AudioDeviceInfo.TYPE_USB_HEADSET)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add(AudioDeviceInfo.TYPE_BLE_HEADSET)
        }
        hasHeadphones = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in headphoneTypes }
    }

    private fun registerReceivers() {
        synchronized(this) {
            if (receiversRegistered) return
            receiversRegistered = true
        }
        ContextCompat.registerReceiver(
            context, noisyReceiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        audioManager.registerAudioDeviceCallback(deviceCallback, mainHandler)
        updateHeadphones()
    }

    private fun unregisterReceivers() {
        synchronized(this) {
            if (!receiversRegistered) return
            receiversRegistered = false
        }
        runCatching { context.unregisterReceiver(noisyReceiver) }
        audioManager.unregisterAudioDeviceCallback(deviceCallback)
    }
}
