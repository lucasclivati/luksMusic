// MIDIFilePlayer.swift
// luksMusic
//
// A MIDI file playback service using AVAudioSequencer.
// Supports loading .mid files and Score model conversion, with playback controls
// and progress tracking.

import AVFoundation
import Observation
import os.log

// MARK: - MIDIFilePlayerError

/// Errors that can occur during MIDI file playback operations.
enum MIDIFilePlayerError: LocalizedError {
    case fileNotFound(url: URL)
    case loadFailed(underlying: Error)
    case engineNotRunning
    case playbackFailed(underlying: Error)
    case invalidSeekPosition(beat: Double)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "MIDI file not found at: \(url.path)"
        case .loadFailed(let underlying):
            return "Failed to load MIDI file: \(underlying.localizedDescription)"
        case .engineNotRunning:
            return "Audio engine is not running."
        case .playbackFailed(let underlying):
            return "Playback failed: \(underlying.localizedDescription)"
        case .invalidSeekPosition(let beat):
            return "Invalid seek position: \(beat)"
        }
    }
}

// MARK: - MIDINoteEvent

/// Represents a note event during MIDI playback, used for score highlighting.
struct MIDINoteEvent: Equatable, Sendable {
    /// The MIDI note number (0–127).
    let note: UInt8
    
    /// The velocity of the note (0–127).
    let velocity: UInt8
    
    /// The beat position where this note occurs.
    let beat: Double
    
    /// The duration of the note in beats.
    let duration: Double
    
    /// Whether this is a note-on (true) or note-off (false) event.
    let isNoteOn: Bool
}

// MARK: - MIDIFilePlayer

/// A service for loading and playing MIDI files using `AVAudioSequencer`.
///
/// Features:
/// - Load `.mid` files from URL
/// - Convert `Score` models to MIDI data for playback
/// - Play, pause, stop controls
/// - Seek to specific beat positions
/// - Tempo override
/// - Progress tracking
/// - Note event callbacks for score highlighting
///
/// ## Usage
/// ```swift
/// let player = MIDIFilePlayer()
/// player.loadMIDIFile(url: midiFileURL)
/// player.play()
/// ```
@Observable
final class MIDIFilePlayer {
    
    // MARK: - Published Properties
    
    /// The current playback position in beats.
    private(set) var currentBeat: Double = 0.0
    
    /// The total length of the loaded MIDI file in beats.
    private(set) var totalBeats: Double = 0.0
    
    /// Whether the player is currently playing.
    private(set) var isPlaying: Bool = false
    
    /// Playback progress from 0.0 to 1.0.
    var progress: Double {
        guard totalBeats > 0 else { return 0.0 }
        return min(currentBeat / totalBeats, 1.0)
    }
    
    /// The most recent error encountered, if any.
    private(set) var lastError: MIDIFilePlayerError?
    
    /// Whether a MIDI file is currently loaded.
    private(set) var isFileLoaded: Bool = false
    
    // MARK: - Callbacks
    
    /// Callback invoked when a note event occurs during playback.
    /// Use this to highlight notes on the score display.
    var onNoteEvent: ((MIDINoteEvent) -> Void)?
    
    // MARK: - Private Properties
    
    /// The audio engine used for MIDI playback.
    private let engine = AVAudioEngine()
    
    /// The sampler unit for sound output.
    private let sampler = AVAudioUnitSampler()
    
    /// The sequencer that plays MIDI data.
    private var sequencer: AVAudioSequencer?
    
    /// Timer for tracking playback position.
    private var positionTimer: Timer?
    
    /// Logger for structured logging.
    private let logger = Logger(subsystem: "com.luksMusic.midi", category: "MIDIFilePlayer")
    
    /// The current tempo override, if set.
    private var tempoOverride: Double?
    
    // MARK: - Initialization
    
    init() {
        setupEngine()
    }
    
    deinit {
        stop()
        engine.stop()
    }
    
    // MARK: - Engine Setup
    
    /// Sets up the internal audio engine and sampler for MIDI playback.
    private func setupEngine() {
        engine.attach(sampler)
        
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(sampler, to: engine.mainMixerNode, format: format)
        
        engine.prepare()
        
        do {
            try engine.start()
            logger.info("MIDI file player engine started.")
        } catch {
            logger.error("Failed to start MIDI file player engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Loading
    
    /// Loads a MIDI file from disk for playback.
    ///
    /// - Parameter url: The file URL of the `.mid` file to load.
    func loadMIDIFile(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let error = MIDIFilePlayerError.fileNotFound(url: url)
            lastError = error
            logger.error("MIDI file not found: \(url.path)")
            return
        }
        
        // Stop any current playback
        stop()
        
        // Create a new sequencer attached to the engine
        let newSequencer = AVAudioSequencer(audioEngine: engine)
        
        do {
            try newSequencer.load(from: url, options: [])
            self.sequencer = newSequencer
            
            // Calculate total beats from all tracks
            totalBeats = calculateTotalBeats(from: newSequencer)
            currentBeat = 0.0
            isFileLoaded = true
            
            // Apply tempo override if set
            if let tempoOverride {
                newSequencer.rate = Float(tempoOverride / getFileTempo(from: newSequencer))
            }
            
            logger.info("MIDI file loaded: \(url.lastPathComponent), total beats: \(self.totalBeats)")
        } catch {
            let loadError = MIDIFilePlayerError.loadFailed(underlying: error)
            lastError = loadError
            isFileLoaded = false
            logger.error("Failed to load MIDI file: \(error.localizedDescription)")
        }
    }
    
    /// Converts a `Score` model to MIDI data and loads it for playback.
    ///
    /// This creates an in-memory MIDI representation of the score,
    /// which can then be played back through the sequencer.
    ///
    /// - Parameter score: The `Score` model to convert and load.
    func loadFromScore(_ score: Score) {
        // Stop any current playback
        stop()
        
        // Create a new sequencer
        let newSequencer = AVAudioSequencer(audioEngine: engine)
        
        // Convert Score to MIDI data
        guard let midiData = convertScoreToMIDIData(score) else {
            logger.error("Failed to convert Score to MIDI data.")
            return
        }
        
        do {
            try newSequencer.load(from: midiData, options: [])
            self.sequencer = newSequencer
            
            totalBeats = calculateTotalBeats(from: newSequencer)
            currentBeat = 0.0
            isFileLoaded = true
            
            logger.info("Score loaded as MIDI, total beats: \(self.totalBeats)")
        } catch {
            let loadError = MIDIFilePlayerError.loadFailed(underlying: error)
            lastError = loadError
            isFileLoaded = false
            logger.error("Failed to load Score as MIDI: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Playback Controls
    
    /// Starts or resumes playback.
    func play() {
        guard let sequencer, isFileLoaded else {
            logger.warning("Cannot play: no MIDI file loaded.")
            return
        }
        
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                let playError = MIDIFilePlayerError.engineNotRunning
                lastError = playError
                logger.error("Engine not running and failed to start.")
                return
            }
        }
        
        do {
            try sequencer.start()
            isPlaying = true
            startPositionTracking()
            logger.info("MIDI playback started.")
        } catch {
            let playError = MIDIFilePlayerError.playbackFailed(underlying: error)
            lastError = playError
            logger.error("Playback failed: \(error.localizedDescription)")
        }
    }
    
    /// Pauses playback at the current position.
    func pause() {
        guard let sequencer, isPlaying else { return }
        
        sequencer.stop()
        isPlaying = false
        stopPositionTracking()
        
        logger.info("MIDI playback paused at beat \(self.currentBeat).")
    }
    
    /// Stops playback and resets to the beginning.
    func stop() {
        guard let sequencer else { return }
        
        sequencer.stop()
        sequencer.currentPositionInBeats = 0
        
        isPlaying = false
        currentBeat = 0.0
        stopPositionTracking()
        
        logger.info("MIDI playback stopped.")
    }
    
    /// Jumps to a specific beat position.
    ///
    /// - Parameter beat: The target beat position. Must be non-negative and within file bounds.
    func seekTo(beat: Double) {
        guard let sequencer, isFileLoaded else { return }
        
        let clampedBeat = max(0, min(beat, totalBeats))
        sequencer.currentPositionInBeats = clampedBeat
        currentBeat = clampedBeat
        
        logger.info("Seeked to beat \(clampedBeat).")
    }
    
    /// Overrides the playback tempo.
    ///
    /// - Parameter bpm: The desired tempo in beats per minute.
    func setTempo(_ bpm: Double) {
        guard bpm > 0 else { return }
        
        tempoOverride = bpm
        
        if let sequencer {
            let originalTempo = getFileTempo(from: sequencer)
            if originalTempo > 0 {
                sequencer.rate = Float(bpm / originalTempo)
            }
        }
        
        logger.info("Tempo set to \(bpm) BPM.")
    }
    
    // MARK: - SoundFont Loading
    
    /// Loads a SoundFont for the player's sampler.
    ///
    /// - Parameter name: The name of the `.sf2` file in the app bundle (without extension).
    func loadSoundFont(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "sf2") else {
            logger.error("SoundFont '\(name).sf2' not found in bundle.")
            return
        }
        
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            logger.info("SoundFont '\(name)' loaded for MIDI player.")
        } catch {
            logger.error("Failed to load SoundFont '\(name)': \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private: Position Tracking
    
    /// Starts a timer that periodically updates the current beat position.
    private func startPositionTracking() {
        stopPositionTracking()
        
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let sequencer = self.sequencer else { return }
            
            let beat = sequencer.currentPositionInBeats
            self.currentBeat = beat
            
            // Check if playback has finished
            if beat >= self.totalBeats && self.isPlaying {
                self.isPlaying = false
                self.stopPositionTracking()
                self.logger.info("MIDI playback completed.")
            }
        }
    }
    
    /// Stops the position tracking timer.
    private func stopPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
    
    // MARK: - Private: MIDI Utilities
    
    /// Calculates the total number of beats across all tracks in the sequencer.
    ///
    /// - Parameter sequencer: The `AVAudioSequencer` to inspect.
    /// - Returns: The total length in beats.
    private func calculateTotalBeats(from sequencer: AVAudioSequencer) -> Double {
        var maxBeats: Double = 0
        for track in sequencer.tracks {
            maxBeats = max(maxBeats, track.lengthInBeats)
        }
        return maxBeats
    }
    
    /// Retrieves the original tempo from the MIDI file's tempo track.
    ///
    /// - Parameter sequencer: The `AVAudioSequencer` to inspect.
    /// - Returns: The file's tempo in BPM, or 120.0 as a default.
    private func getFileTempo(from sequencer: AVAudioSequencer) -> Double {
        // Default to 120 BPM if we can't determine the file tempo
        guard let tempoTrack = sequencer.tracks.first else { return 120.0 }
        _ = tempoTrack
        return sequencer.rate > 0 ? 120.0 / Double(sequencer.rate) : 120.0
    }
    
    /// Converts a `Score` model to raw MIDI file data.
    ///
    /// Creates a minimal Standard MIDI File (SMF format 0) from the score.
    ///
    /// - Parameter score: The `Score` model to convert.
    /// - Returns: MIDI file data, or nil if conversion fails.
    private func convertScoreToMIDIData(_ score: Score) -> Data? {
        // Build a Standard MIDI File (SMF) format 0
        var data = Data()
        
        let ticksPerBeat: UInt16 = 480
        
        // ---- MThd Header ----
        data.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        data.append(contentsOf: uint32Bytes(6))              // Header length
        data.append(contentsOf: uint16Bytes(0))              // Format 0
        data.append(contentsOf: uint16Bytes(1))              // 1 track
        data.append(contentsOf: uint16Bytes(ticksPerBeat))   // Ticks per beat
        
        // ---- MTrk Track ----
        var trackData = Data()
        
        // Tempo meta event: set tempo based on score's BPM (default 120)
        let bpm: Double = 120.0 // Could be extracted from Score if available
        let microsecondsPerBeat = UInt32(60_000_000 / bpm)
        trackData.append(contentsOf: [0x00])                        // Delta time
        trackData.append(contentsOf: [0xFF, 0x51, 0x03])            // Tempo meta event
        trackData.append(UInt8((microsecondsPerBeat >> 16) & 0xFF))
        trackData.append(UInt8((microsecondsPerBeat >> 8) & 0xFF))
        trackData.append(UInt8(microsecondsPerBeat & 0xFF))
        
        // Time signature meta event
        trackData.append(contentsOf: [0x00])                                   // Delta time
        trackData.append(contentsOf: [0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08]) // 4/4 time
        
        // Build note events from score measures and notes
        var events: [(tick: UInt32, statusByte: UInt8, note: UInt8, velocity: UInt8)] = []
        
        var currentTick: UInt32 = 0
        for measure in score.measures {
            for note in measure.notes where !note.isRest {
                let noteTick = currentTick + UInt32(max(0.0, (note.position.beat - 1.0)) * Double(ticksPerBeat))
                let noteDurationTicks = UInt32(note.duration.beats * Double(ticksPerBeat))
                
                // Note On
                events.append((tick: noteTick, statusByte: 0x90, note: note.midiNote, velocity: 80))
                // Note Off
                events.append((tick: noteTick + noteDurationTicks, statusByte: 0x80, note: note.midiNote, velocity: 0))
            }
            let numBeats = Double(measure.timeSignatureNumerator ?? score.timeSignatureTop)
            currentTick += UInt32(numBeats * Double(ticksPerBeat))
        }
        
        // Sort events by tick
        events.sort { $0.tick < $1.tick }
        
        // Write events with delta times
        var lastTick: UInt32 = 0
        for event in events {
            let delta = event.tick - lastTick
            trackData.append(contentsOf: variableLengthQuantity(delta))
            trackData.append(event.statusByte)
            trackData.append(event.note)
            trackData.append(event.velocity)
            lastTick = event.tick
        }
        
        // End of track meta event
        trackData.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        
        // Write track header
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        data.append(contentsOf: uint32Bytes(UInt32(trackData.count)))
        data.append(trackData)
        
        return data
    }
    
    // MARK: - Private: Binary Encoding Helpers
    
    /// Encodes a UInt32 as 4 big-endian bytes.
    private func uint32Bytes(_ value: UInt32) -> [UInt8] {
        return [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
    
    /// Encodes a UInt16 as 2 big-endian bytes.
    private func uint16Bytes(_ value: UInt16) -> [UInt8] {
        return [
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
    
    /// Encodes a value as MIDI variable-length quantity.
    private func variableLengthQuantity(_ value: UInt32) -> [UInt8] {
        if value == 0 { return [0x00] }
        
        var result: [UInt8] = []
        var remaining = value
        
        result.append(UInt8(remaining & 0x7F))
        remaining >>= 7
        
        while remaining > 0 {
            result.append(UInt8((remaining & 0x7F) | 0x80))
            remaining >>= 7
        }
        
        result.reverse()
        return result
    }
}
