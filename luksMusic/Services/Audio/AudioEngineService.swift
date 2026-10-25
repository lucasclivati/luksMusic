// AudioEngineService.swift
// luksMusic
//
// Singleton service managing AVAudioEngine for piano sound playback.
// Uses AVAudioUnitSampler with SoundFont (.sf2) files for realistic piano sounds.

import AVFoundation
import Observation
import os.log

// MARK: - AudioEngineError

/// Errors that can occur during audio engine operations.
enum AudioEngineError: LocalizedError {
    case engineNotRunning
    case soundFontNotFound(name: String)
    case soundFontLoadFailed(name: String, underlying: Error)
    case audioSessionSetupFailed(underlying: Error)
    case engineStartFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .engineNotRunning:
            return "Audio engine is not running."
        case .soundFontNotFound(let name):
            return "SoundFont file '\(name).sf2' not found in bundle."
        case .soundFontLoadFailed(let name, let underlying):
            return "Failed to load SoundFont '\(name)': \(underlying.localizedDescription)"
        case .audioSessionSetupFailed(let underlying):
            return "Audio session setup failed: \(underlying.localizedDescription)"
        case .engineStartFailed(let underlying):
            return "Audio engine failed to start: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - AudioEngineService

/// A singleton service that manages `AVAudioEngine` for piano sound playback.
///
/// This service provides:
/// - SoundFont-based piano sound via `AVAudioUnitSampler`
/// - Reverb effect via `AVAudioUnitReverb`
/// - Audio session management (interruptions, route changes)
/// - Volume control
///
/// ## Usage
/// ```swift
/// let engine = AudioEngineService.shared
/// engine.setupEngine()
/// engine.loadSoundFont(name: "Piano")
/// engine.playNote(midiNote: 60) // Middle C
/// ```
@Observable
final class AudioEngineService {
    
    // MARK: - Singleton
    
    /// Shared singleton instance.
    static let shared = AudioEngineService()
    
    // MARK: - Published Properties
    
    /// Whether a note is currently being played.
    private(set) var isPlaying: Bool = false
    
    /// Master volume level (0.0 to 1.0).
    var volume: Float = 0.8 {
        didSet {
            let clamped = volume.clamped(to: 0.0...1.0)
            if volume != clamped { volume = clamped }
            engine.mainMixerNode.outputVolume = clamped
        }
    }
    
    /// Whether the audio engine is currently running.
    private(set) var isEngineRunning: Bool = false
    
    /// The most recent error encountered, if any.
    private(set) var lastError: AudioEngineError?
    
    // MARK: - Private Properties
    
    /// The core audio engine.
    private let engine = AVAudioEngine()
    
    /// Sampler unit for SoundFont playback.
    private let sampler = AVAudioUnitSampler()
    
    /// Reverb effect unit.
    private let reverb = AVAudioUnitReverb()
    
    /// Logger for structured logging.
    private let logger = Logger(subsystem: "com.luksMusic.audio", category: "AudioEngine")
    
    /// Tracks the number of active notes for `isPlaying` state.
    private var activeNoteCount: Int = 0
    
    /// Whether the SoundFont has been loaded.
    private var isSoundFontLoaded: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        registerForNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        engine.stop()
    }
    
    // MARK: - Engine Setup
    
    /// Initializes the audio session, attaches nodes, connects the signal chain, and starts the engine.
    ///
    /// The signal chain is: `Sampler → Reverb → MainMixer → Output`.
    ///
    /// - Throws: `AudioEngineError` if setup or engine start fails.
    func setupEngine() {
        do {
            try configureAudioSession()
        } catch {
            let audioError = AudioEngineError.audioSessionSetupFailed(underlying: error)
            lastError = audioError
            logger.error("Audio session setup failed: \(error.localizedDescription)")
            return
        }
        
        // Attach nodes to the engine
        engine.attach(sampler)
        engine.attach(reverb)
        
        // Configure reverb with a reasonable default
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 20.0
        
        // Connect: Sampler → Reverb → MainMixer → Output
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(sampler, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        
        // Set initial volume
        engine.mainMixerNode.outputVolume = volume
        
        // Prepare and start
        engine.prepare()
        
        do {
            try engine.start()
            isEngineRunning = true
            logger.info("Audio engine started successfully.")
        } catch {
            let audioError = AudioEngineError.engineStartFailed(underlying: error)
            lastError = audioError
            isEngineRunning = false
            logger.error("Audio engine failed to start: \(error.localizedDescription)")
        }
    }
    
    // MARK: - SoundFont Loading
    
    /// Loads a SoundFont (.sf2) file for realistic piano sounds.
    ///
    /// - Parameter name: The name of the `.sf2` file in the app bundle (without extension).
    func loadSoundFont(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "sf2") else {
            let error = AudioEngineError.soundFontNotFound(name: name)
            lastError = error
            logger.error("SoundFont '\(name).sf2' not found in bundle.")
            return
        }
        
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: 0,       // Acoustic Grand Piano (General MIDI program 0)
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            isSoundFontLoaded = true
            logger.info("SoundFont '\(name)' loaded successfully.")
        } catch {
            let audioError = AudioEngineError.soundFontLoadFailed(name: name, underlying: error)
            lastError = audioError
            isSoundFontLoaded = false
            logger.error("Failed to load SoundFont '\(name)': \(error.localizedDescription)")
        }
    }
    
    // MARK: - Note Playback
    
    /// Starts playing a MIDI note.
    ///
    /// - Parameters:
    ///   - midiNote: The MIDI note number (0–127). Middle C is 60.
    ///   - velocity: The note velocity (0–127). Default is 80.
    func playNote(midiNote: UInt8, velocity: UInt8 = 80) {
        guard isEngineRunning else {
            logger.warning("Cannot play note: engine is not running.")
            return
        }
        
        sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
        activeNoteCount += 1
        isPlaying = true
    }
    
    /// Stops a currently playing MIDI note.
    ///
    /// - Parameter midiNote: The MIDI note number to stop (0–127).
    func stopNote(midiNote: UInt8) {
        sampler.stopNote(midiNote, onChannel: 0)
        activeNoteCount = max(0, activeNoteCount - 1)
        if activeNoteCount == 0 {
            isPlaying = false
        }
    }
    
    /// Stops all currently playing notes (MIDI panic).
    func stopAllNotes() {
        for note: UInt8 in 0...127 {
            sampler.stopNote(note, onChannel: 0)
        }
        activeNoteCount = 0
        isPlaying = false
    }
    
    // MARK: - Volume Control
    
    /// Sets the master volume of the audio engine.
    ///
    /// - Parameter volume: The volume level, clamped to 0.0–1.0.
    func setVolume(_ volume: Float) {
        self.volume = volume
    }
    
    // MARK: - Reverb Control
    
    /// Sets the reverb wet/dry mix amount.
    ///
    /// - Parameter amount: The reverb amount from 0.0 (fully dry) to 1.0 (fully wet).
    func setReverb(_ amount: Float) {
        let clamped = amount.clamped(to: 0.0...1.0)
        reverb.wetDryMix = clamped * 100.0 // AVAudioUnitReverb uses 0–100 scale
        logger.debug("Reverb set to \(clamped * 100.0)%.")
    }
    
    // MARK: - Engine Lifecycle
    
    /// Stops the audio engine.
    func stopEngine() {
        engine.stop()
        isEngineRunning = false
        isPlaying = false
        activeNoteCount = 0
        logger.info("Audio engine stopped.")
    }
    
    /// Restarts the audio engine after it was stopped.
    func restartEngine() {
        guard !isEngineRunning else { return }
        
        do {
            try engine.start()
            isEngineRunning = true
            logger.info("Audio engine restarted successfully.")
        } catch {
            let audioError = AudioEngineError.engineStartFailed(underlying: error)
            lastError = audioError
            logger.error("Audio engine restart failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Audio Session Configuration
    
    /// Configures the `AVAudioSession` for playback.
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        logger.info("Audio session configured for playback.")
    }
    
    // MARK: - Notification Handling
    
    /// Registers for audio session interruption and route change notifications.
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    /// Handles audio session interruptions (e.g., incoming phone calls).
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            logger.info("Audio session interruption began.")
            stopAllNotes()
            isEngineRunning = false
            
        case .ended:
            logger.info("Audio session interruption ended.")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    restartEngine()
                }
            }
            
        @unknown default:
            logger.warning("Unknown audio session interruption type.")
        }
    }
    
    /// Handles audio route changes (e.g., headphones plugged/unplugged).
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged — stop playback to avoid unexpected speaker output
            logger.info("Audio route changed: old device unavailable (headphones unplugged).")
            stopAllNotes()
            
        case .newDeviceAvailable:
            logger.info("Audio route changed: new device available (headphones plugged in).")
            
        default:
            logger.debug("Audio route changed: reason \(reasonValue).")
        }
    }
}

// MARK: - Float Clamping Extension

private extension Float {
    /// Clamps the value to the given closed range.
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
