// ReadingDrillTest.kt — port of luksMusicTests/ReadingDrillTests.swift.
//
// The sight-reading drill's rules: steps of one hand, checking key presses, printed accidentals, note names for
// scores without them, and the keyboard window.
package com.lukstrike.luksmusic.core.lessons

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.NoteName
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Staff
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class ReadingDrillTest {

    private fun note(
        name: NoteName, octave: Int, accidental: Accidental = Accidental.NATURAL, beat: Double,
        staff: Staff = Staff.TREBLE, duration: NoteDuration = NoteDuration.QUARTER, rest: Boolean = false,
        tieContinuation: Boolean? = null,
    ) = Note(pitch = Pitch(name, octave, accidental), duration = duration, isRest = rest, staff = staff, beat = beat,
        isTieContinuation = tieContinuation)

    // ---- Steps

    @Test
    fun notesKeptPerHandAndBothHandsReadTheWholePiece() {
        // Right hand: a chord G4 C5 E5 then a lone D5; left hand: C3 G3 with the chord, then F2 on beat 2 alone
        val measures = listOf(Measure(number = 1, notes = listOf(
            note(NoteName.G, 4, beat = 1.0), note(NoteName.C, 5, beat = 1.0), note(NoteName.E, 5, beat = 1.0),
            note(NoteName.C, 3, beat = 1.0, staff = Staff.BASS), note(NoteName.G, 3, beat = 1.0, staff = Staff.BASS),
            note(NoteName.F, 2, beat = 2.0, staff = Staff.BASS),
            note(NoteName.D, 5, beat = 3.0),
        )))
        fun steps(hand: ReadingHand, kept: ReadingNotes) =
            ReadingDrill.steps(measures, hand, 4, 4, kept).map { it.midiNotes }
        // The right hand keeps its top notes, the left hand its bottom notes
        assertEquals(listOf(setOf(76), setOf(74)), steps(ReadingHand.RIGHT, ReadingNotes.ONE))
        assertEquals(listOf(setOf(72, 76), setOf(74)), steps(ReadingHand.RIGHT, ReadingNotes.TWO))
        assertEquals(listOf(setOf(67, 72, 76), setOf(74)), steps(ReadingHand.RIGHT, ReadingNotes.ALL))
        assertEquals(listOf(setOf(48), setOf(41)), steps(ReadingHand.LEFT, ReadingNotes.ONE))
        assertEquals(listOf(setOf(48, 55), setOf(41)), steps(ReadingHand.LEFT, ReadingNotes.TWO))
        // Both hands: the melody alone (a bass note on its own is left out), melody and bass, or everything
        assertEquals(listOf(setOf(76), setOf(74)), steps(ReadingHand.BOTH, ReadingNotes.ONE))
        assertEquals(listOf(setOf(48, 76), setOf(41), setOf(74)), steps(ReadingHand.BOTH, ReadingNotes.TWO))
        assertEquals(listOf(setOf(48, 55, 67, 72, 76), setOf(41), setOf(74)), steps(ReadingHand.BOTH, ReadingNotes.ALL))
        // "Completo" is what one hand always read
        assertEquals(ReadingDrill.steps(measures, ReadingHand.RIGHT, 4, 4).map { it.midiNotes }, steps(ReadingHand.RIGHT, ReadingNotes.ALL))
    }

    @Test
    fun stepsGroupChordsAndSkipRestsTiesAndTheOtherHand() {
        val measures = listOf(
            Measure(number = 0, notes = listOf(note(NoteName.E, 5, beat = 1.0)), length = 1.0),
            Measure(number = 1, notes = listOf(
                note(NoteName.G, 4, beat = 1.0), note(NoteName.C, 5, beat = 1.0), note(NoteName.E, 5, beat = 1.0),
                note(NoteName.C, 3, beat = 1.0, staff = Staff.BASS),
                note(NoteName.C, 5, beat = 2.0, rest = true),
                note(NoteName.E, 5, beat = 3.0, tieContinuation = true),
                note(NoteName.D, 5, beat = 4.0),
            )),
        )
        val right = ReadingDrill.steps(measures, ReadingHand.RIGHT, 4, 4)
        assertEquals(listOf(setOf(76), setOf(67, 72, 76), setOf(74)), right.map { it.midiNotes })
        // A short first measure numbered 0 is a pickup
        assertEquals(listOf(0, 1, 1), right.map { it.measureNumber })
        // Other unnumbered measures (older data) count from their position
        val unnumbered = ReadingDrill.steps(
            listOf(Measure(number = 0, notes = listOf(note(NoteName.C, 5, beat = 1.0))),
                Measure(number = 0, notes = listOf(note(NoteName.D, 5, beat = 1.0)))),
            ReadingHand.RIGHT, 4, 4,
        )
        assertEquals(listOf(1, 2), unnumbered.map { it.measureNumber })
        // The pickup lasts one beat, so the next measure starts on beat 1 of the piece
        assertEquals(listOf(0.0, 1.0, 4.0), right.map { it.globalBeat })
        assertEquals("lowest first", listOf(67, 72, 76), right[1].notes.map { it.midiNote })

        val left = ReadingDrill.steps(measures, ReadingHand.LEFT, 4, 4)
        assertEquals(listOf(setOf(48)), left.map { it.midiNotes })
    }

    // ---- Pressing Keys

    @Test
    fun wrongKeysCountUntilTheRightOneAndChordsTakeAnyOrder() {
        val steps = ReadingDrill.steps(listOf(Measure(number = 1, notes = listOf(
            note(NoteName.E, 5, beat = 1.0),
            note(NoteName.C, 5, beat = 2.0), note(NoteName.E, 5, beat = 2.0),
            note(NoteName.A, 4, beat = 3.0),
        ))), ReadingHand.RIGHT, 4, 4)
        val state = ReadingSegmentState(steps)
        val outcomes = listOf(76, 77, 76, 76, 72).map { state.press(it) }
        assertEquals(
            "E5; a wrong F5; the chord's keys in any order",
            listOf(ReadingPress.Correct(true), ReadingPress.Wrong, ReadingPress.Correct(false), ReadingPress.Ignored, ReadingPress.Correct(true)),
            outcomes,
        )
        state.reveal()
        assertEquals(ReadingPress.Correct(true), state.press(69))
        assertTrue(state.isComplete)
        assertEquals(ReadingPress.Ignored, state.press(69))

        assertEquals(listOf(true, false, false), state.results.map { it.isClean })
        assertEquals(1, state.results[1].mistakes)
        assertTrue(state.results[2].revealed)
        assertEquals(1, state.cleanCount)
    }

    // ---- Segments

    @Test
    fun sequentialSegmentsAndRandomStarts() {
        assertEquals(4, ReadingDrill.segmentCount(10, 3))
        assertEquals(9 until 10, ReadingDrill.segment(9, 3, 10))
        assertEquals(3 until 6, ReadingDrill.segment(3, 3, 10))

        val random = Random(7)
        var previous: Int? = null
        repeat(200) {
            val start = ReadingDrill.randomStart(10, 3, previous, random)
            assertTrue(start in 0..7)
            assertNotEquals(previous, start)
            previous = start
        }
        assertEquals(0, ReadingDrill.randomStart(2, 3, 0, random))
    }

    // ---- Accidentals and Names

    @Test
    fun accidentalsArePrintedAgainstTheKeySignatureAndCarryThroughTheMeasure() {
        // G major: F♯ comes from the key; F natural needs ♮ once per measure; C♯ needs ♯
        val measures = listOf(
            Measure(number = 1, notes = listOf(
                note(NoteName.F, 5, Accidental.SHARP, beat = 1.0), note(NoteName.F, 5, beat = 2.0),
                note(NoteName.F, 5, beat = 3.0), note(NoteName.C, 5, Accidental.SHARP, beat = 4.0),
            )),
            Measure(number = 2, notes = listOf(note(NoteName.F, 5, Accidental.SHARP, beat = 1.0), note(NoteName.F, 5, beat = 2.0))),
        )
        val steps = ReadingDrill.steps(measures, ReadingHand.RIGHT, 4, 4)
        assertEquals(
            listOf(listOf(null), listOf(Accidental.NATURAL), listOf(null), listOf(Accidental.SHARP), listOf(null), listOf(Accidental.NATURAL)),
            ReadingDrill.printedAccidentals(steps, 1),
        )
        // F major: B♭ from the key
        assertEquals(-1, ReadingDrill.keyAlteration(NoteName.B, -1))
        assertEquals(0, ReadingDrill.keyAlteration(NoteName.E, -1))
        assertEquals(1, ReadingDrill.keyAlteration(NoteName.C, 2))
    }

    @Test
    fun notesWithOnlyMidiNumbersAreNamedForTheirKey() {
        fun spelled(midi: Int, key: Int) = ReadingDrill.name(ReadingDrill.spelledPitch(midi, key), usesLetters = false)
        assertEquals("Fá♯4", spelled(66, 1))
        assertEquals("Sol♭4", spelled(66, -1))
        assertEquals("Si♭4", spelled(70, 0))
        assertEquals("Dó♯4", spelled(61, 0))
        assertEquals("Ré♯4", spelled(63, 2))
        assertEquals("Dó4", spelled(60, 0))
        assertEquals("F♯4", ReadingDrill.name(ReadingDrill.spelledPitch(66, 1), usesLetters = true))
        // C♭ belongs to the octave above the B it sounds as
        assertEquals("C♭5", ReadingDrill.spelledPitch(71, -7).displayName)
        assertEquals(71, ReadingDrill.spelledPitch(71, -7).midiNoteNumber)
        assertEquals("B♯4", ReadingDrill.spelledPitch(72, 7).displayName)

        val gMajor = listOf(67, 69, 71, 72, 74, 76, 78, 79, 78, 74)
        assertEquals(1, ReadingDrill.estimatedKeySignature(gMajor))
        val fMajor = listOf(65, 67, 69, 70, 72, 74, 76, 77, 70, 70)
        assertEquals(-1, ReadingDrill.estimatedKeySignature(fMajor))
        assertEquals(0, ReadingDrill.estimatedKeySignature(listOf(60, 62, 64, 65, 67, 69, 71)))
        assertEquals(0, ReadingDrill.estimatedKeySignature(emptyList()))

        val (measures, keySignature) = ReadingDrill.respelled(listOf(Measure(number = 1, notes = gMajor.mapIndexed { index, midi ->
            Note(pitch = Pitch.fromMidi(midi), beat = (index % 4) + 1.0)
        })))
        assertEquals(1, keySignature)
        assertEquals("F♯5", measures[0].notes[6].pitch.displayName)
        assertEquals(gMajor, measures[0].notes.map { it.midiNote })

        val chord = ReadingDrill.steps(
            listOf(Measure(number = 1, notes = listOf(note(NoteName.C, 5, beat = 1.0), note(NoteName.E, 5, Accidental.FLAT, beat = 1.0)))),
            ReadingHand.RIGHT, 4, 4,
        )[0]
        assertEquals("Mi♭5 · Dó5", ReadingDrill.name(chord, usesLetters = false))
    }

    // ---- Keyboard Window

    @Test
    fun keyboardShowsTheWholeHandWhenItFits() {
        val range = ReadingDrill.keyboardRange(64..67, 60..76, 15, null)
        assertEquals(57..81, range)
        assertEquals(15, ReadingDrill.whiteCount(range.first, range.last))
    }

    @Test
    fun keyboardFollowsTheSegmentWhenTheHandIsWider() {
        val first = ReadingDrill.keyboardRange(74..76, 40..90, 15, null)
        assertEquals("starts on the C that centers the segment best", 60..84, first)

        // Stays put while the next segment fits
        assertEquals(first, ReadingDrill.keyboardRange(79..83, 40..90, 15, first))

        val moved = ReadingDrill.keyboardRange(86..88, 40..90, 15, first)
        assertTrue(86 in moved && 88 in moved)
        assertEquals(15, ReadingDrill.whiteCount(moved.first, moved.last))
        assertTrue(ReadingDrill.isWhite(moved.first) && ReadingDrill.isWhite(moved.last))

        // A segment wider than the screen gets every key it needs
        assertEquals(36..84, ReadingDrill.keyboardRange(36..84, 30..90, 15, null))

        // Never past the piano's last key
        val top = ReadingDrill.keyboardRange(105..108, 40..108, 15, null)
        assertEquals(108, top.last)
        assertEquals(15, ReadingDrill.whiteCount(top.first, top.last))
    }
}
