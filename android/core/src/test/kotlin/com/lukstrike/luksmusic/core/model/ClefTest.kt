// ClefTest.kt — port of luksMusicTests/ClefTests.swift. Where each clef writes a pitch, its key signatures, and the
// clef the reading drill picks by itself.
package com.lukstrike.luksmusic.core.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ClefTest {

    /** "C4", "F#3", "Bb2" (the lessons' notation, iOS LessonNotation.pitch(from:)). */
    private fun pitch(text: String): Pitch {
        val name = NoteName.valueOf(text.take(1))
        val accidental = when (text.drop(1).takeWhile { !it.isDigit() && it != '-' }) {
            "" -> Accidental.NATURAL
            "#" -> Accidental.SHARP
            "b" -> Accidental.FLAT
            else -> error("not a pitch: $text")
        }
        val octave = text.dropWhile { !it.isDigit() && it != '-' }.toInt()
        return Pitch(name, octave, accidental)
    }

    @Test
    fun middleCInEachClef() {
        assertEquals("first ledger line below", -6, Clef.TREBLE.position(pitch("C4")))
        assertEquals("first ledger line above", 6, Clef.BASS.position(pitch("C4")))
        assertEquals("the middle line, where the C clef points", 0, Clef.ALTO.position(pitch("C4")))
        assertEquals("bottom line", -4, Clef.ALTO.position(pitch("F3")))
        assertEquals("top line", 4, Clef.ALTO.position(pitch("G4")))
    }

    @Test
    fun trebleAndBassAgreeWithTheScoreStaves() {
        for (octave in 1..6) {
            for (name in NoteName.entries) {
                val pitch = Pitch(name, octave)
                assertEquals(Note(pitch = pitch, staff = Staff.TREBLE).staffPosition, Clef.TREBLE.position(pitch))
                assertEquals(Note(pitch = pitch, staff = Staff.BASS).staffPosition, Clef.BASS.position(pitch))
            }
        }
    }

    @Test
    fun ledgerLines() {
        assertEquals(1, Clef.TREBLE.ledgerLines(pitch("C4")))
        assertEquals(2, Clef.TREBLE.ledgerLines(pitch("A3")))
        assertEquals("the space below the staff", 0, Clef.TREBLE.ledgerLines(pitch("D4")))
        assertEquals(1, Clef.BASS.ledgerLines(pitch("E2")))
        assertEquals(0, Clef.ALTO.ledgerLines(pitch("C4")))
        assertEquals("above the first ledger line", 1, Clef.ALTO.ledgerLines(pitch("C5")))
        assertEquals(2, Clef.ALTO.ledgerLines(pitch("D5")))
    }

    /** Each sharp or flat of a key signature sits on a line or space of the note it alters. */
    @Test
    fun keySignaturesSitOnTheirNotes() {
        val sharps = listOf(NoteName.F, NoteName.C, NoteName.G, NoteName.D, NoteName.A, NoteName.E, NoteName.B)
        val flats = sharps.reversed()
        for (clef in Clef.entries) {
            val bottomLine = clef.middleLine - 4
            for ((steps, names) in listOf(clef.keySignatureSteps(true) to sharps, clef.keySignatureSteps(false) to flats)) {
                assertEquals("$clef", names.map { it.diatonicIndex }, steps.map { Math.floorMod(bottomLine + it, 7) })
                assertTrue("$clef stays on the staff", steps.all { it in -1..9 })
            }
        }
    }

    @Test
    fun fewestLedgerLines() {
        val lowRightHand = listOf("A3", "C4", "E4").map(::pitch)
        assertEquals(Clef.ALTO, Clef.fewestLedgerLines(lowRightHand, usual = Clef.TREBLE, usesAlto = true))
        // Treble and bass need three ledger lines each, so the hand keeps its usual clef
        assertEquals(Clef.TREBLE, Clef.fewestLedgerLines(lowRightHand, usual = Clef.TREBLE, usesAlto = false))
        assertEquals(Clef.TREBLE, Clef.fewestLedgerLines(listOf("E5", "G5").map(::pitch), usual = Clef.BASS, usesAlto = true))
        assertEquals(Clef.BASS, Clef.fewestLedgerLines(listOf("E2", "G2").map(::pitch), usual = Clef.TREBLE, usesAlto = true))
        assertEquals(Clef.BASS, Clef.fewestLedgerLines(emptyList(), usual = Clef.BASS, usesAlto = true))
    }

    @Test
    fun clefChoiceKeepsTheIosSavedValues() {
        assertEquals(listOf("score", "automatic", "treble", "bass", "alto"), ClefChoice.entries.map { it.raw })
        assertEquals(ClefChoice.ALTO, ClefChoice.fromRaw("alto"))
        assertEquals(ClefChoice.SCORE, ClefChoice.fromRaw(null))
        assertEquals(ClefChoice.SCORE, ClefChoice.fromRaw("unknown"))
        assertEquals(Clef.BASS, ClefChoice.BASS.fixedClef)
        assertEquals(null, ClefChoice.AUTOMATIC.fixedClef)
    }
}
