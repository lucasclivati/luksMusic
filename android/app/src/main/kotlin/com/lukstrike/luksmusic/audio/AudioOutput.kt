// AudioOutput.kt — the speaker end of AudioEngine: a float stereo AudioTrack on the low-latency path, fed by a
// dedicated urgent-priority thread in small blocks (the device's native burst), so a key press is heard within a few
// milliseconds. The buffer starts at two bursts and grows by one burst whenever the device reports an underrun
// (the latency tuning Oboe does). With nothing to play for a few seconds the track pauses and the thread sleeps
// until the next event, so the app costs no battery while silent.
package com.lukstrike.luksmusic.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Process
import android.util.Log
import com.lukstrike.luksmusic.audio.synth.PianoRenderer

internal class AudioOutput(context: Context, createRenderer: (sampleRate: Int) -> PianoRenderer) {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    /** The device's native rate and burst: matching them keeps the track on the fast mixer path. */
    val sampleRate: Int =
        audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull()?.takeIf { it > 0 } ?: 48_000
    private val burstFrames: Int =
        (audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.toIntOrNull()?.takeIf { it > 0 } ?: 192)
            .coerceAtMost(PianoRenderer.MAX_BLOCK_FRAMES)

    val renderer: PianoRenderer = createRenderer(sampleRate)

    /** Frames queued in the track ahead of what is heard, so beats can be shown when their click is heard. */
    @Volatile var latencyFrames: Int = burstFrames * 2
        private set

    private val lock = Object()
    @Volatile private var running = false
    @Volatile private var wakeRequested = false
    private var thread: Thread? = null

    fun start() {
        synchronized(lock) {
            if (running) return
            running = true
            thread = Thread(::run, "luksMusic-audio").apply { start() }
        }
    }

    fun stop() {
        val old: Thread?
        synchronized(lock) {
            if (!running) return
            running = false
            old = thread
            thread = null
            lock.notifyAll()
        }
        old?.join(500)
    }

    /** Wakes the render thread if it paused for silence (call after sending an event). */
    fun wake() {
        if (wakeRequested) return
        synchronized(lock) {
            wakeRequested = true
            lock.notifyAll()
        }
    }

    private fun run() {
        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        val buffer = FloatArray(burstFrames * 2)
        var track: AudioTrack? = null
        var lastUnderruns = 0
        var framesSinceCheck = 0
        try {
            while (running) {
                if (track == null) {
                    track = createTrack()
                    if (track == null) {
                        // No output now (the device is changing routes): try again soon
                        waitForWake(1_000)
                        continue
                    }
                    lastUnderruns = 0
                    track.play()
                }

                if (renderer.isIdle) {
                    track.pause()
                    track.flush()
                    waitForWake(0)
                    if (!running) break
                    track.play()
                }

                renderer.render(buffer, burstFrames)
                val written = track.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING)
                if (written < 0) {
                    // The output went away (a route change can kill the track): make a new one
                    Log.w(TAG, "AudioTrack write failed ($written), recreating the track")
                    track.release()
                    track = null
                    continue
                }

                framesSinceCheck += burstFrames
                if (framesSinceCheck >= sampleRate / 2) {
                    framesSinceCheck = 0
                    val underruns = track.underrunCount
                    if (underruns > lastUnderruns) {
                        lastUnderruns = underruns
                        val bigger = track.bufferSizeInFrames + burstFrames
                        if (bigger <= track.bufferCapacityInFrames) {
                            latencyFrames = track.setBufferSizeInFrames(bigger).coerceAtLeast(burstFrames)
                        }
                    }
                }
            }
        } catch (error: Throwable) {
            Log.e(TAG, "Audio thread stopped", error)
        } finally {
            track?.runCatching { stop(); release() }
        }
    }

    private fun waitForWake(timeoutMs: Long) {
        synchronized(lock) {
            if (!wakeRequested && running) {
                if (timeoutMs > 0) lock.wait(timeoutMs) else lock.wait()
            }
            wakeRequested = false
        }
    }

    private fun createTrack(): AudioTrack? = try {
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
            .build()
        val minimum = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_FLOAT)
        AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(format)
            .setBufferSizeInBytes(maxOf(minimum, burstFrames * 2 * 4 * 4))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build()
            .also { track ->
                // As small as the device allows: two bursts, grown on underruns
                latencyFrames = track.setBufferSizeInFrames(burstFrames * 2).coerceAtLeast(burstFrames)
            }
    } catch (error: Exception) {
        Log.e(TAG, "Couldn't create the AudioTrack", error)
        null
    }

    private companion object {
        const val TAG = "AudioOutput"
    }
}
