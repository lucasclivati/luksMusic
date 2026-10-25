// PracticeViewModel.swift
// luksMusic
//
// View model managing interactive piano practice, note evaluation, and scoring.

import Foundation
import Observation
import SwiftUI
import SwiftData

@Observable
final class PracticeViewModel {
    
    // MARK: - Properties
    
    var score: Score
    var practiceMode: PracticeMode = .guided
    var tempoBPM: Int
    var isRunning: Bool = false
    var isPaused: Bool = false
    var currentMeasureIndex: Int = 0
    var currentBeat: Double = 1.0
    
    // Accuracy tracking
    var totalNotesPlayed: Int = 0
    var correctNotes: Int = 0
    var incorrectNotes: Int = 0
    var missedNotes: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var sessionStartTime: Date = Date()
    var sessionCompleted: Bool = false
    var latestSession: PracticeSession? = nil
    
    // Active / Expected notes
    var expectedNotes: [Note] = []
    var activeTargetMidiNotes: Set<Int> = []
    var correctKeyFeedback: Set<Int> = []
    var incorrectKeyFeedback: Set<Int> = []
    
    // Microphone Pitch Detection Mode
    var isMicrophoneEnabled: Bool = false
    var microphoneService = MicrophonePitchService.shared
    
    // Looping / Section Practice
    var practiceStartMeasure: Int = 1
    var practiceEndMeasure: Int = 1
    
    // Dependencies
    private let audioEngine = AudioEngineService.shared
    private let midiService = MIDIService.shared
    private var practiceTimer: Timer?
    
    // MARK: - Initialization
    
    init(score: Score, practiceMode: PracticeMode = .guided) {
        self.score = score
        self.practiceMode = practiceMode
        self.tempoBPM = practiceMode == .slowPractice ? max(40, Int(Double(score.tempo) * 0.7)) : score.tempo
        self.practiceEndMeasure = max(1, score.measureCount)
        updateExpectedNotes()
        setupMicrophoneListener()
    }
    
    private func setupMicrophoneListener() {
        microphoneService.onNoteDetected = { [weak self] midiNote in
            guard let self = self, self.isMicrophoneEnabled, self.isRunning, !self.isPaused else { return }
            self.notePlayed(midiNote: midiNote, fromMicrophone: true)
        }
    }
    
    func toggleMicrophoneListening() {
        isMicrophoneEnabled.toggle()
        if isMicrophoneEnabled {
            Task {
                try? await self.microphoneService.startListening()
            }
        } else {
            microphoneService.stopListening()
        }
    }
    
    // MARK: - Practice Lifecycle
    
    func startPractice() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        sessionStartTime = Date()
        sessionCompleted = false
        totalNotesPlayed = 0
        correctNotes = 0
        incorrectNotes = 0
        missedNotes = 0
        currentStreak = 0
        longestStreak = 0
        currentMeasureIndex = max(0, practiceStartMeasure - 1)
        currentBeat = 1.0
        
        updateExpectedNotes()
        startPracticeTimer()
    }
    
    func pausePractice() {
        isPaused = true
        practiceTimer?.invalidate()
        practiceTimer = nil
        audioEngine.stopAllNotes()
    }
    
    func resumePractice() {
        guard isRunning && isPaused else { return }
        isPaused = false
        startPracticeTimer()
    }
    
    func stopPractice(modelContext: ModelContext? = nil) {
        isRunning = false
        isPaused = false
        practiceTimer?.invalidate()
        practiceTimer = nil
        audioEngine.stopAllNotes()
        if isMicrophoneEnabled {
            microphoneService.stopListening()
        }
        
        // Save session stats if notes were played
        if totalNotesPlayed > 0, let context = modelContext {
            let session = PracticeSession(
                scoreId: score.id,
                scoreTitle: score.title,
                startTime: sessionStartTime,
                endTime: Date(),
                totalNotesPlayed: totalNotesPlayed,
                correctNotes: correctNotes,
                incorrectNotes: incorrectNotes,
                missedNotes: missedNotes,
                tempoUsed: tempoBPM,
                sectionsCompleted: currentMeasureIndex + 1,
                longestStreak: longestStreak,
                practiceMode: practiceMode
            )
            context.insert(session)
            score.lastPracticed = Date()
            try? context.save()
            self.latestSession = session
            self.sessionCompleted = true
        }
    }
    
    // MARK: - Note Evaluation
    
    /// Evaluates a note played by the user (tap on screen keyboard, external MIDI, or acoustic piano via microphone).
    func notePlayed(midiNote: Int, fromMicrophone: Bool = false) {
        if !fromMicrophone {
            audioEngine.playNote(midiNote: UInt8(midiNote), velocity: 85)
        }
        totalNotesPlayed += 1
        
        let isCorrect = activeTargetMidiNotes.contains(midiNote)
        
        if isCorrect {
            correctNotes += 1
            currentStreak += 1
            longestStreak = max(longestStreak, currentStreak)
            
            // Visual feedback
            correctKeyFeedback.insert(midiNote)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.correctKeyFeedback.remove(midiNote)
            }
            
            // In guided mode, if all target notes for current beat are hit, advance!
            if practiceMode == .guided {
                advancePracticeBeat()
            }
        } else {
            incorrectNotes += 1
            currentStreak = 0
            
            // Red flash feedback
            incorrectKeyFeedback.insert(midiNote)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.incorrectKeyFeedback.remove(midiNote)
            }
        }
    }
    
    func noteReleased(midiNote: Int) {
        audioEngine.stopNote(midiNote: UInt8(midiNote))
    }
    
    // MARK: - Timing & Progression
    
    private func startPracticeTimer() {
        guard practiceMode != .guided else {
            // Guided mode waits for user input to advance
            return
        }
        
        let interval = 60.0 / Double(tempoBPM) / 4.0 // 16th note interval
        practiceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advancePracticeBeat(step: 0.25)
        }
    }
    
    private func advancePracticeBeat(step: Double = 0.5) {
        currentBeat += step
        let maxBeats = Double(score.timeSignatureTop)
        
        if currentBeat > maxBeats {
            currentBeat = 1.0
            if currentMeasureIndex + 1 < practiceEndMeasure {
                currentMeasureIndex += 1
            } else {
                // Completed looped section or piece
                currentMeasureIndex = max(0, practiceStartMeasure - 1)
            }
        }
        
        updateExpectedNotes()
    }
    
    private func updateExpectedNotes() {
        guard currentMeasureIndex < score.measures.count else {
            expectedNotes = []
            activeTargetMidiNotes = []
            return
        }
        
        let currentMeasure = score.measures[currentMeasureIndex]
        
        // Filter notes by practice mode
        let candidates = currentMeasure.notes.filter { note in
            guard !note.isRest else { return false }
            switch practiceMode {
            case .handsSeparateRight:
                return note.staff == .treble
            case .handsSeparateLeft:
                return note.staff == .bass
            default:
                return true
            }
        }
        
        // Find notes on or near current beat
        let active = candidates.filter { abs($0.position.beat - currentBeat) < 0.35 }
        expectedNotes = active.isEmpty ? candidates.prefix(2).map { $0 } : active
        activeTargetMidiNotes = Set(expectedNotes.map { Int($0.midiNote) })
    }
    
    var accuracyPercentage: Double {
        guard totalNotesPlayed > 0 else { return 0 }
        return (Double(correctNotes) / Double(totalNotesPlayed)) * 100.0
    }
    
    deinit {
        practiceTimer?.invalidate()
    }
}
