// ScoreViewModel.swift
// luksMusic
//
// View model managing score viewing, playback, and navigation.

import Foundation
import Observation
import SwiftUI

@Observable
final class ScoreViewModel {
    
    // MARK: - Properties
    
    var score: Score
    var currentMeasureIndex: Int = 0
    var currentBeat: Double = 1.0
    var isPlaying: Bool = false
    var playbackSpeed: Double = 1.0
    var zoomScale: CGFloat = 1.0
    
    // Looping
    var isLooping: Bool = false
    var loopStartMeasure: Int = 1
    var loopEndMeasure: Int = 1
    
    // Audio engine connection
    private let audioEngine = AudioEngineService.shared
    private var playbackTimer: Timer?
    
    // MARK: - Initialization
    
    init(score: Score) {
        self.score = score
        self.loopEndMeasure = max(1, score.measureCount)
    }
    
    // MARK: - Playback Controls
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        
        let bpm = Double(score.tempo) * playbackSpeed
        let interval = 60.0 / bpm / 4.0 // 16th note granularity
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advancePlayback(step: 0.25)
        }
    }
    
    func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        audioEngine.stopAllNotes()
    }
    
    func stop() {
        pause()
        currentMeasureIndex = isLooping ? (loopStartMeasure - 1) : 0
        currentBeat = 1.0
    }
    
    func seekToMeasure(_ index: Int) {
        guard index >= 0 && index < score.measureCount else { return }
        currentMeasureIndex = index
        currentBeat = 1.0
        playCurrentMeasureNotes()
    }
    
    func nextMeasure() {
        if currentMeasureIndex < score.measureCount - 1 {
            seekToMeasure(currentMeasureIndex + 1)
        }
    }
    
    func previousMeasure() {
        if currentMeasureIndex > 0 {
            seekToMeasure(currentMeasureIndex - 1)
        }
    }
    
    // MARK: - Playback Loop Logic
    
    private func advancePlayback(step: Double) {
        currentBeat += step
        
        let maxBeats = Double(score.timeSignatureTop)
        if currentBeat > maxBeats {
            currentBeat = 1.0
            
            if isLooping && (currentMeasureIndex + 1 >= loopEndMeasure) {
                currentMeasureIndex = max(0, loopStartMeasure - 1)
            } else if currentMeasureIndex + 1 < score.measureCount {
                currentMeasureIndex += 1
            } else {
                // End of score reached
                stop()
                return
            }
        }
        
        playNotesAtCurrentBeat()
    }
    
    private func playNotesAtCurrentBeat() {
        guard currentMeasureIndex < score.measures.count else { return }
        let currentMeasure = score.measures[currentMeasureIndex]
        
        // Find notes that start around current beat
        let activeNotes = currentMeasure.notes.filter { note in
            !note.isRest && abs(note.position.beat - currentBeat) < 0.15
        }
        
        for note in activeNotes {
            audioEngine.playNote(midiNote: note.midiNote, velocity: UInt8(note.velocity))
        }
    }
    
    private func playCurrentMeasureNotes() {
        guard currentMeasureIndex < score.measures.count else { return }
        let notes = score.measures[currentMeasureIndex].notes.filter { !$0.isRest }
        for note in notes.prefix(2) {
            audioEngine.playNote(midiNote: note.midiNote, velocity: 70)
        }
    }
    
    deinit {
        playbackTimer?.invalidate()
    }
}
