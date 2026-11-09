// MicrophonePitchService.swift
// luksMusic
//
// Real-time acoustic note detection using AVAudioEngine; the analysis itself is in PitchDetection.swift.
// Listens to acoustic or digital pianos via device microphone to verify notes played in real life.

import Foundation
import AVFoundation
import Observation
import os.log

@Observable
final class MicrophonePitchService: @unchecked Sendable {
    
    // MARK: - Singleton
    
    nonisolated(unsafe) static let shared = MicrophonePitchService()
    
    // MARK: - Published State
    
    var isListening: Bool = false
    var hasPermission: Bool = false
    var detectedMidiNote: Int? = nil
    var detectedNoteName: String = "--"
    var detectedFrequency: Double = 0.0
    var inputLevel: Float = 0.0
    var errorMessage: String? = nil
    
    // Callback when a new distinct piano note is identified
    var onNoteDetected: ((Int) -> Void)?

    // Called when a chord was struck but some of its notes weren't heard
    var onChordMissed: (() -> Void)?
    
    // MARK: - Audio Properties
    
    private let audioEngine = AVAudioEngine()
    private let logger = Logger(subsystem: "com.luksMusic.audio", category: "MicrophonePitchService")
    private let bufferSize: AVAudioFrameCount = 2048
    
    // Only touched on the audio tap's queue, or before the tap is installed
    private var reader = MicrophoneNoteReader(sampleRate: 44100)
    
    // Time until which the microphone is deaf, while the app itself is making sound
    private let deafLock = NSLock()
    private var deafUntil: Date = .distantPast
    private var expectedChord: Set<Int>?
    
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    private init() {}
    
    // MARK: - Permissions
    
    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                self.hasPermission = granted
            }
            return granted
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        self.hasPermission = granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    // MARK: - Listening Lifecycle
    
    func startListening() async throws {
        guard !isListening else { return }
        
        let granted = await requestPermission()
        guard granted else {
            let errorMsg = "Microphone access is required to listen to your piano."
            await MainActor.run {
                self.errorMessage = errorMsg
                self.isListening = false
            }
            throw NSError(domain: "MicrophonePitchService", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            reader = MicrophoneNoteReader(sampleRate: inputFormat.sampleRate > 0 ? inputFormat.sampleRate : 44100.0)
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            // Changing the session's category can stop the engine that plays the app's own notes
            AudioEngineService.shared.ensureRunning()
            
            await MainActor.run {
                self.isListening = true
                self.errorMessage = nil
            }
            logger.info("Microphone pitch detection engine started successfully.")
        } catch {
            await MainActor.run {
                self.isListening = false
                self.errorMessage = error.localizedDescription
            }
            logger.error("Failed to start microphone pitch engine: \(error.localizedDescription)")
            throw error
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isListening = false
            self.detectedMidiNote = nil
            self.detectedNoteName = "--"
            self.detectedFrequency = 0.0
            self.inputLevel = 0.0
        }
        logger.info("Microphone pitch detection stopped.")
    }
    
    /// Stops hearing for `seconds`, so the app's own sound through the speaker isn't taken for the piano.
    func ignoreInput(for seconds: TimeInterval) {
        deafLock.lock()
        deafUntil = max(deafUntil, Date().addingTimeInterval(seconds))
        deafLock.unlock()
    }
    
    /// Tells the analysis which notes must sound together, or nil to go back to listening for single notes.
    func expectChord(_ notes: Set<Int>?) {
        deafLock.lock()
        expectedChord = notes
        deafLock.unlock()
    }

    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let samples = UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength))
        
        deafLock.lock()
        let isDeaf = Date() < deafUntil
        let chord = expectedChord
        deafLock.unlock()
        if isDeaf {
            reader.reset()
            return
        }
        
        reader.expectedChord = chord
        let missedBefore = reader.missedChords
        let notes = reader.read(samples)
        let missedChord = reader.missedChords > missedBefore
        let level = min(1.0, max(0.0, reader.level * 10.0))
        let estimate = reader.lastEstimate
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.inputLevel = level
            if let estimate {
                let midi = estimate.midiNote
                self.detectedFrequency = estimate.frequency
                self.detectedMidiNote = midi
                self.detectedNoteName = "\(self.noteNames[midi % 12])\((midi / 12) - 1)"
            }
            for note in notes {
                self.onNoteDetected?(note)
            }
            if missedChord {
                self.onChordMissed?()
            }
        }
    }
}
