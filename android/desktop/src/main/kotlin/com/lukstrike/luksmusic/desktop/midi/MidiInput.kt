// MidiInput.kt — USB MIDI keyboards on the desktop (javax.sound.midi; ALSA raw MIDI on Linux, so the Deck needs no
// driver). Every input port is opened; the list is checked every two seconds, so a keyboard plugged in later is
// found, and one unplugged is closed. Note on/off and the sustain pedal are parsed by core's MidiMessage, the same
// rules as the Android and iOS apps, and handed to the screens through [events].
package com.lukstrike.luksmusic.desktop.midi

import com.lukstrike.luksmusic.core.practice.MidiMessage
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.sound.midi.MidiDevice
import javax.sound.midi.MidiSystem
import javax.sound.midi.Receiver
import javax.sound.midi.Sequencer
import javax.sound.midi.ShortMessage
import javax.sound.midi.Synthesizer
import javax.sound.midi.MidiMessage as JavaMidiMessage

/** What a keyboard did. */
sealed interface KeyEvent {
    data class NoteOn(val note: Int, val velocity: Int) : KeyEvent
    data class NoteOff(val note: Int) : KeyEvent
    data class Sustain(val down: Boolean) : KeyEvent
}

/** One MIDI port as the system lists it, reduced to what choosing inputs needs (testable without devices). */
data class PortInfo(val key: String, val name: String, val isInput: Boolean)

object MidiPorts {
    /** The ports to open: inputs only (Java's own sequencer and synthesizer are not keyboards). */
    fun inputs(ports: List<PortInfo>): List<PortInfo> = ports.filter { it.isInput }.distinctBy { it.key }

    /** Which open ports to close and which new ones to open, given the ports open now. */
    fun diff(open: Set<String>, available: List<PortInfo>): Pair<Set<String>, List<PortInfo>> {
        val keys = available.mapTo(HashSet()) { it.key }
        return (open - keys) to available.filter { it.key !in open }
    }

    /** A port's name without ALSA's "[hw:1,0,0]" suffix. */
    fun displayName(name: String): String = name.replace(Regex("""\s*\[hw:[^\]]*]\s*$"""), "").trim().ifEmpty { name }

    /** A java short message as a KeyEvent; null for anything but notes and the sustain pedal. */
    fun event(command: Int, channel: Int, data1: Int, data2: Int): KeyEvent? =
        when (val message = MidiMessage.fromStatus(command ushr 4, channel, data1, data2)) {
            is MidiMessage.NoteOn -> KeyEvent.NoteOn(message.note, message.velocity)
            is MidiMessage.NoteOff -> KeyEvent.NoteOff(message.note)
            is MidiMessage.ControlChange -> if (message.isSustain) KeyEvent.Sustain(message.isPressed) else null
            null -> null
        }
}

class MidiInput {
    private val _events = MutableSharedFlow<KeyEvent>(extraBufferCapacity = 256)
    val events: SharedFlow<KeyEvent> = _events

    private val _connected = MutableStateFlow<List<String>>(emptyList())
    /** Names of the keyboards open now. */
    val connected: StateFlow<List<String>> = _connected

    private val open = LinkedHashMap<String, Pair<MidiDevice, String>>()
    private val executor = Executors.newSingleThreadScheduledExecutor { r -> Thread(r, "luksMusic-midi").apply { isDaemon = true } }

    fun start() {
        executor.scheduleWithFixedDelay({ runCatching { scan() } }, 0, 2, TimeUnit.SECONDS)
    }

    /** Looks for keyboards now (the settings' "Search again"). */
    fun rescan() {
        executor.execute { runCatching { scan() } }
    }

    fun shutdown() {
        executor.shutdownNow()
        synchronized(open) { open.values.forEach { runCatching { it.first.close() } }; open.clear() }
    }

    private fun scan() {
        val devices = HashMap<String, MidiDevice>()
        val ports = MidiSystem.getMidiDeviceInfo().mapNotNull { info ->
            val device = runCatching { MidiSystem.getMidiDevice(info) }.getOrNull() ?: return@mapNotNull null
            val key = "${info.name}|${info.vendor}|${info.description}|${info.version}"
            devices[key] = device
            PortInfo(key, info.name, device !is Sequencer && device !is Synthesizer && device.maxTransmitters != 0)
        }
        val inputs = MidiPorts.inputs(ports)
        synchronized(open) {
            val (gone, added) = MidiPorts.diff(open.keys.toSet(), inputs)
            for (key in gone) open.remove(key)?.let { runCatching { it.first.close() } }
            for (port in added) {
                val device = devices[port.key] ?: continue
                runCatching {
                    if (!device.isOpen) device.open()
                    device.transmitter.receiver = receiver
                    open[port.key] = device to MidiPorts.displayName(port.name)
                }.onFailure { runCatching { device.close() } }
            }
            val names = open.values.map { it.second }
            if (names != _connected.value) _connected.value = names
        }
    }

    private val receiver = object : Receiver {
        override fun send(message: JavaMidiMessage, timeStamp: Long) {
            val short = message as? ShortMessage ?: return
            MidiPorts.event(short.command, short.channel, short.data1, short.data2)?.let { _events.tryEmit(it) }
        }

        override fun close() = Unit
    }
}
