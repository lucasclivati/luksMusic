// MidiMessagesTest.kt — MIDI keyboard messages (the UMP cases port luksMusicTests testUSBKeyboardMessagesAreDecoded;
// the byte-stream cases cover what Android delivers: running status, split sends, real-time bytes, sysex).
package com.lukstrike.luksmusic.core.practice

import com.lukstrike.luksmusic.core.practice.MidiMessage.ControlChange
import com.lukstrike.luksmusic.core.practice.MidiMessage.NoteOff
import com.lukstrike.luksmusic.core.practice.MidiMessage.NoteOn
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MidiMessagesTest {

    private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }

    @Test
    fun universalMidiPacketWordsAreDecoded() {
        // Universal MIDI Packet words: type 2, group 0, then status/channel, note, velocity
        assertEquals(listOf(NoteOn(60, 100, 0)), MidiMessage.fromUmpWords(intArrayOf(0x20903C64)))
        assertEquals(listOf(NoteOff(60, 0)), MidiMessage.fromUmpWords(intArrayOf(0x20803C00)))
        assertEquals("velocity 0 releases", listOf(NoteOff(60, 0)), MidiMessage.fromUmpWords(intArrayOf(0x20903C00)))
        assertEquals(listOf(ControlChange(64, 127, 0)), MidiMessage.fromUmpWords(intArrayOf(0x20B0407F)))
        // A chord in one packet, with a clock message between the notes
        assertEquals(
            listOf(NoteOn(60, 100, 0), NoteOn(64, 100, 0)),
            MidiMessage.fromUmpWords(intArrayOf(0x20903C64, 0x10F80000, 0x20904064)),
        )
        // A two-word message's second word is not read as a note
        assertEquals(emptyList<MidiMessage>(), MidiMessage.fromUmpWords(intArrayOf(0x30017E00, 0x20903C64)))
    }

    @Test
    fun noteOnOffAndVelocityZero() {
        val parser = MidiStreamParser()
        assertEquals(listOf(NoteOn(60, 100, 0)), parser.parse(bytes(0x90, 60, 100)))
        assertEquals(listOf(NoteOff(60, 0)), parser.parse(bytes(0x80, 60, 64)))
        assertEquals("velocity 0 releases", listOf(NoteOff(62, 3)), parser.parse(bytes(0x93, 62, 0)))
    }

    @Test
    fun runningStatusKeepsTheLastStatus() {
        val parser = MidiStreamParser()
        // Note on once, then pairs; a velocity 0 pair is the release
        assertEquals(
            listOf(NoteOn(60, 90, 0), NoteOn(64, 80, 0), NoteOff(60, 0)),
            parser.parse(bytes(0x90, 60, 90, 64, 80, 60, 0)),
        )
        // ...and it carries over to the next send
        assertEquals(listOf(NoteOn(67, 70, 0)), parser.parse(bytes(67, 70)))
    }

    @Test
    fun aMessageSplitAcrossSendsIsJoined() {
        val parser = MidiStreamParser()
        assertTrue(parser.parse(bytes(0x91)).isEmpty())
        assertTrue(parser.parse(bytes(48)).isEmpty())
        assertEquals(listOf(NoteOn(48, 50, 1)), parser.parse(bytes(50)))
    }

    @Test
    fun offsetAndCountLimitTheBytesRead() {
        val parser = MidiStreamParser()
        val buffer = bytes(0xFF, 0x90, 60, 100, 0x90, 61)
        assertEquals(listOf(NoteOn(60, 100, 0)), parser.parse(buffer, offset = 1, count = 3))
    }

    @Test
    fun realTimeBytesInsideAMessageAreSkipped() {
        val parser = MidiStreamParser()
        // Clock and active sensing between the note's bytes
        assertEquals(listOf(NoteOn(60, 100, 0)), parser.parse(bytes(0x90, 0xF8, 60, 0xFE, 100)))
        // ...and they do not cancel running status
        assertEquals(listOf(NoteOn(62, 100, 0)), parser.parse(bytes(0xF8, 62, 100)))
    }

    @Test
    fun sustainPedalIsControlChange64() {
        val parser = MidiStreamParser()
        val down = parser.parse(bytes(0xB0, 64, 127)).single() as ControlChange
        assertTrue(down.isSustain)
        assertTrue(down.isPressed)
        val up = parser.parse(bytes(0xB0, 64, 0)).single() as ControlChange
        assertFalse(up.isPressed)
        assertTrue("half way counts as down", (parser.parse(bytes(0xB0, 64, 64)).single() as ControlChange).isPressed)
        assertFalse((parser.parse(bytes(0xB0, 7, 100)).single() as ControlChange).isSustain)
    }

    @Test
    fun otherMessagesAreIgnoredButKeepTheStreamInStep() {
        val parser = MidiStreamParser()
        // Program change (one data byte), pitch bend (two), then a note
        assertEquals(listOf(NoteOn(60, 1, 0)), parser.parse(bytes(0xC0, 5, 0xE0, 0, 64, 0x90, 60, 1)))
        // Running status of the program change takes one byte per message
        assertEquals(listOf(NoteOn(72, 9, 0)), parser.parse(bytes(0xC0, 1, 2, 3, 0x90, 72, 9)))
    }

    @Test
    fun systemExclusiveIsSkipped() {
        val parser = MidiStreamParser()
        assertEquals(
            listOf(NoteOn(60, 100, 0)),
            parser.parse(bytes(0xF0, 0x7E, 0x10, 0x7F, 0x06, 0x01, 0xF7, 0x90, 60, 100)),
        )
        // Data after the sysex has no running status to belong to
        assertTrue(parser.parse(bytes(0xF0, 1, 2, 0xF7, 60, 100)).isEmpty())
    }

    @Test
    fun systemCommonCancelsRunningStatus() {
        val parser = MidiStreamParser()
        // Note on, song select (one data byte), then orphan data bytes
        assertEquals(listOf(NoteOn(60, 100, 0)), parser.parse(bytes(0x90, 60, 100, 0xF3, 4, 61, 100)))
    }
}
