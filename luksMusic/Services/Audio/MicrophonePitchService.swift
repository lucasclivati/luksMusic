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
    /// The steady pitch the tuner hears, in hertz; nil in silence or when the tuner isn't on
    var tunerFrequency: Double? = nil
    
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
    @ObservationIgnored private var inputSampleRate = 44100.0
    @ObservationIgnored private var tunerTracker: TunerPitchTracker?
    
    // Time until which the microphone is deaf, while the app itself is making sound
    private let deafLock = NSLock()
    private var deafUntil: Date = .distantPast
    private var expectedNotes: Set<Int>?
    // What the tuner listens for; nil reads struck notes for the practice screens
    @ObservationIgnored private var tunerSettings: TunerPitchTracker.Settings?
    
    // The heard note is named in solfège, or with letters when the app is in English
    private let solfegeNames = ["Dó", "Dó♯", "Ré", "Ré♯", "Mi", "Fá", "Fá♯", "Sol", "Sol♯", "Lá", "Lá♯", "Si"]
    private let letterNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    
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
            let errorMsg = String(localized: "O app precisa do microfone para ouvir o seu piano.")
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
            inputSampleRate = inputFormat.sampleRate > 0 ? inputFormat.sampleRate : 44100.0
            reader = MicrophoneNoteReader(sampleRate: inputSampleRate)
            tunerTracker = nil
            
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
            self.tunerFrequency = nil
        }
        logger.info("Microphone pitch detection stopped.")
    }
    
    /// Stops hearing for `seconds`, so the app's own sound through the speaker isn't taken for the piano.
    func ignoreInput(for seconds: TimeInterval) {
        deafLock.lock()
        deafUntil = max(deafUntil, Date().addingTimeInterval(seconds))
        deafLock.unlock()
    }
    
    /// Tells the analysis which notes the exercise wants now: one note is listened for closely (a different note
    /// is still reported), several must sound together. Nil listens for any note.
    func expect(_ notes: Set<Int>?) {
        deafLock.lock()
        expectedNotes = notes
        deafLock.unlock()
    }

    /// Turns the tuner on (a steady pitch in `tunerFrequency`, from `settings.lowest` to `settings.highest`) or,
    /// with nil, back to reading struck notes.
    func setTuner(_ settings: TunerPitchTracker.Settings?) {
        deafLock.lock()
        tunerSettings = settings
        deafLock.unlock()
        if settings == nil {
            DispatchQueue.main.async { [weak self] in
                self?.tunerFrequency = nil
            }
        }
    }

    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let samples = UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength))
        
        deafLock.lock()
        let isDeaf = Date() < deafUntil
        let expected = expectedNotes
        let tuner = tunerSettings
        deafLock.unlock()
        if isDeaf {
            reader.reset()
            tunerTracker?.reset()
            return
        }
        if let tuner {
            processForTuner(samples, settings: tuner)
            return
        }
        tunerTracker = nil
        
        reader.expectedNotes = expected
        let missedBefore = reader.missedChords
        let notes = reader.read(samples)
        let missedChord = reader.missedChords > missedBefore
        // In decibels, so a piano across the room still moves the meter (-60 dB is empty, -10 dB is full)
        let level = min(1.0, max(0.0, (20 * log10(max(reader.level, 0.000_001)) + 60) / 50))
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.inputLevel = level
            // The last note understood, which the screen shows as heard
            if let midi = notes.last {
                self.detectedFrequency = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
                self.detectedMidiNote = midi
                let names = AppLanguage.usesLetterNames ? self.letterNames : self.solfegeNames
                self.detectedNoteName = "\(names[midi % 12])\((midi / 12) - 1)"
            }
            for note in notes {
                self.onNoteDetected?(note)
            }
            if missedChord {
                self.onChordMissed?()
            }
        }
    }

    /// The tuner's reading of one hop: the pitch while a note rings, nil in silence.
    private func processForTuner(_ samples: UnsafeBufferPointer<Float>, settings: TunerPitchTracker.Settings) {
        if tunerTracker?.settings != settings || tunerTracker?.sampleRate != inputSampleRate {
            tunerTracker = TunerPitchTracker(sampleRate: inputSampleRate, settings: settings)
        }
        // Mutated in place, so its sample window isn't copied every hop
        let frequency = tunerTracker?.process(samples) ?? nil
        let rms = tunerTracker?.level ?? 0
        let level = min(1.0, max(0.0, (20 * log10(max(rms, 0.000_001)) + 60) / 50))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.inputLevel = level
            if self.tunerFrequency != frequency {
                self.tunerFrequency = frequency
            }
        }
    }
}
