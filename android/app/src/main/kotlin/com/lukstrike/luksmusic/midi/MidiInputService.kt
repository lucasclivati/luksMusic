// MidiInputService.kt — external MIDI keyboards over USB or Bluetooth (port of Services/MIDI/MIDIService.swift),
// through android.media.midi. One instance for the whole app, from AppContainer.midi.
//
// Every keyboard the system knows is opened (USB, and Bluetooth MIDI keyboards already connected to the system), and
// keyboards plugged in or removed later are followed through a DeviceCallback. Each output port of a keyboard (what it
// sends) gets its own MidiStreamParser (core/practice), so running status and split messages work per stream.
//
// PUBLIC API — other features use these members; keep their signatures stable.
package com.lukstrike.luksmusic.midi

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.midi.MidiDevice
import android.media.midi.MidiManager
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.core.content.ContextCompat
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.practice.MidiMessage
import com.lukstrike.luksmusic.core.practice.MidiStreamParser
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import android.media.midi.MidiDeviceInfo as AndroidMidiDeviceInfo

data class MidiDeviceInfo(val id: Int, val name: String, val manufacturer: String)

data class MidiNoteOn(val note: Int, val velocity: Int, val channel: Int)

class MidiInputService(private val context: Context) {

    private val _devices = MutableStateFlow<List<MidiDeviceInfo>>(emptyList())
    val connectedDevices: StateFlow<List<MidiDeviceInfo>> = _devices

    private val _noteOn = MutableSharedFlow<MidiNoteOn>(extraBufferCapacity = 128)
    val noteOn: SharedFlow<MidiNoteOn> = _noteOn

    private val _noteOff = MutableSharedFlow<Int>(extraBufferCapacity = 128)
    val noteOff: SharedFlow<Int> = _noteOff

    private val _sustain = MutableSharedFlow<Boolean>(extraBufferCapacity = 16)
    val sustainPedal: SharedFlow<Boolean> = _sustain

    /** Whether the service is following the keyboards. */
    var isListening: Boolean = false
        private set

    /** Null on devices without MIDI support (the manifest marks the feature as not required). */
    private val manager: MidiManager? by lazy {
        if (context.packageManager.hasSystemFeature(PackageManager.FEATURE_MIDI)) {
            context.getSystemService(MidiManager::class.java)
        } else {
            null
        }
    }

    // Callbacks (device opened, plugged, removed) arrive on the main thread; the bytes arrive on MIDI threads
    private val mainHandler = Handler(Looper.getMainLooper())

    /** An opened keyboard and the ports it sends on. Only touched on the main thread. */
    private class OpenDevice(val device: MidiDevice, val ports: List<MidiOutputPort>)

    private val openDevices = mutableMapOf<Int, OpenDevice>()
    /** Devices being opened (openDevice is asynchronous), so a device is not opened twice. */
    private val opening = mutableSetOf<Int>()
    /** Paired Bluetooth keyboards this service connected to. */
    private val bluetoothConnections = mutableListOf<MidiDevice>()

    private val deviceCallback = object : MidiManager.DeviceCallback() {
        override fun onDeviceAdded(device: AndroidMidiDeviceInfo) {
            Log.i(TAG, "MIDI device added")
            open(device)
            refreshDeviceList()
        }

        override fun onDeviceRemoved(device: AndroidMidiDeviceInfo) {
            Log.i(TAG, "MIDI device removed")
            close(device.id)
            bluetoothConnections.removeAll { connection ->
                (connection.info.id == device.id).also { gone -> if (gone) runCatching { connection.close() } }
            }
            refreshDeviceList()
        }
    }

    /** Opens every connected keyboard and watches for keyboards plugged in or removed. */
    fun startListening() {
        if (isListening) return
        val manager = manager ?: return
        isListening = true
        registerCallback(manager)
        knownDevices(manager).forEach(::open)
        openBondedBluetoothKeyboards(manager)
        refreshDeviceList()
        Log.i(TAG, "MIDI service started listening")
    }

    fun stopListening() {
        if (!isListening) return
        isListening = false
        manager?.unregisterDeviceCallback(deviceCallback)
        openDevices.keys.toList().forEach(::close)
        bluetoothConnections.forEach { runCatching { it.close() } }
        bluetoothConnections.clear()
        opening.clear()
        _devices.value = emptyList()
        Log.i(TAG, "MIDI service stopped listening")
    }

    // MARK: - Devices

    /** The keyboards that can send to the app (at least one output port), as the list shows them. */
    private fun refreshDeviceList() {
        val manager = manager ?: return
        _devices.value = knownDevices(manager).filter { it.outputPortCount > 0 }.map { info ->
            val properties = info.properties
            MidiDeviceInfo(
                id = info.id,
                name = properties.getString(AndroidMidiDeviceInfo.PROPERTY_NAME)
                    ?: context.getString(R.string.practice_midi_unknown_device),
                manufacturer = properties.getString(AndroidMidiDeviceInfo.PROPERTY_MANUFACTURER)
                    ?: context.getString(R.string.practice_midi_unknown_manufacturer),
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun knownDevices(manager: MidiManager): List<AndroidMidiDeviceInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM).toList()
        } else {
            manager.devices.toList()
        }

    @Suppress("DEPRECATION")
    private fun registerCallback(manager: MidiManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.registerDeviceCallback(
                MidiManager.TRANSPORT_MIDI_BYTE_STREAM, { command -> mainHandler.post(command) }, deviceCallback,
            )
        } else {
            manager.registerDeviceCallback(deviceCallback, mainHandler)
        }
    }

    private fun open(info: AndroidMidiDeviceInfo) {
        val manager = manager ?: return
        if (!isListening || info.outputPortCount == 0 || info.id in openDevices || !opening.add(info.id)) return
        manager.openDevice(info, { device -> opened(info.id, device) }, mainHandler)
    }

    private fun opened(id: Int, device: MidiDevice?) {
        opening.remove(id)
        if (device == null) {
            Log.w(TAG, "Failed to open MIDI device $id")
            return
        }
        // Stopped, or removed, while it was opening
        if (!isListening || id in openDevices) {
            device.close()
            return
        }
        openDevices[id] = OpenDevice(device, connectPorts(device))
    }

    /** Connects a receiver, with its own parser, to each port the keyboard sends on. */
    private fun connectPorts(device: MidiDevice): List<MidiOutputPort> =
        (0 until device.info.outputPortCount).mapNotNull { index ->
            device.openOutputPort(index)?.also { port -> port.connect(PortReceiver()) }
                ?: run { Log.w(TAG, "Failed to open MIDI port $index"); null }
        }

    private fun close(id: Int) {
        val open = openDevices.remove(id) ?: return
        open.ports.forEach { port -> runCatching { port.close() } }
        runCatching { open.device.close() }
    }

    /**
     * Bluetooth MIDI keyboards paired with the phone are only listed by the system once something connects to them.
     * This connects to the paired ones that advertise the BLE MIDI service, when the app may use Bluetooth
     * (BLUETOOTH_CONNECT on Android 12+); without the permission they still work once connected in the system.
     */
    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun openBondedBluetoothKeyboards(manager: MidiManager) {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Manifest.permission.BLUETOOTH_CONNECT else Manifest.permission.BLUETOOTH
        if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) return
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter ?: return
        val bonded = runCatching { adapter.bondedDevices }.getOrNull() ?: return
        val alreadyOpen = knownDevices(manager).mapNotNull {
            it.properties.getParcelable<android.bluetooth.BluetoothDevice>(AndroidMidiDeviceInfo.PROPERTY_BLUETOOTH_DEVICE)?.address
        }.toSet()
        bonded.filter { device -> device.address !in alreadyOpen && device.uuids.orEmpty().any { it == BLE_MIDI_SERVICE } }
            .forEach { device ->
                manager.openBluetoothDevice(device, { midi ->
                    // This handle only keeps the Bluetooth connection up; the system now lists the keyboard and it is
                    // opened like any other (open() skips it if DeviceCallback already did)
                    if (midi == null) return@openBluetoothDevice
                    if (!isListening) { midi.close(); return@openBluetoothDevice }
                    bluetoothConnections += midi
                    open(midi.info)
                    refreshDeviceList()
                }, mainHandler)
            }
    }

    // MARK: - Messages

    /** Receives one port's bytes (on a MIDI thread) and emits the notes and the pedal. */
    private inner class PortReceiver : MidiReceiver() {
        private val parser = MidiStreamParser()

        override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
            for (message in parser.parse(msg, offset, count)) dispatch(message)
        }
    }

    private fun dispatch(message: MidiMessage) {
        // The flows are thread-safe and buffered; collectors run on their own dispatcher (the screens' main thread)
        when (message) {
            is MidiMessage.NoteOn -> _noteOn.tryEmit(MidiNoteOn(message.note, message.velocity, message.channel))
            is MidiMessage.NoteOff -> _noteOff.tryEmit(message.note)
            is MidiMessage.ControlChange -> if (message.isSustain) _sustain.tryEmit(message.isPressed)
        }
    }

    private companion object {
        const val TAG = "MidiInputService"
        /** The Bluetooth LE MIDI service. */
        val BLE_MIDI_SERVICE: ParcelUuid = ParcelUuid.fromString("03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    }
}
