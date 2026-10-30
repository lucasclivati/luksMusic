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
    // Onset of the expected notes in the current measure (drives the engraved score's cursor)
    var cursorBeat: Double = 1.0
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
    // Keys of the expected chord already played (guided mode waits for all of them)
    private var playedTargetNotes: Set<Int> = []
    // Decoded once: `score.measures` decodes JSON on every access and the practice clock reads it every step
    private let measures: [Measure]
    
    // MARK: - Initialization
    
    init(score: Score, practiceMode: PracticeMode = .guided) {
        self.score = score
        self.measures = score.measures
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
            
            // In guided mode, once every note of the expected chord is played, move on to the next note
            if practiceMode == .guided {
                playedTargetNotes.insert(midiNote)
                if activeTargetMidiNotes.isSubset(of: playedTargetNotes) {
                    advanceToNextNote()
                }
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
    
    private func advancePracticeBeat(step: Double) {
        currentBeat += step
        // Beats count from 1, so the measure's last beat ends at timeSignatureTop + 1
        if currentBeat >= Double(score.timeSignatureTop) + 1.0 {
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
    
    /// Guided mode: steps past the expected notes; `updateExpectedNotes` lands on the next onset.
    private func advanceToNextNote() {
        currentBeat += 0.01
        updateExpectedNotes()
    }
    
    /// Moves practice to a note tapped on the engraved score.
    func seek(toMeasure index: Int, beat: Double) {
        guard index >= 0 && index < measures.count else { return }
        currentMeasureIndex = index
        currentBeat = beat
        updateExpectedNotes()
    }
    
    /// Re-targets the expected notes (hand filter, guided stepping) and the timer after the mode changes.
    func practiceModeChanged() {
        practiceTimer?.invalidate()
        practiceTimer = nil
        if isRunning && !isPaused {
            startPracticeTimer()
        }
        updateExpectedNotes()
    }
    
    private func updateExpectedNotes() {
        playedTargetNotes = []
        // Guided mode waits on the next note to play, even when it is a few measures ahead
        if practiceMode == .guided, let next = nextNoteOnset(measure: currentMeasureIndex, from: currentBeat) {
            currentMeasureIndex = next.measure
            currentBeat = next.beat
        }
        
        guard currentMeasureIndex < measures.count else {
            expectedNotes = []
            activeTargetMidiNotes = []
            return
        }
        
        let currentMeasure = measures[currentMeasureIndex]
        let candidates = practiceNotes(in: currentMeasure)
        
        // The latest onset reached; timed modes accept it one timer step early
        let reach = currentBeat + (practiceMode == .guided ? 0.001 : 0.25)
        let onset = candidates.map(\.position.beat).filter { $0 <= reach }.max()
        expectedNotes = onset.map { beat in candidates.filter { abs($0.position.beat - beat) < 0.001 } } ?? []
        
        let targets = Set(expectedNotes.map { Int($0.midiNote) })
        if targets != activeTargetMidiNotes {
            activeTargetMidiNotes = targets
        }
        let cursorOnset = onset ?? currentMeasure.cursorBeat(at: currentBeat)
        if cursorOnset != cursorBeat {
            cursorBeat = cursorOnset
        }
    }
    
    /// Notes the current mode asks for in `measure` (one hand only in the hands-separate modes).
    private func practiceNotes(in measure: Measure) -> [Note] {
        measure.notes.filter { note in
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
    }
    
    /// First onset of a note to practice at or after `beat`, moving on through the practice range and back to its start.
    private func nextNoteOnset(measure index: Int, from beat: Double) -> (measure: Int, beat: Double)? {
        let first = max(0, practiceStartMeasure - 1)
        let end = min(practiceEndMeasure, measures.count)
        var measureIndex = index
        var fromBeat = beat
        for _ in 0...max(0, end - first) {
            guard measureIndex < measures.count else { break }
            let onsets = practiceNotes(in: measures[measureIndex]).map(\.position.beat)
            if let onset = onsets.filter({ $0 >= fromBeat - 0.001 }).min() {
                return (measureIndex, onset)
            }
            measureIndex = measureIndex + 1 < end ? measureIndex + 1 : first
            fromBeat = 0
        }
        return nil
    }
    
    var accuracyPercentage: Double {
        guard totalNotesPlayed > 0 else { return 0 }
        return (Double(correctNotes) / Double(totalNotesPlayed)) * 100.0
    }
    
    deinit {
        practiceTimer?.invalidate()
    }
}
