// MIDIService.swift
// luksMusic
//
// A service for handling external MIDI keyboard input using CoreMIDI.
// Provides Combine publishers for reactive MIDI event streaming.

import CoreMIDI
import Combine
import Observation
import os.log

// MARK: - MIDI Data Models

/// Information about a connected MIDI device.
struct MIDIDeviceInfo: Identifiable, Equatable, Sendable {
    /// Unique identifier for this device info entry.
    let id: MIDIObjectRef
    
    /// The display name of the MIDI device.
    let name: String
    
    /// The manufacturer of the MIDI device.
    let manufacturer: String
}

/// Represents a MIDI note-on event.
struct MIDINote: Equatable, Sendable {
    /// The MIDI note number (0–127).
    let note: UInt8
    
    /// The velocity of the note (0–127).
    let velocity: UInt8
    
    /// The MIDI channel (0–15).
    let channel: UInt8
}

/// Represents the types of MIDI messages this service handles.
enum MIDIMessageType: Equatable {
    case noteOn(note: UInt8, velocity: UInt8, channel: UInt8)
    case noteOff(note: UInt8, channel: UInt8)
    case controlChange(controller: UInt8, value: UInt8, channel: UInt8)
}

// MARK: - Key Input

/// Delivers a connected MIDI keyboard's keys to one screen while that screen is open.
final class MIDIKeyInput {
    private var subscriptions = Set<AnyCancellable>()

    func start(onNoteOn: @escaping (Int) -> Void, onNoteOff: @escaping (Int) -> Void) {
        subscriptions.removeAll()
        MIDIService.shared.noteOnPublisher.sink { onNoteOn(Int($0.note)) }.store(in: &subscriptions)
        MIDIService.shared.noteOffPublisher.sink { onNoteOff(Int($0)) }.store(in: &subscriptions)
    }
}

// MARK: - MIDIService

/// A service that manages external MIDI device connections and parses incoming MIDI data.
///
/// This service uses CoreMIDI to:
/// - Detect and connect to external MIDI devices
/// - Parse note on/off and control change messages
/// - Publish events via Combine publishers for reactive consumption
///
/// ## Usage
/// ```swift
/// let midi = MIDIService()
/// midi.startListening()
///
/// midi.noteOnPublisher
///     .sink { note in
///         print("Note on: \(note.note), velocity: \(note.velocity)")
///     }
///     .store(in: &cancellables)
/// ```
@Observable
final class MIDIService {
    
    // MARK: - Singleton
    nonisolated(unsafe) static let shared = MIDIService()
    
    // MARK: - Published Properties
    
    /// List of currently detected MIDI devices.
    private(set) var connectedDevices: [MIDIDeviceInfo] = []
    
    /// Whether any MIDI device is currently connected.
    var isDeviceConnected: Bool {
        !connectedDevices.isEmpty
    }
    
    /// Whether the service is actively listening for MIDI input.
    private(set) var isListening: Bool = false
    
    // MARK: - Combine Publishers
    
    /// Publishes MIDI note-on events.
    var noteOnPublisher: AnyPublisher<MIDINote, Never> {
        noteOnSubject.eraseToAnyPublisher()
    }
    
    /// Publishes MIDI note-off events (note number only).
    var noteOffPublisher: AnyPublisher<UInt8, Never> {
        noteOffSubject.eraseToAnyPublisher()
    }
    
    /// Publishes sustain pedal state changes (true = pressed, false = released).
    var sustainPedalPublisher: AnyPublisher<Bool, Never> {
        sustainPedalSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    /// The CoreMIDI client reference.
    private var midiClient: MIDIClientRef = 0
    
    /// The CoreMIDI input port reference.
    private var inputPort: MIDIPortRef = 0
    
    /// Subject for note-on events.
    private let noteOnSubject = PassthroughSubject<MIDINote, Never>()
    
    /// Subject for note-off events.
    private let noteOffSubject = PassthroughSubject<UInt8, Never>()
    
    /// Subject for sustain pedal events.
    private let sustainPedalSubject = PassthroughSubject<Bool, Never>()
    
    /// Logger for structured logging.
    private let logger = Logger(subsystem: "com.luksMusic.midi", category: "MIDIService")
    
    /// MIDI CC number for the sustain pedal.
    private static let sustainPedalCC: UInt8 = 64
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        stopListening()
    }
    
    // MARK: - Public Methods
    
    /// Starts listening for MIDI input from all available sources.
    ///
    /// Creates a CoreMIDI client and input port, then connects to all available MIDI sources.
    func startListening() {
        guard !isListening else {
            logger.info("MIDI service is already listening.")
            return
        }
        
        // Create MIDI client
        let clientStatus = MIDIClientCreateWithBlock("luksMusic.MIDIClient" as CFString, &midiClient) { [weak self] notificationPointer in
            self?.handleMIDINotification(notificationPointer)
        }
        
        guard clientStatus == noErr else {
            logger.error("Failed to create MIDI client: \(clientStatus)")
            return
        }
        
        // Create input port
        let portStatus = MIDIInputPortCreateWithProtocol(
            midiClient,
            "luksMusic.InputPort" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleMIDIEventList(eventList)
        }
        
        guard portStatus == noErr else {
            logger.error("Failed to create MIDI input port: \(portStatus)")
            MIDIClientDispose(midiClient)
            return
        }
        
        // Connect to all available sources
        connectToAllSources()
        
        // Scan for devices
        refreshDeviceList()
        
        isListening = true
        logger.info("MIDI service started listening.")
    }
    
    /// Stops listening for MIDI input and disposes CoreMIDI resources.
    func stopListening() {
        guard isListening else { return }
        
        // Disconnect from all sources
        disconnectFromAllSources()
        
        // Dispose CoreMIDI objects
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }
        
        connectedDevices = []
        isListening = false
        logger.info("MIDI service stopped listening.")
    }
    
    // MARK: - Device Management
    
    /// Refreshes the list of available MIDI devices.
    func refreshDeviceList() {
        var devices: [MIDIDeviceInfo] = []
        
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            let name = getMIDIStringProperty(source, property: kMIDIPropertyDisplayName) ?? "Unknown Device"
            let manufacturer = getMIDIStringProperty(source, property: kMIDIPropertyManufacturer) ?? "Unknown"
            
            devices.append(MIDIDeviceInfo(
                id: source,
                name: name,
                manufacturer: manufacturer
            ))
        }
        
        connectedDevices = devices
        logger.info("Found \(devices.count) MIDI source(s).")
    }
    
    // MARK: - Private: MIDI Connection
    
    /// Connects the input port to all available MIDI sources.
    private func connectToAllSources() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            let status = MIDIPortConnectSource(inputPort, source, nil)
            if status != noErr {
                logger.warning("Failed to connect to MIDI source \(i): \(status)")
            }
        }
    }
    
    /// Disconnects the input port from all MIDI sources.
    private func disconnectFromAllSources() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortDisconnectSource(inputPort, source)
        }
    }
    
    // MARK: - Private: MIDI Notification Handling
    
    /// Handles CoreMIDI system notifications (device added/removed, etc.).
    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let messageID = notification.pointee.messageID
        
        switch messageID {
        case .msgSetupChanged:
            logger.info("MIDI setup changed.")
            DispatchQueue.main.async { [weak self] in
                self?.refreshDeviceList()
                self?.connectToAllSources()
            }
            
        case .msgObjectAdded:
            logger.info("MIDI object added.")
            DispatchQueue.main.async { [weak self] in
                self?.refreshDeviceList()
                self?.connectToAllSources()
            }
            
        case .msgObjectRemoved:
            logger.info("MIDI object removed.")
            DispatchQueue.main.async { [weak self] in
                self?.refreshDeviceList()
            }
            
        default:
            break
        }
    }
    
    // MARK: - Private: MIDI Message Parsing
    
    /// Handles incoming MIDI event lists (MIDI 1.0 messages inside Universal MIDI Packets).
    private func handleMIDIEventList(_ eventListPointer: UnsafePointer<MIDIEventList>) {
        let packetCount = eventListPointer.pointee.numPackets
        guard packetCount > 0,
              let packetOffset = MemoryLayout<MIDIEventList>.offset(of: \.packet),
              let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \.words) else { return }

        var packet = (UnsafeRawPointer(eventListPointer) + packetOffset).assumingMemoryBound(to: MIDIEventPacket.self)
        for index in 0..<packetCount {
            // Only the packet's own words are valid; the rest of its fixed-size array is undefined
            let words = UnsafeBufferPointer(
                start: (UnsafeRawPointer(packet) + wordsOffset).assumingMemoryBound(to: UInt32.self),
                count: Int(packet.pointee.wordCount)
            )
            for message in Self.messages(in: Array(words)) {
                dispatchMIDIMessage(message)
            }
            if index + 1 < packetCount {
                packet = UnsafePointer(MIDIEventPacketNext(packet))
            }
        }
    }

    /// The note and controller messages among Universal MIDI Packet words.
    static func messages(in words: [UInt32]) -> [MIDIMessageType] {
        var messages: [MIDIMessageType] = []
        var index = 0
        while index < words.count {
            let word = words[index]
            // Bits 31-28: message type; 0x2 is a MIDI 1.0 channel voice message
            let messageType = (word >> 28) & 0x0F
            if messageType == 0x2 {
                let status = UInt8((word >> 20) & 0x0F)
                let channel = UInt8((word >> 16) & 0x0F)
                let data1 = UInt8((word >> 8) & 0xFF)
                let data2 = UInt8(word & 0xFF)
                if let message = parseMIDIStatus(status: status, channel: channel, data1: data1, data2: data2) {
                    messages.append(message)
                }
            }
            // Longer message types take more than one word
            switch messageType {
            case 0x3, 0x4: index += 2
            case 0x5: index += 4
            default: index += 1
            }
        }
        return messages
    }

    /// Parses a MIDI status nibble into a typed message.
    private static func parseMIDIStatus(status: UInt8, channel: UInt8, data1: UInt8, data2: UInt8) -> MIDIMessageType? {
        switch status {
        case 0x9: // Note On
            // Note On with velocity 0 is equivalent to Note Off
            return data2 == 0 ? .noteOff(note: data1, channel: channel) : .noteOn(note: data1, velocity: data2, channel: channel)
        case 0x8: // Note Off
            return .noteOff(note: data1, channel: channel)
        case 0xB: // Control Change
            return .controlChange(controller: data1, value: data2, channel: channel)
        default:
            return nil
        }
    }

    /// Dispatches a parsed MIDI message to the appropriate Combine subject.
    private func dispatchMIDIMessage(_ message: MIDIMessageType) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            switch message {
            case .noteOn(let note, let velocity, let channel):
                let midiNote = MIDINote(note: note, velocity: velocity, channel: channel)
                self.noteOnSubject.send(midiNote)
                self.logger.debug("Note On: \(note), vel: \(velocity), ch: \(channel)")
                
            case .noteOff(let note, _):
                self.noteOffSubject.send(note)
                self.logger.debug("Note Off: \(note)")
                
            case .controlChange(let controller, let value, _):
                if controller == Self.sustainPedalCC {
                    let isPressed = value >= 64
                    self.sustainPedalSubject.send(isPressed)
                    self.logger.debug("Sustain pedal: \(isPressed ? "pressed" : "released")")
                }
            }
        }
    }
    
    // MARK: - Private: Utility
    
    /// Retrieves a string property from a MIDI object.
    ///
    /// - Parameters:
    ///   - ref: The MIDI object reference.
    ///   - property: The property key to query.
    /// - Returns: The property value as a String, or nil if unavailable.
    private func getMIDIStringProperty(_ ref: MIDIObjectRef, property: CFString) -> String? {
        var unmanagedString: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(ref, property, &unmanagedString)
        guard status == noErr, let cfString = unmanagedString?.takeRetainedValue() else {
            return nil
        }
        return cfString as String
    }
}
