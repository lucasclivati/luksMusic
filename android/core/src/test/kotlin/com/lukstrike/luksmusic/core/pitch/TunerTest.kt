// TunerTest.kt — port of iOS luksMusicTests/TunerTests.swift: frequency to note and cents at different reference A's,
// the guitar's strings, and the pitch tracker against synthetic tones (pure sines, plucked strings with harmonics,
// piano bass with a weak fundamental, room noise), fed in hops as the microphone delivers them.
package com.lukstrike.luksmusic.core.pitch

import com.lukstrike.luksmusic.core.model.TunerMode
import com.lukstrike.luksmusic.core.model.Tuning
import com.lukstrike.luksmusic.core.model.TuningReading
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

class TunerTest {

    private val sampleRate = 48_000.0

    // Frequency to note

    @Test
    fun frequencyOfNotes() {
        assertEquals(440.0, Tuning.frequency(69), 1e-9)
        assertEquals(220.0, Tuning.frequency(57), 1e-9)
        assertEquals(27.5, Tuning.frequency(21), 1e-9)
        assertEquals(4186.009, Tuning.frequency(108), 0.001)
        assertEquals(82.407, Tuning.frequency(40), 0.001)
        assertEquals(432.0, Tuning.frequency(69, a4 = 432.0), 1e-9)
        assertEquals(830.0, Tuning.frequency(81, a4 = 415.0), 1e-9)
    }

    @Test
    fun cents() {
        assertEquals(1200.0, Tuning.cents(440.0, 880.0), 1e-9)
        assertEquals(100.0, Tuning.cents(440.0, Tuning.frequency(70)), 1e-9)
        assertEquals(19.56, Tuning.cents(440.0, 445.0), 0.01)
        assertEquals(-19.79, Tuning.cents(440.0, 435.0), 0.01)
    }

    @Test
    fun nearestNote() {
        val a4 = Tuning.nearestNote(440.0)!!
        assertEquals(69, a4.midi)
        assertEquals(0.0, a4.cents, 1e-9)
        assertTrue(a4.isInTune)

        val sharp = Tuning.nearestNote(445.0)!!
        assertEquals(69, sharp.midi)
        assertEquals(19.56, sharp.cents, 0.01)
        assertTrue(sharp.isSharp)
        assertEquals(440.0, sharp.targetFrequency, 1e-9)

        // Just under halfway to A♯4 is still A4, just over is A♯4
        assertEquals(69, Tuning.nearestNote(440 * 2.0.pow(49.0 / 1200))?.midi)
        assertEquals(70, Tuning.nearestNote(440 * 2.0.pow(51.0 / 1200))?.midi)
        assertEquals(-49.0, Tuning.nearestNote(440 * 2.0.pow(51.0 / 1200))?.cents ?: 0.0, 1e-6)

        // The piano's ends, and nothing beyond them
        assertEquals(21, Tuning.nearestNote(27.5)?.midi)
        assertEquals(108, Tuning.nearestNote(4186.01)?.midi)
        assertEquals(40, Tuning.nearestNote(82.41)?.midi)
        assertNull(Tuning.nearestNote(20.0))
        assertNull(Tuning.nearestNote(5000.0))
        assertNull(Tuning.nearestNote(0.0))
        assertNull(Tuning.nearestNote(-10.0))
        assertNull(Tuning.nearestNote(Double.NaN))
    }

    @Test
    fun referenceA() {
        // At A4 = 415 (baroque), 415 Hz is an A in tune and 440 Hz is about a semitone up
        val baroque = Tuning.nearestNote(415.0, a4 = 415.0)!!
        assertEquals(69, baroque.midi)
        assertEquals(0.0, baroque.cents, 1e-9)
        val modern = Tuning.nearestNote(440.0, a4 = 415.0)!!
        assertEquals(70, modern.midi)
        assertEquals(1.27, modern.cents, 0.01)
        // At A4 = 442, a 440 Hz A is 8 cents flat
        val orchestra = Tuning.nearestNote(440.0, a4 = 442.0)!!
        assertEquals(69, orchestra.midi)
        assertEquals(-7.85, orchestra.cents, 0.01)
        assertTrue(orchestra.isFlat)

        assertEquals(466.0, Tuning.clampedA4(500.0), 0.0)
        assertEquals(415.0, Tuning.clampedA4(400.0), 0.0)
        assertEquals(441.0, Tuning.clampedA4(441.4), 0.0)
    }

    @Test
    fun inTuneBand() {
        fun reading(cents: Double) = TuningReading(69, cents, 440 * 2.0.pow(cents / 1200), 440.0)
        assertTrue(reading(5.0).isInTune)
        assertTrue(reading(-5.0).isInTune)
        assertFalse(reading(5.1).isInTune)
        assertTrue(reading(5.1).isSharp)
        assertTrue(reading(-5.1).isFlat)
        assertFalse(reading(0.0).isFlat)
        assertFalse(reading(0.0).isSharp)
    }

    @Test
    fun guitarStrings() {
        assertEquals(
            listOf("E2", "A2", "D3", "G3", "B3", "E4"),
            Tuning.guitarStrings.map { Tuning.noteName(it, letters = true) + Tuning.octave(it) },
        )
        assertEquals(listOf("Mi", "Lá", "Ré", "Sol", "Si", "Mi"), Tuning.guitarStrings.map { Tuning.noteName(it, letters = false) })

        assertEquals(0, Tuning.nearestGuitarString(82.41))
        assertEquals(1, Tuning.nearestGuitarString(104.0)) // closer to A2 than to E2
        assertEquals(2, Tuning.nearestGuitarString(146.8))
        assertEquals(3, Tuning.nearestGuitarString(190.0))
        assertEquals(4, Tuning.nearestGuitarString(250.0))
        assertEquals(5, Tuning.nearestGuitarString(330.0))
        assertEquals(5, Tuning.nearestGuitarString(600.0))
        assertNull(Tuning.nearestGuitarString(0.0))

        // A2 a little flat: tighten
        val flat = Tuning.reading(108.0, string = 1)!!
        assertEquals(45, flat.midi)
        assertEquals(-31.77, flat.cents, 0.01)
        assertTrue(flat.isFlat)
        // A string picked by hand is compared even from far away (low E tuned a fourth up toward A)
        val far = Tuning.reading(110.0, string = 0)!!
        assertEquals(500.0, far.cents, 0.01)
        assertNull(Tuning.reading(110.0, string = 6))
    }

    @Test
    fun noteNamesAndOctaves() {
        assertEquals("C", Tuning.noteName(60, letters = true))
        assertEquals("Dó", Tuning.noteName(60, letters = false))
        assertEquals("C♯", Tuning.noteName(61, letters = true))
        assertEquals("Lá♯", Tuning.noteName(70, letters = false))
        assertEquals(4, Tuning.octave(60))
        assertEquals(3, Tuning.octave(59))
        assertEquals(0, Tuning.octave(21))
        assertEquals(8, Tuning.octave(108))
    }

    // Pitch of one window

    @Test
    fun detectorOnGuitarStrings() {
        val profiles = listOf(
            floatArrayOf(1f), // a pure sine
            floatArrayOf(1f, 0.7f, 0.45f, 0.3f, 0.2f, 0.12f, 0.08f, 0.05f), // a plucked string
            floatArrayOf(0.15f, 1f, 0.8f, 0.6f, 0.4f, 0.3f, 0.2f), // a weak fundamental, as from a small speaker or a far microphone
        )
        for (midi in Tuning.guitarStrings) {
            for (profile in profiles) {
                // Past the 4 ms attack, which isn't periodic yet
                val window = tone(Tuning.frequency(midi), 0.2, harmonics = profile).copyOfRange(2400, 6496)
                val label = "MIDI $midi, ${profile.size} harmonics"
                val estimate = PitchDetector.estimate(window, sampleRate, lowest = 60.0, highest = 1400.0)
                assertNotNull(label, estimate)
                assertEquals(label, 0.0, Tuning.cents(Tuning.frequency(midi), estimate!!.frequency), 1.0)
                assertTrue(label, estimate.clarity > 0.9)
            }
        }
    }

    @Test
    fun detectorOnThePianoRange() {
        // The low keys' fundamental is weak (most of their sound is in the harmonics); the top keys are nearly sines
        for (midi in listOf(21, 24, 28, 33, 40, 48, 60, 69, 84, 96, 108)) {
            val profile = if (midi < 45) floatArrayOf(0.1f, 0.5f, 1f, 0.8f, 0.6f, 0.5f, 0.4f, 0.3f, 0.25f, 0.2f)
            else floatArrayOf(1f, 0.3f, 0.1f)
            val window = tone(Tuning.frequency(midi), 0.25, harmonics = profile).copyOfRange(2400, 10592)
            val estimate = PitchDetector.estimate(window, sampleRate, lowest = 26.0, highest = 4300.0)
            assertNotNull("MIDI $midi", estimate)
            assertEquals(midi, Tuning.nearestNote(estimate!!.frequency)?.midi)
            assertEquals("MIDI $midi", 0.0, Tuning.cents(Tuning.frequency(midi), estimate.frequency), 2.0)
        }
    }

    // Tracking a ringing note

    @Test
    fun trackerHoldsPluckedStringsSteady() {
        for (midi in Tuning.guitarStrings) {
            val target = Tuning.frequency(midi)
            val audio = silence(0.3) + tone(target, 2.5, stretch = 0.00005, decaying = true, seed = midi.toLong())
            val readings = track(audio, TunerMode.GUITAR)
            val ringing = readings.filter { it.first > 0.6 && it.first < 2.8 }
            assertFalse(ringing.isEmpty())
            // Never a gap while the string rings, and never more than a cent off
            assertTrue("MIDI $midi: lost the note while it rang", ringing.all { it.second != null })
            val worst = ringing.mapNotNull { it.second }.maxOfOrNull { abs(Tuning.cents(target, it)) } ?: Double.POSITIVE_INFINITY
            assertTrue("MIDI $midi: $worst cents", worst < 1)
            // And the needle is up within a quarter second of the pluck
            val first = readings.firstOrNull { it.second != null }?.first ?: Double.POSITIVE_INFINITY
            assertTrue("MIDI $midi", first < 0.3 + 0.25)
        }
    }

    @Test
    fun trackerReadsAnOutOfTuneString() {
        // Low E 20 cents flat in a noisy room, A2 13 cents sharp, high E 35 cents flat
        for ((midi, detune) in listOf(40 to -20.0, 45 to 13.0, 64 to -35.0)) {
            val target = Tuning.frequency(midi)
            val audio = silence(0.3) + tone(target * 2.0.pow(detune / 1200), 2.0, decaying = true, noise = 0.006f, seed = 7)
            val readings = track(audio, TunerMode.GUITAR).filter { it.first > 0.6 && it.first < 1.8 }
            val cents = readings.mapNotNull { it.second }.map { Tuning.cents(target, it) }
            assertEquals("MIDI $midi", readings.size, cents.size)
            for (value in cents) assertEquals("MIDI $midi", detune, value, 2.0)
            val index = Tuning.nearestGuitarString(target * 2.0.pow(detune / 1200))!!
            assertEquals(midi, Tuning.guitarStrings[index])
        }
    }

    @Test
    fun trackerFollowsThePianoBass() {
        for (midi in listOf(21, 28, 33, 48, 60, 72, 84, 96, 108)) {
            val target = Tuning.frequency(midi)
            val profile = if (midi < 45) floatArrayOf(0.15f, 0.6f, 1f, 0.8f, 0.6f, 0.5f, 0.4f, 0.3f, 0.25f, 0.2f)
            else floatArrayOf(1f, 0.5f, 0.3f, 0.2f, 0.1f)
            val audio = silence(0.3) +
                tone(target, 2.5, harmonics = profile, decaying = true, slowFade = true, seed = midi.toLong())
            val ringing = track(audio, TunerMode.PIANO).filter { it.first > 0.8 && it.first < 2.8 }
            assertTrue("MIDI $midi: lost the note while it rang", ringing.all { it.second != null })
            for (frequency in ringing.mapNotNull { it.second }) {
                assertEquals(midi, Tuning.nearestNote(frequency)?.midi)
                assertEquals("MIDI $midi", 0.0, Tuning.cents(target, frequency), 1.5)
            }
        }
    }

    @Test
    fun trackerIgnoresSilence() {
        assertTrue(track(silence(2.0), TunerMode.GUITAR).all { it.second == null })
        assertTrue(track(silence(2.0), TunerMode.PIANO).all { it.second == null })
    }

    @Test
    fun trackerHoldsThenClearsAfterTheNoteStops() {
        val audio = silence(0.3) + tone(110.0, 1.0, seed = 3) + silence(2.5, seed = 4)
        val readings = track(audio, TunerMode.GUITAR)
        // Still on screen a moment after the sound stops, gone well before the end
        assertNotNull(readings.lastOrNull { it.first < 1.6 }?.second)
        val lastShown = readings.lastOrNull { it.second != null }?.first ?: 0.0
        assertTrue(lastShown > 1.3 + 0.8)
        assertTrue(lastShown < 1.3 + 1.6)
        assertNull(readings.last().second)
    }

    @Test
    fun trackerMovesToTheNextString() {
        // Low E, then A2 plucked straight after: the reading jumps to A2 instead of gliding through the notes between
        val audio = silence(0.3) + tone(Tuning.frequency(40), 1.0, seed = 3) + tone(Tuning.frequency(45), 1.5, seed = 4)
        val readings = track(audio, TunerMode.GUITAR)
        val afterSwitch = readings.filter { it.first > 1.3 }.mapNotNull { it.second }
        val between = afterSwitch.filter { frequency ->
            val toE = abs(Tuning.cents(Tuning.frequency(40), frequency))
            val toA = abs(Tuning.cents(Tuning.frequency(45), frequency))
            toE > 10 && toA > 10
        }
        assertTrue("Readings between the two strings: $between", between.isEmpty())
        val settled = readings.filter { it.first > 1.3 + 0.3 }.mapNotNull { it.second }
        assertFalse(settled.isEmpty())
        for (frequency in settled) assertEquals(0.0, Tuning.cents(Tuning.frequency(45), frequency), 1.0)
    }

    @Test
    fun trackerWorksWithAnyHopSize() {
        // The microphone's buffers are not always the size asked for
        for (hop in listOf(1024, 4800)) {
            val target = Tuning.frequency(40)
            val audio = silence(0.3) + tone(target, 2.0, decaying = true, seed = 5)
            val ringing = track(audio, TunerMode.GUITAR, hop).filter { it.first > 0.7 && it.first < 2.2 }
            assertFalse(ringing.isEmpty())
            for (frequency in ringing.map { it.second }) {
                assertEquals("hop $hop", 0.0, Tuning.cents(target, frequency ?: 0.0), 1.0)
            }
        }
    }

    // Synthetic audio

    /** A tone with [harmonics] (weights from the fundamental up), optionally stretched as on real strings and fading as a
     *  plucked or struck one, the upper harmonics faster; with a little room noise. */
    private fun tone(
        frequency: Double,
        seconds: Double,
        harmonics: FloatArray = floatArrayOf(1f, 0.7f, 0.45f, 0.3f, 0.2f, 0.12f, 0.08f, 0.05f),
        stretch: Double = 0.0,
        decaying: Boolean = false,
        slowFade: Boolean = false,
        noise: Float = 0.0015f,
        seed: Long = 1,
    ): FloatArray {
        val count = (seconds * sampleRate).toInt()
        val generator = SeededNoise(seed * 2_654_435_761L + 1)
        class Partial(val frequency: Double, val weight: Double, val fade: Double)
        val partials = harmonics.withIndex().mapNotNull { (index, weight) ->
            val n = (index + 1).toDouble()
            val partial = n * frequency * sqrt(1 + stretch * n * n)
            if (partial >= sampleRate / 2) return@mapNotNull null
            val fade = if (decaying) (if (slowFade) 0.5 + 0.3 * n else 1.2 + 0.7 * n) else 0.0
            Partial(partial, weight.toDouble(), fade)
        }
        return FloatArray(count) { index ->
            val t = index / sampleRate
            var sample = 0.0
            for (partial in partials) sample += partial.weight * exp(-t * partial.fade) * sin(2 * PI * partial.frequency * t)
            val attack = minOf(1.0, t / 0.004)
            (sample * attack).toFloat() * 0.25f + generator.next() * noise
        }
    }

    private fun silence(seconds: Double, seed: Long = 99): FloatArray {
        val generator = SeededNoise(seed)
        return FloatArray((seconds * sampleRate).toInt()) { generator.next() * 0.0015f }
    }

    /** The pitch shown after each hop, with the time at the end of that hop. */
    private fun track(audio: FloatArray, mode: TunerMode, hop: Int = 2048): List<Pair<Double, Double?>> {
        val tracker = TunerPitchTracker(sampleRate, TunerPitchTracker.Settings(mode))
        val readings = ArrayList<Pair<Double, Double?>>()
        var start = 0
        while (start + hop <= audio.size) {
            val frequency = tracker.process(audio, start, hop)
            start += hop
            readings += (start / sampleRate) to frequency
        }
        return readings
    }
}
