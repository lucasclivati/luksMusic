// PianoRendererTest.kt — the synthesized piano and its mixer, rendered offline: chords never clip, the damper and the
// pedal end notes, voices are stolen past 32 keys, the metronome clock clicks on its exact sample, and 32 voices
// render far faster than real time.
package com.lukstrike.luksmusic.core.audio.synth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.pow

class PianoRendererTest {

    private val sampleRate = 48_000
    private val block = 192

    private fun renderer() = PianoRenderer(sampleRate, SynthPiano())

    private fun frequency(midi: Int) = 440.0 * 2.0.pow((midi - 69) / 12.0)

    /** Renders [seconds] and returns the loudest sample. */
    private fun PianoRenderer.peak(seconds: Double): Float {
        val output = FloatArray(block * 2)
        var peak = 0f
        repeat((seconds * sampleRate / block).toInt()) {
            render(output, block)
            for (sample in output) peak = maxOf(peak, abs(sample))
        }
        return peak
    }

    @Test
    fun aLoudChordWithThePedalNeverClips() {
        val piano = renderer()
        piano.volume = 1f
        piano.sustain(true)
        for (midi in listOf(36, 43, 48, 52, 55, 60, 64, 67, 72, 76)) piano.noteOn(midi, frequency(midi), 127, null)
        val peak = piano.peak(1.0)
        assertTrue("peak $peak", peak < 1f)
        assertTrue("peak $peak", peak > 0.2f)
    }

    @Test
    fun aSingleNoteSoundsAndTheDamperEndsIt() {
        val piano = renderer()
        piano.noteOn(60, frequency(60), 80, null)
        assertTrue(piano.peak(0.3) > 0.02f)
        piano.noteOff(60)
        piano.peak(1.0)
        assertTrue("silent a second after the key is up", piano.peak(0.1) < 0.002f)
        // The reverb tail, then idle
        piano.peak(3.5)
        assertTrue(piano.isIdle)
    }

    @Test
    fun thePedalKeepsReleasedNotesRinging() {
        val piano = renderer()
        piano.sustain(true)
        piano.noteOn(60, frequency(60), 80, null)
        piano.peak(0.2)
        piano.noteOff(60)
        piano.peak(1.0)
        assertTrue("still ringing with the pedal down", piano.peak(0.1) > 0.01f)
        piano.sustain(false)
        piano.peak(1.0)
        assertTrue("damped when the pedal comes up", piano.peak(0.1) < 0.002f)
    }

    @Test
    fun aTimedNoteReleasesItself() {
        val piano = renderer()
        piano.noteOn(64, frequency(64), 90, 0.5)
        assertTrue(piano.peak(0.4) > 0.02f)
        piano.peak(1.2)
        assertTrue(piano.peak(0.1) < 0.002f)
    }

    @Test
    fun softerIsQuieterAndHarderIsLouder() {
        val soft = renderer().apply { noteOn(60, frequency(60), 30, null) }.peak(0.3)
        val loud = renderer().apply { noteOn(60, frequency(60), 120, null) }.peak(0.3)
        assertTrue("soft $soft, loud $loud", loud > soft * 3)
    }

    @Test
    fun moreThan32KeysStealVoicesWithoutTrouble() {
        val piano = renderer()
        piano.sustain(true)
        for (midi in 30..90) piano.noteOn(midi, frequency(midi), 100, null)
        val peak = piano.peak(0.5)
        assertTrue(peak < 1f)
    }

    @Test
    fun theClockClicksOnItsExactSample() {
        val piano = renderer()
        val target = 1_000L
        piano.addClock(object : AudioClock {
            var done = false
            override fun onBlock(blockStart: Long, frames: Int, sampleRate: Int, clicks: ClickScheduler) {
                if (!done && target < blockStart + frames) {
                    clicks.click((target - blockStart).toInt(), accent = true)
                    done = true
                }
            }
        })
        val output = FloatArray(block * 2)
        var first = -1L
        var frame = 0L
        repeat(20) {
            piano.render(output, block)
            for (f in 0 until block) if (first < 0 && abs(output[2 * f]) > 1e-6f) first = frame + f
            frame += block
        }
        // The click is a sine starting at zero: its first non-zero sample is the one after its start
        assertEquals(target + 1, first)
    }

    @Test
    fun thirtyTwoVoicesRenderFasterThanRealTime() {
        val piano = renderer()
        piano.sustain(true)
        for (midi in 40 until 72) piano.noteOn(midi, frequency(midi), 100, null)
        piano.peak(0.5) // warm up the JIT
        val start = System.nanoTime()
        piano.peak(2.0)
        val seconds = (System.nanoTime() - start) / 1e9
        println("32 voices: 2 s of audio rendered in ${"%.3f".format(seconds)} s")
        assertTrue("took $seconds s", seconds < 2.0)
    }
}
