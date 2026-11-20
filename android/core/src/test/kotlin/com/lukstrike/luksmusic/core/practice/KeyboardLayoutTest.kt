// KeyboardLayoutTest.kt — where the keys of the on-screen piano are, the falling notes' lanes and the keyboard range
// Modo Estudo picks for a piece.
package com.lukstrike.luksmusic.core.practice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class KeyboardLayoutTest {

    private val layout = KeyboardLayout(48, 84) // C3–C6

    @Test
    fun blackKeys() {
        assertTrue(PianoKeys.isBlack(61))
        assertTrue(PianoKeys.isBlack(70))
        assertFalse(PianoKeys.isBlack(60))
        assertFalse(PianoKeys.isBlack(64))
        assertFalse(PianoKeys.isBlack(65))
    }

    @Test
    fun threeOctavesAndATopC() {
        assertEquals(22, layout.whiteKeyCount)
        assertEquals(15, layout.blackKeys.size)
        assertEquals(0, layout.whiteKeysBefore(48))
        assertEquals(7, layout.whiteKeysBefore(60))
        assertEquals(8, layout.whiteKeysBefore(61))
    }

    @Test
    fun lanesSitOnTheKeys() {
        assertEquals(0.5, layout.centerX(48), 1e-9)
        assertEquals(7.5, layout.centerX(60), 1e-9)
        // C♯4 on the line between C4 and D4
        assertEquals(8.0, layout.centerX(61), 1e-9)
        assertEquals(8.0 - 0.3, layout.blackKeyLeft(61, 0.6), 1e-9)
    }

    @Test
    fun touchesFindTheKeyOnTop() {
        // Low on the keys: always the white key
        assertEquals(60, layout.keyAt(7.95, 0.9))
        assertEquals(62, layout.keyAt(8.05, 0.9))
        // High up, near the C4|D4 line: the black key covers it
        assertEquals(61, layout.keyAt(7.95, 0.3))
        assertEquals(61, layout.keyAt(8.25, 0.3))
        // Middle of C4, high up: no black key there
        assertEquals(60, layout.keyAt(7.5, 0.3))
        // E4|F4 has no black key between
        assertEquals(64, layout.keyAt(9.95, 0.1))
        assertEquals(65, layout.keyAt(10.05, 0.1))
        assertNull(layout.keyAt(-0.1, 0.5))
        assertNull(layout.keyAt(22.0, 0.5))
        assertNull(layout.keyAt(3.0, 1.2))
    }

    @Test
    fun practiceRangeCoversThePieceInWholeOctaves() {
        // No notes: the defaults C3 and C6, and C6 rounds up to the next octave (as on iOS)
        assertEquals(48..96, PianoKeys.practiceRange(emptyList()))
        assertEquals("small pieces still show three octaves", 48..84, PianoKeys.practiceRange(listOf(60, 67)))
        assertEquals(36..84, PianoKeys.practiceRange(listOf(40, 72)))
        assertEquals(48..96, PianoKeys.practiceRange(listOf(60, 86)))
        assertEquals("never past C1–C8", 24..108, PianoKeys.practiceRange(listOf(10, 120)))
    }
}
