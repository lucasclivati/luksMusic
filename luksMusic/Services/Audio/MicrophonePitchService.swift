// MicrophonePitchService.swift
// luksMusic
//
// Real-time acoustic pitch detection service using AVAudioEngine and autocorrelation.
// Listens to acoustic or digital pianos via device microphone to verify notes played in real life.

import Foundation
import AVFoundation
import Accelerate
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
    
    // MARK: - Audio Properties
    
    private let audioEngine = AVAudioEngine()
    private let logger = Logger(subsystem: "com.luksMusic.audio", category: "MicrophonePitchService")
    
    // Audio configuration
    private let bufferSize: AVAudioFrameCount = 2048
    private var sampleRate: Double = 44100.0
    
    // Debounce & onset detection
    private var lastEmittedMidiNote: Int? = nil
    private var lastEmittedTime: Date = .distantPast
    private let minNoteInterval: TimeInterval = 0.12 // 120ms debounce
    private let minimumRMSThreshold: Float = 0.015 // Ignore ambient noise
    
    // Note names lookup
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
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            sampleRate = inputFormat.sampleRate > 0 ? inputFormat.sampleRate : 44100.0
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
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
            self.lastEmittedMidiNote = nil
        }
        logger.info("Microphone pitch detection stopped.")
    }
    
    // MARK: - Audio Processing & Pitch Estimation
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= 512 else { return }
        
        // Compute RMS energy to gate silence
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
        
        let level = min(1.0, max(0.0, rms * 10.0))
        
        guard rms >= minimumRMSThreshold else {
            DispatchQueue.main.async { [weak self] in
                self?.inputLevel = level
            }
            return
        }
        
        // Estimate fundamental frequency using autocorrelation
        if let frequency = detectPitchAutocorrelation(samples: channelData, count: frameCount, sampleRate: sampleRate),
           frequency >= 55.0 && frequency <= 4186.0 { // Piano A1 (55Hz) to C8 (4186Hz)
            
            let midi = Int(round(69.0 + 12.0 * log2(frequency / 440.0)))
            guard midi >= 21 && midi <= 108 else { return } // 88-key piano range
            
            let noteIdx = midi % 12
            let octave = (midi / 12) - 1
            let name = "\(noteNames[noteIdx])\(octave)"
            
            let now = Date()
            let shouldEmit = (lastEmittedMidiNote != midi) || (now.timeIntervalSince(lastEmittedTime) >= minNoteInterval)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.inputLevel = level
                self.detectedFrequency = frequency
                self.detectedMidiNote = midi
                self.detectedNoteName = name
                
                if shouldEmit {
                    self.lastEmittedMidiNote = midi
                    self.lastEmittedTime = now
                    self.onNoteDetected?(midi)
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.inputLevel = level
            }
        }
    }
    
    /// Pitch detection using Normalized Square Difference / Autocorrelation with parabolic interpolation.
    private func detectPitchAutocorrelation(samples: UnsafePointer<Float>, count: Int, sampleRate: Double) -> Double? {
        let minFreq: Double = 55.0   // A1
        let maxFreq: Double = 4186.0 // C8
        
        let minLag = max(1, Int(sampleRate / maxFreq))
        let maxLag = min(count / 2, Int(sampleRate / minFreq))
        
        guard maxLag > minLag else { return nil }
        
        var correlations = [Float](repeating: 0.0, count: maxLag + 1)
        
        // Calculate autocorrelation for lags
        for lag in minLag...maxLag {
            var sum: Float = 0.0
            let windowLength = count - lag
            vDSP_dotpr(samples, 1, samples.advanced(by: lag), 1, &sum, vDSP_Length(windowLength))
            correlations[lag] = sum / Float(windowLength)
        }
        
        // Find highest correlation peak
        var bestLag = -1
        var maxCorrelation: Float = 0.0
        
        for lag in (minLag + 1)..<maxLag {
            let prev = correlations[lag - 1]
            let curr = correlations[lag]
            let next = correlations[lag + 1]
            
            if curr > prev && curr > next && curr > maxCorrelation {
                maxCorrelation = curr
                bestLag = lag
            }
        }
        
        guard bestLag > 0, maxCorrelation > 0.001 else { return nil }
        
        // Parabolic interpolation for fine frequency resolution
        let y0 = Double(correlations[bestLag - 1])
        let y1 = Double(correlations[bestLag])
        let y2 = Double(correlations[bestLag + 1])
        
        let denominator = 2.0 * (2.0 * y1 - y0 - y2)
        let delta = denominator != 0 ? (y0 - y2) / denominator : 0.0
        let refinedLag = Double(bestLag) + delta
        
        guard refinedLag > 0 else { return nil }
        return sampleRate / refinedLag
    }
}
