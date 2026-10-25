// EditorViewModel.swift
// luksMusic
//
// View model managing note composition, measure editing, and undo/redo history.

import Foundation
import Observation
import SwiftUI

@Observable
final class EditorViewModel {
    
    // MARK: - Editor State
    
    var score: Score
    var selectedMeasureIndex: Int = 0
    var selectedBeat: Double = 1.0
    var selectedStaff: Staff = .treble
    var selectedDuration: NoteDuration = .quarter
    var selectedAccidental: Accidental = .natural
    var isRestSelected: Bool = false
    var isDottedSelected: Bool = false
    var selectedVoice: Int = 1
    
    // History
    private var undoStack: [[Measure]] = []
    private var redoStack: [[Measure]] = []
    
    private let audioEngine = AudioEngineService.shared
    
    // MARK: - Initialization
    
    init(score: Score) {
        self.score = score
        if score.measures.isEmpty {
            score.measures = [Measure(number: 1, notes: [])]
        }
    }
    
    // MARK: - Note Operations
    
    /// Insert a note with currently selected duration and accidental into current measure.
    func insertNote(pitch: Pitch) {
        saveStateForUndo()
        
        let note = Note(
            pitch: pitch,
            duration: selectedDuration,
            velocity: 80,
            isRest: isRestSelected,
            staff: selectedStaff,
            voice: selectedVoice,
            position: NotePosition(beat: selectedBeat)
        )
        
        var currentMeasures = score.measures
        guard selectedMeasureIndex < currentMeasures.count else { return }
        
        currentMeasures[selectedMeasureIndex].notes.append(note)
        currentMeasures[selectedMeasureIndex].notes.sort { $0.position.beat < $1.position.beat }
        score.measures = currentMeasures
        
        // Play audio preview
        if !note.isRest {
            audioEngine.playNote(midiNote: note.midiNote, velocity: 80)
        }
        
        // Advance beat position
        selectedBeat += selectedDuration.beats
        if selectedBeat > Double(score.timeSignatureTop) {
            selectedBeat = 1.0
            if selectedMeasureIndex + 1 < score.measureCount {
                selectedMeasureIndex += 1
            } else {
                addNewMeasure()
            }
        }
    }
    
    /// Delete the last note or note at current position.
    func deleteLastNote() {
        saveStateForUndo()
        
        var currentMeasures = score.measures
        guard selectedMeasureIndex < currentMeasures.count else { return }
        
        if !currentMeasures[selectedMeasureIndex].notes.isEmpty {
            currentMeasures[selectedMeasureIndex].notes.removeLast()
            score.measures = currentMeasures
        }
    }
    
    /// Add a new empty measure at the end of the score.
    func addNewMeasure() {
        saveStateForUndo()
        var currentMeasures = score.measures
        let newMeasure = Measure(number: currentMeasures.count + 1, notes: [])
        currentMeasures.append(newMeasure)
        score.measures = currentMeasures
        selectedMeasureIndex = currentMeasures.count - 1
        selectedBeat = 1.0
    }
    
    // MARK: - Undo / Redo
    
    private func saveStateForUndo() {
        undoStack.append(score.measures)
        redoStack.removeAll()
    }
    
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(score.measures)
        score.measures = previous
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(score.measures)
        score.measures = next
    }
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
}
