// MicrophonePitchService.kt — listens to the instrument through the microphone (port of
// Services/Audio/MicrophonePitchService.swift). Practice and lessons get the keys struck; the tuner gets a steady
// pitch. One instance for the whole app, from AppContainer.microphone.
//
// The audio is read on its own thread with AudioRecord (48 kHz mono float; the UNPROCESSED source when the device
// has one, else VOICE_RECOGNITION, both free of the automatic gain and noise suppression that would flatten a piano's
// attack). The analysis itself is in :core (core/pitch), where it is unit tested.
//
// PUBLIC API — other features use these members; keep their signatures stable.
package com.lukstrike.luksmusic.audio

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.pitch.MicrophoneNoteReader
import com.lukstrike.luksmusic.core.pitch.TunerPitchTracker
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.math.log10

class MicrophonePitchService(private val context: Context) {

    private val _isListening = MutableStateFlow(false)
    val isListening: StateFlow<Boolean> = _isListening

    /** Input level 0..1 for meters. */
    private val _inputLevel = MutableStateFlow(0f)
    val inputLevel: StateFlow<Float> = _inputLevel

    /** The tuner's steady pitch in Hz (null when silent). Only while [setTuner] has settings. */
    private val _tunerFrequency = MutableStateFlow<Double?>(null)
    val tunerFrequency: StateFlow<Double?> = _tunerFrequency

    /** The last note understood (MIDI), which the practice screens show as heard; null when not listening. */
    private val _detectedMidiNote = MutableStateFlow<Int?>(null)
    val detectedMidiNote: StateFlow<Int?> = _detectedMidiNote

    /** Each key struck (MIDI note), for practice and lessons. */
    private val _notes = MutableSharedFlow<Int>(extraBufferCapacity = 64)
    val notesDetected: SharedFlow<Int> = _notes

    /** A chord was expected and the sound did not match it. */
    private val _chordMissed = MutableSharedFlow<Unit>(extraBufferCapacity = 8)
    val chordMissed: SharedFlow<Unit> = _chordMissed

    private val _error = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _error

    // Read by the audio thread, written by the app's: guarded by `lock` (iOS deafLock)
    private val lock = Any()
    /** Time (elapsedRealtime ms) until which the microphone is deaf, while the app itself is making sound. */
    private var deafUntil = 0L
    private var expectedNotes: Set<Int>? = null
    /** What the tuner listens for; null reads struck notes for the practice screens. */
    private var tunerSettings: TunerPitchTracker.Settings? = null

    // Main thread: whether a session runs, and its reading thread (kept after a stop, so the next session can wait
    // for it to close the microphone). `session` changes on every start and stop, so an old thread never publishes.
    private var active = false
    private var thread: Thread? = null
    @Volatile private var session = 0
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Whether RECORD_AUDIO is granted (the screen asks for it with the Activity's permission launcher). */
    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    /** Starts the microphone. Requires the permission. The device is opened on the reading thread, never the caller's. */
    fun startListening() {
        if (active) return
        if (!hasPermission()) {
            _error.value = context.getString(R.string.audio_mic_permission_needed)
            _isListening.value = false
            return
        }
        active = true
        val mySession = synchronized(lock) { ++session }
        val previous = thread
        thread = Thread({ readLoop(mySession, previous) }, "luksMusic-microphone").apply { start() }
    }

    fun stopListening() {
        if (!active) return
        active = false
        synchronized(lock) {
            session += 1 // the reading thread sees it and closes the microphone
            _isListening.value = false
        }
        _detectedMidiNote.value = null
        _inputLevel.value = 0f
        _tunerFrequency.value = null
    }

    /** Ignores the input for a while (e.g. while the app itself plays a note), so its sound through the speaker
     *  isn't taken for the piano. */
    fun ignoreInput(seconds: Double) {
        synchronized(lock) {
            deafUntil = maxOf(deafUntil, SystemClock.elapsedRealtime() + (seconds * 1000).toLong())
        }
    }

    /** The notes expected next (helps tell a chord); null = anything. One note is listened for closely (a different
     *  note is still reported), several must sound together. */
    fun expect(notes: Set<Int>?) {
        synchronized(lock) { expectedNotes = notes }
    }

    /** Tuner mode with the range listened for, in Hz; null leaves tuner mode (back to reading struck notes). */
    fun setTuner(lowestHz: Double?, highestHz: Double?) {
        val settings = if (lowestHz != null && highestHz != null) TunerPitchTracker.Settings(lowestHz, highestHz) else null
        synchronized(lock) { tunerSettings = settings }
        if (settings == null) _tunerFrequency.value = null
    }

    // Reading thread

    @SuppressLint("MissingPermission") // checked in startListening
    private fun readLoop(mySession: Int, previous: Thread?) {
        Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
        // A quick stop and start: let the last session close the microphone first
        previous?.join(1_000)
        val input = openInput()
        if (input == null) {
            failed(mySession)
            return
        }
        val record = input.record
        try {
            record.startRecording()
            if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) throw IllegalStateException("not recording")
            val current = synchronized(lock) {
                (session == mySession).also { if (it) _isListening.value = true }
            }
            if (!current) return
            _error.value = null
            Log.i(TAG, "Microphone started: ${input.sampleRate} Hz, source ${input.source}, float ${input.isFloat}")

            val sampleRate = input.sampleRate.toDouble()
            val reader = MicrophoneNoteReader(sampleRate)
            var tracker: TunerPitchTracker? = null
            val samples = FloatArray(BUFFER_FRAMES)
            val shorts = if (input.isFloat) null else ShortArray(BUFFER_FRAMES)

            while (session == mySession) {
                val count = if (shorts == null) {
                    record.read(samples, 0, BUFFER_FRAMES, AudioRecord.READ_BLOCKING)
                } else {
                    record.read(shorts, 0, BUFFER_FRAMES, AudioRecord.READ_BLOCKING).also { read ->
                        for (index in 0 until read) samples[index] = shorts[index] / 32768f
                    }
                }
                if (count < 0) throw IllegalStateException("AudioRecord.read returned $count")
                if (count == 0 || session != mySession) continue

                val isDeaf: Boolean
                val expected: Set<Int>?
                val tuner: TunerPitchTracker.Settings?
                synchronized(lock) {
                    isDeaf = SystemClock.elapsedRealtime() < deafUntil
                    expected = expectedNotes
                    tuner = tunerSettings
                }
                if (isDeaf) {
                    reader.reset()
                    tracker?.reset()
                    continue
                }
                if (tuner != null) {
                    // The tuner's reading of one hop: the pitch while a note rings, null in silence
                    val current = tracker?.takeIf { it.settings == tuner }
                        ?: TunerPitchTracker(sampleRate, tuner).also { tracker = it }
                    val frequency = current.process(samples, 0, count)
                    if (session != mySession) break
                    _inputLevel.value = meterLevel(current.level)
                    _tunerFrequency.value = frequency
                    continue
                }
                tracker = null

                reader.expectedNotes = expected
                val missedBefore = reader.missedChords
                val notes = reader.read(samples, 0, count)
                val missedChord = reader.missedChords > missedBefore
                if (session != mySession) break
                _inputLevel.value = meterLevel(reader.level)
                // The last note understood, which the screen shows as heard
                notes.lastOrNull()?.let { _detectedMidiNote.value = it }
                for (note in notes) _notes.tryEmit(note)
                if (missedChord) _chordMissed.tryEmit(Unit)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Microphone stopped", error)
            failed(mySession)
        } finally {
            runCatching { record.stop() }
            record.release()
        }
    }

    private fun failed(mySession: Int) {
        synchronized(lock) {
            if (session != mySession) return
            _isListening.value = false
        }
        _error.value = context.getString(R.string.audio_mic_start_failed)
        // So the next startListening tries again
        mainHandler.post { if (session == mySession) active = false }
    }

    /** In decibels, so a piano across the room still moves the meter (-60 dB is empty, -10 dB is full). */
    private fun meterLevel(rms: Float): Float =
        ((20 * log10(maxOf(rms, 0.000_001f)) + 60) / 50).coerceIn(0f, 1f)

    private class Input(val record: AudioRecord, val sampleRate: Int, val source: Int, val isFloat: Boolean)

    /** 48 kHz mono, float when the device allows it, else 16-bit. */
    @SuppressLint("MissingPermission")
    private fun openInput(): Input? {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val source = if (audioManager.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true") {
            MediaRecorder.AudioSource.UNPROCESSED
        } else {
            MediaRecorder.AudioSource.VOICE_RECOGNITION
        }
        for (encoding in intArrayOf(AudioFormat.ENCODING_PCM_FLOAT, AudioFormat.ENCODING_PCM_16BIT)) {
            for (rate in intArrayOf(SAMPLE_RATE, 44_100)) {
                val minimum = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, encoding)
                if (minimum <= 0) continue
                val bytesPerSample = if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
                // A quarter second of room, so a slow analysis (a strike's 16k FFT) never loses audio
                val size = maxOf(minimum, rate / 4 * bytesPerSample, BUFFER_FRAMES * 4 * bytesPerSample)
                val record = try {
                    AudioRecord.Builder()
                        .setAudioSource(source)
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setEncoding(encoding)
                                .setSampleRate(rate)
                                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                                .build()
                        )
                        .setBufferSizeInBytes(size)
                        .build()
                } catch (error: Exception) {
                    Log.w(TAG, "AudioRecord $rate Hz encoding $encoding failed", error)
                    continue
                }
                if (record.state == AudioRecord.STATE_INITIALIZED) {
                    return Input(record, record.sampleRate, source, encoding == AudioFormat.ENCODING_PCM_FLOAT)
                }
                record.release()
            }
        }
        return null
    }

    private companion object {
        const val TAG = "MicrophonePitch"
        const val SAMPLE_RATE = 48_000
        /** Frames read at once, as iOS's tap (2048). */
        const val BUFFER_FRAMES = 2048
    }
}
