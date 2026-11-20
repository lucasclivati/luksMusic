// MidiMessages.kt — the MIDI parsing of Services/MIDI/MIDIService.swift: note on/off and control change, from the raw
// MIDI 1.0 byte stream Android delivers (MidiReceiver.onSend) and from Universal MIDI Packet words (what CoreMIDI
// hands the iOS app). Pure Kotlin so it is unit-tested; the app's MidiInputService feeds it.
package com.lukstrike.luksmusic.core.practice

/** The messages the app cares about. Notes and controllers are 0–127, channels 0–15. */
sealed interface MidiMessage {
    data class NoteOn(val note: Int, val velocity: Int, val channel: Int) : MidiMessage
    data class NoteOff(val note: Int, val channel: Int) : MidiMessage
    data class ControlChange(val controller: Int, val value: Int, val channel: Int) : MidiMessage {
        /** The sustain pedal (CC 64), down from half way. */
        val isSustain: Boolean get() = controller == SUSTAIN_PEDAL_CC
        val isPressed: Boolean get() = value >= 64
    }

    companion object {
        /** MIDI CC number for the sustain pedal. */
        const val SUSTAIN_PEDAL_CC = 64

        /**
         * Parses a status nibble (0x8–0xF) and its two data bytes into a typed message; null for the ones the app
         * ignores. Note On with velocity 0 is equivalent to Note Off.
         */
        fun fromStatus(status: Int, channel: Int, data1: Int, data2: Int): MidiMessage? = when (status) {
            0x9 -> if (data2 == 0) NoteOff(data1, channel) else NoteOn(data1, data2, channel)
            0x8 -> NoteOff(data1, channel)
            0xB -> ControlChange(data1, data2, channel)
            else -> null
        }

        /** The note and controller messages among Universal MIDI Packet words (port of `MIDIService.messages(in:)`). */
        fun fromUmpWords(words: IntArray): List<MidiMessage> {
            val messages = mutableListOf<MidiMessage>()
            var index = 0
            while (index < words.size) {
                val word = words[index]
                // Bits 31-28: message type; 0x2 is a MIDI 1.0 channel voice message
                val messageType = (word ushr 28) and 0x0F
                if (messageType == 0x2) {
                    fromStatus(
                        status = (word ushr 20) and 0x0F,
                        channel = (word ushr 16) and 0x0F,
                        data1 = (word ushr 8) and 0xFF,
                        data2 = word and 0xFF,
                    )?.let(messages::add)
                }
                // Longer message types take more than one word
                index += when (messageType) {
                    0x3, 0x4 -> 2
                    0x5 -> 4
                    else -> 1
                }
            }
            return messages
        }
    }
}

/**
 * Turns a MIDI 1.0 byte stream into messages. One parser per input port: it keeps the running status (a keyboard
 * may send the status byte once and then only note/velocity pairs) and a message split across two sends.
 *
 * Real-time bytes (clock, active sensing: 0xF8–0xFF) may come between any two bytes and are skipped without
 * touching the running status. System exclusive data is skipped up to its end. System common messages (0xF1–0xF6)
 * cancel the running status, as the MIDI spec says.
 */
class MidiStreamParser {
    /** The status byte the next data bytes belong to (0 = none). */
    private var status = 0
    private val data = IntArray(2)
    private var dataCount = 0
    private var inSysEx = false

    fun reset() {
        status = 0
        dataCount = 0
        inSysEx = false
    }

    /** Parses [count] bytes of [bytes] from [offset]; returns the complete messages they finish. */
    fun parse(bytes: ByteArray, offset: Int = 0, count: Int = bytes.size - offset): List<MidiMessage> {
        var messages: MutableList<MidiMessage>? = null
        for (i in offset until offset + count) {
            val byte = bytes[i].toInt() and 0xFF
            when {
                byte >= 0xF8 -> Unit // real-time: no effect on anything else
                byte == 0xF0 -> { inSysEx = true; status = 0; dataCount = 0 }
                byte == 0xF7 -> { inSysEx = false; status = 0; dataCount = 0 }
                byte >= 0x80 -> {
                    // Any other status byte also ends a system exclusive message left open
                    inSysEx = false
                    status = byte
                    dataCount = 0
                    // Tune request has no data
                    if (byte == 0xF6) status = 0
                }
                inSysEx || status == 0 -> Unit // data with no status to belong to
                else -> {
                    data[dataCount++] = byte
                    if (dataCount == dataLength(status)) {
                        dataCount = 0
                        if (status < 0xF0) {
                            val data2 = if (dataLength(status) == 2) data[1] else 0
                            val message = MidiMessage.fromStatus(status ushr 4, status and 0x0F, data[0], data2)
                            if (message != null) (messages ?: mutableListOf<MidiMessage>().also { messages = it }).add(message)
                        } else {
                            // System common messages do not set a running status
                            status = 0
                        }
                    }
                }
            }
        }
        return messages ?: emptyList()
    }

    private fun dataLength(status: Int): Int = when {
        status in 0xC0..0xDF -> 1 // program change, channel pressure
        status == 0xF1 || status == 0xF3 -> 1 // time code quarter frame, song select
        else -> 2 // notes, controllers, pitch bend, song position
    }
}
