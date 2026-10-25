// MetronomeService.swift
// luksMusic
//
// A metronome service for practice, providing precise tempo-based click sounds
// with time signature support and visual beat indicators.

import AVFoundation
import Observation
import os.log

// MARK: - MetronomeService

/// A metronome service that provides tempo-based click sounds for practice.
///
/// Features:
/// - Configurable BPM (40–240)
/// - Time signature support
/// - Accented beat 1
/// - Visual beat indicator via `currentBeat`
///
/// ## Usage
/// ```swift
/// let metronome = MetronomeService()
/// metronome.tempo = 120
/// metronome.start()
/// ```
@Observable
final class MetronomeService {
    
    // MARK: - Constants
    
    /// Minimum allowed tempo in BPM.
    static let minTempo: Int = 40
    
    /// Maximum allowed tempo in BPM.
    static let maxTempo: Int = 240
    
    // MARK: - Published Properties
    
    /// The tempo in beats per minute, clamped to 40–240.
    var tempo: Int = 120 {
        didSet {
            let clamped = min(max(tempo, Self.minTempo), Self.maxTempo)
            if tempo != clamped { tempo = clamped }
            if isPlaying {
                // Restart with new tempo
                stopTimer()
                startTimer()
            }
        }
    }
    
    /// The numerator of the time signature (number of beats per measure).
    var timeSignatureNumerator: Int = 4 {
        didSet {
            let clamped = max(1, timeSignatureNumerator)
            if timeSignatureNumerator != clamped { timeSignatureNumerator = clamped }
        }
    }
    
    /// The denominator of the time signature (note value that gets one beat).
    var timeSignatureDenominator: Int = 4 {
        didSet {
            let valid = [1, 2, 4, 8, 16]
            if !valid.contains(timeSignatureDenominator) {
                timeSignatureDenominator = 4
            }
        }
    }
    
    /// Whether the metronome is currently playing.
    private(set) var isPlaying: Bool = false
    
    /// The current beat position within the measure (1-indexed).
    private(set) var currentBeat: Int = 1
    
    // MARK: - Private Properties
    
    /// The audio engine for click playback.
    private let engine = AVAudioEngine()
    
    /// Player node for accent clicks (beat 1).
    private let accentPlayerNode = AVAudioPlayerNode()
    
    /// Player node for normal clicks.
    private let normalPlayerNode = AVAudioPlayerNode()
    
    /// Audio buffer for the accent click sound.
    private var accentClickBuffer: AVAudioPCMBuffer?
    
    /// Audio buffer for the normal click sound.
    private var normalClickBuffer: AVAudioPCMBuffer?
    
    /// Timer for scheduling beats.
    private var timer: DispatchSourceTimer?
    
    /// The dispatch queue for timer operations.
    private let timerQueue = DispatchQueue(label: "com.luksMusic.metronome", qos: .userInteractive)
    
    /// Logger for structured logging.
    private let logger = Logger(subsystem: "com.luksMusic.audio", category: "Metronome")
    
    // MARK: - Initialization
    
    /// Creates a new metronome service.
    ///
    /// - Parameters:
    ///   - tempo: Initial tempo in BPM (default: 120).
    ///   - timeSignatureNumerator: Beats per measure (default: 4).
    ///   - timeSignatureDenominator: Note value per beat (default: 4).
    init(tempo: Int = 120, timeSignatureNumerator: Int = 4, timeSignatureDenominator: Int = 4) {
        self.tempo = min(max(tempo, Self.minTempo), Self.maxTempo)
        self.timeSignatureNumerator = max(1, timeSignatureNumerator)
        self.timeSignatureDenominator = timeSignatureDenominator
        
        setupAudioEngine()
        generateClickBuffers()
    }
    
    deinit {
        stop()
        engine.stop()
    }
    
    // MARK: - Public Methods
    
    /// Starts the metronome.
    func start() {
        guard !isPlaying else { return }
        
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                logger.error("Failed to start metronome engine: \(error.localizedDescription)")
                return
            }
        }
        
        accentPlayerNode.play()
        normalPlayerNode.play()
        
        currentBeat = 1
        isPlaying = true
        startTimer()
        
        logger.info("Metronome started at \(self.tempo) BPM.")
    }
    
    /// Stops the metronome.
    func stop() {
        guard isPlaying else { return }
        
        stopTimer()
        accentPlayerNode.stop()
        normalPlayerNode.stop()
        
        isPlaying = false
        currentBeat = 1
        
        logger.info("Metronome stopped.")
    }
    
    /// Toggles the metronome between playing and stopped states.
    func toggle() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }
    
    // MARK: - Audio Engine Setup
    
    /// Sets up the audio engine with player nodes.
    private func setupAudioEngine() {
        engine.attach(accentPlayerNode)
        engine.attach(normalPlayerNode)
        
        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)
        
        engine.connect(accentPlayerNode, to: mainMixer, format: format)
        engine.connect(normalPlayerNode, to: mainMixer, format: format)
        
        engine.prepare()
    }
    
    /// Generates synthetic click sound buffers for accent and normal beats.
    private func generateClickBuffers() {
        accentClickBuffer = generateClickBuffer(frequency: 1000.0, duration: 0.04, amplitude: 0.8)
        normalClickBuffer = generateClickBuffer(frequency: 800.0, duration: 0.03, amplitude: 0.5)
    }
    
    /// Generates a short sine wave click buffer.
    ///
    /// - Parameters:
    ///   - frequency: The frequency of the click tone in Hz.
    ///   - duration: The duration of the click in seconds.
    ///   - amplitude: The amplitude of the click (0.0–1.0).
    /// - Returns: An `AVAudioPCMBuffer` containing the synthesized click, or nil on failure.
    private func generateClickBuffer(
        frequency: Double,
        duration: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        let sampleRate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            logger.error("Failed to create audio buffer for click sound.")
            return nil
        }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let sineValue = sin(2.0 * Double.pi * frequency * time)
            
            // Apply an exponential decay envelope for a natural click sound
            let envelope = exp(-time * 80.0)
            channelData[frame] = Float(sineValue * envelope) * amplitude
        }
        
        return buffer
    }
    
    // MARK: - Timer Management
    
    /// Starts the beat timer based on the current tempo.
    private func startTimer() {
        let interval = 60.0 / Double(tempo) // seconds per beat
        
        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        source.schedule(
            deadline: .now(),
            repeating: interval,
            leeway: .milliseconds(1)
        )
        
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        
        source.resume()
        timer = source
    }
    
    /// Stops the beat timer.
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    /// Processes a single metronome tick.
    private func tick() {
        let isAccent = (currentBeat == 1)
        
        if isAccent {
            playClick(accent: true)
        } else {
            playClick(accent: false)
        }
        
        // Update currentBeat on main thread for UI
        let nextBeat = (currentBeat % timeSignatureNumerator) + 1
        DispatchQueue.main.async { [weak self] in
            self?.currentBeat = nextBeat
        }
    }
    
    /// Plays a click sound.
    ///
    /// - Parameter accent: Whether to play the accented (beat 1) click.
    private func playClick(accent: Bool) {
        if accent {
            guard let buffer = accentClickBuffer else { return }
            accentPlayerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        } else {
            guard let buffer = normalClickBuffer else { return }
            normalPlayerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }
}
