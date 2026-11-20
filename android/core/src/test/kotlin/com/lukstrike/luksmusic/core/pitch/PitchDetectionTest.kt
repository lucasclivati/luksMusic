// PitchDetectionTest.kt — port of iOS luksMusicTests/PitchDetectionTests.swift: the microphone analysis against
// synthetic piano tones (harmonics that fade at different speeds, stretched slightly as on real strings, with a little
// room noise). "Ringing" tones fade slowly, as with the sustain pedal down, so several notes sound at once.
// (The USB keyboard decoding test belongs with the MIDI code.)
package com.lukstrike.luksmusic.core.pitch

import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

class PitchDetectionTest {

    private val sampleRate = 48_000.0

    private fun frequency(midi: Int) = 440.0 * 2.0.pow((midi - 69.0) / 12.0)

    /** A struck string: [harmonics] weights per harmonic, the upper ones fading faster. */
    private fun tone(
        midi: Int,
        seconds: Double,
        amplitude: Float = 0.25f,
        harmonics: FloatArray = floatArrayOf(1f, 0.7f, 0.45f, 0.3f, 0.2f, 0.12f, 0.08f, 0.05f),
        ringing: Boolean = false,
    ): FloatArray {
        val f0 = frequency(midi)
        val count = (seconds * sampleRate).toInt()
        val generator = SeededNoise(midi.toLong() * 2_654_435_761L + 1)
        return FloatArray(count) { index ->
            val t = index / sampleRate
            var sample = 0.0
            for ((h, weight) in harmonics.withIndex()) {
                val n = (h + 1).toDouble()
                val stretched = n * f0 * sqrt(1 + 0.0004 * n * n)
                if (stretched >= sampleRate / 2) continue
                val fade = if (ringing) 0.35 + 0.25 * n else 1.2 + 0.7 * n
                sample += weight * exp(-t * fade) * sin(2 * PI * stretched * t)
            }
            val attack = minOf(1.0, t / 0.004)
            (sample * attack).toFloat() * amplitude + generator.next() * 0.0015f
        }
    }

    private fun silence(seconds: Double): FloatArray {
        val generator = SeededNoise(99)
        return FloatArray((seconds * sampleRate).toInt()) { generator.next() * 0.0015f }
    }

    /** Notes struck [gap] seconds apart, each one still sounding under the next ones. */
    private fun played(notes: List<Int>, gap: Double, amplitudes: List<Float>? = null, ringing: Boolean = false): FloatArray {
        val audio = silence(0.3 + gap * notes.size + 2)
        for ((index, midi) in notes.withIndex()) {
            val start = ((0.3 + gap * index) * sampleRate).toInt()
            val sound = tone(midi, 2.0, amplitudes?.get(index) ?: 0.25f, ringing = ringing)
            for (offset in sound.indices) audio[start + offset] += sound[offset]
        }
        return audio
    }

    /** What a lesson hears: the reader is told the next note, which moves on only when that note is heard. */
    private fun notes(samples: FloatArray, expecting: List<Int>): List<Int> {
        val reader = MicrophoneNoteReader(sampleRate)
        val found = ArrayList<Int>()
        var next = 0
        reader.expectedNotes = setOf(expecting[0])
        var start = 0
        while (start < samples.size) {
            val end = minOf(samples.size, start + 2048)
            for (note in reader.read(samples, start, end - start)) {
                found += note
                if (next < expecting.size && note == expecting[next]) next += 1
            }
            reader.expectedNotes = if (next < expecting.size) setOf(expecting[next]) else null
            start = end
        }
        return found
    }

    private fun notes(samples: FloatArray, chunk: Int = 2048): List<Int> {
        val reader = MicrophoneNoteReader(sampleRate)
        val result = ArrayList<Int>()
        var start = 0
        while (start < samples.size) {
            val end = minOf(samples.size, start + chunk)
            result += reader.read(samples, start, end - start)
            start = end
        }
        return result
    }

    @Test
    fun everyPianoNoteLessonsUseIsReadInTheRightOctave() {
        for (midi in 36..96) {
            val window = tone(midi, 0.25).copyOfRange(2400, 6496)
            assertEquals("MIDI $midi", midi, PitchDetector.estimate(window, sampleRate)?.midiNote)
        }
    }

    @Test
    fun lowNotesWithAWeakFundamentalStayInTheirOctave() {
        for (midi in listOf(36, 40, 45, 48)) {
            val window = tone(midi, 0.25, harmonics = floatArrayOf(0.15f, 1f, 0.8f, 0.5f, 0.3f, 0.2f)).copyOfRange(2400, 6496)
            assertEquals("MIDI $midi", midi, PitchDetector.estimate(window, sampleRate)?.midiNote)
        }
    }

    @Test
    fun aHeldNoteCountsOnce() {
        assertEquals(listOf(60), notes(silence(0.2) + tone(60, 1.5)))
    }

    @Test
    fun theSameNoteStruckTwiceCountsTwice() {
        val audio = silence(0.2) + tone(60, 0.5) + tone(60, 0.5)
        assertEquals(listOf(60, 60), notes(audio))
    }

    @Test
    fun aScaleWithNotesRingingIntoEachOtherIsReadInOrder() {
        val scale = listOf(60, 62, 64, 65, 67, 69, 71, 72)
        for (played in listOf(scale, scale.reversed())) {
            // Each note starts 0.45 s after the last and keeps sounding under the next ones
            val audio = silence(0.2 + 0.45 * played.size + 1.2)
            for ((index, midi) in played.withIndex()) {
                val start = ((0.2 + 0.45 * index) * sampleRate).toInt()
                val sound = tone(midi, 1.2)
                for (offset in sound.indices) audio[start + offset] += sound[offset]
            }
            assertEquals(played, notes(audio))
        }
    }

    @Test
    fun chunkSizeDoesNotChangeTheResult() {
        val audio = silence(0.2) + tone(64, 0.6) + tone(67, 0.6)
        assertEquals(listOf(64, 67), notes(audio, chunk = 4800))
        assertEquals(listOf(64, 67), notes(audio, chunk = 512))
    }

    @Test
    fun aQuietPianoFarFromThePhoneIsStillHeard() {
        // The built-in microphone, without automatic gain, hears a piano across the room this softly
        for (amplitude in listOf(0.012f, 0.005f)) {
            val audio = silence(0.4) + tone(64, 0.8, amplitude) + tone(67, 0.8, amplitude)
            assertEquals("amplitude $amplitude", listOf(64, 67), notes(audio))
        }
    }

    @Test
    fun silenceAndNoiseAreNotNotes() {
        assertEquals(emptyList<Int>(), notes(silence(1.0)))
        val generator = SeededNoise(5)
        val hiss = FloatArray(48_000) { generator.next() * 0.2f }
        assertEquals(emptyList<Int>(), notes(hiss))
    }

    private fun chord(notes: List<Int>, seconds: Double = 0.7): FloatArray {
        val audio = silence(0.3 + seconds)
        val start = (0.2 * sampleRate).toInt()
        for (midi in notes) {
            val sound = tone(midi, seconds, 0.15f)
            for (offset in sound.indices) audio[start + offset] += sound[offset]
        }
        return audio
    }

    private fun readChord(audio: FloatArray, expecting: Set<Int>): Pair<List<Int>, Int> {
        val reader = MicrophoneNoteReader(sampleRate)
        reader.expectedNotes = expecting
        val result = ArrayList<Int>()
        var start = 0
        while (start < audio.size) {
            val end = minOf(audio.size, start + 2048)
            result += reader.read(audio, start, end - start)
            start = end
        }
        return result to reader.missedChords
    }

    @Test
    fun aChordIsHeardOnlyWhenAllItsNotesSound() {
        val cMajor = setOf(60, 64, 67)
        assertEquals(listOf(60, 64, 67), readChord(chord(listOf(60, 64, 67)), cMajor).first)

        val wrongChord = readChord(chord(listOf(65, 69, 72)), cMajor)
        assertEquals(emptyList<Int>(), wrongChord.first)
        assertEquals(1, wrongChord.second)

        val incomplete = readChord(chord(listOf(60, 64)), cMajor)
        assertEquals(emptyList<Int>(), incomplete.first)
        assertEquals(1, incomplete.second)
    }

    /** Two ringing notes read together sound like their common lower octave; the strike must be read by what it added. */
    @Test
    fun notesStillRingingUnderThePedalDontConfuseTheReading() {
        val scale = listOf(60, 62, 64, 65, 67, 69, 71, 72)
        val leaps = listOf(60, 67, 64, 72, 65, 69, 62, 71)
        for (melody in listOf(scale, scale.reversed(), leaps)) {
            val heard = notes(played(melody, 0.5, ringing = true), expecting = melody)
            assertEquals(melody, heard.take(melody.size))
        }
    }

    @Test
    fun aSofterRepeatOfTheExpectedNoteCounts() {
        val audio = played(listOf(60, 60, 60), 0.6, amplitudes = listOf(0.25f, 0.15f, 0.1f))
        assertEquals(listOf(60, 60, 60), notes(audio, expecting = listOf(60, 60, 60)).take(3))
    }

    @Test
    fun aWrongNoteIsStillNamedWhenAnotherIsExpected() {
        assertEquals(listOf(60, 65), notes(played(listOf(60, 65), 0.5, ringing = true), expecting = listOf(60, 64)))
        assertEquals("the octave below", listOf(60, 52), notes(played(listOf(60, 52), 0.5), expecting = listOf(60, 64)))
    }

    @Test
    fun fftMatchesTheDirectDifferenceFunction() {
        // The FFT shortcut in PitchDetector must agree with the plain sum of squares iOS computes lag by lag
        val samples = tone(57, 0.25).copyOfRange(2400, 6496)
        val maxLag = 960
        val fast = PitchDetector.differenceFunction(samples, maxLag)
        val window = samples.size - maxLag
        for (lag in 1..maxLag) {
            var direct = 0.0
            for (i in 0 until window) {
                val d = samples[i].toDouble() - samples[i + lag]
                direct += d * d
            }
            assertEquals("lag $lag", direct, fast[lag], 1e-6 * maxOf(1.0, direct))
        }
    }
}
