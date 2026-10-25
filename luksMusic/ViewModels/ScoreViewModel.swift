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
    private var lastPlaybackTime: TimeInterval = 0.0
    private var playedNoteIds: Set<UUID> = []
    
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
        lastPlaybackTime = CACurrentMediaTime()
        playedNoteIds.removeAll()
        
        // Immediately trigger notes on current starting beat
        triggerNotes(around: currentBeat)
        
        // 50 Hz high-precision continuous clock for smooth cursor & exact note timing
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.tickPlayback()
        }
    }
    
    func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        playedNoteIds.removeAll()
        audioEngine.stopAllNotes()
    }
    
    func stop() {
        pause()
        currentMeasureIndex = isLooping ? (loopStartMeasure - 1) : 0
        currentBeat = 1.0
        playedNoteIds.removeAll()
    }
    
    func seekToMeasure(_ index: Int) {
        guard index >= 0 && index < score.measureCount else { return }
        currentMeasureIndex = index
        currentBeat = 1.0
        playedNoteIds.removeAll()
        triggerNotes(around: 1.0)
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
    
    // MARK: - High-Precision Continuous Playback Loop
    
    private func tickPlayback() {
        guard isPlaying else { return }
        let now = CACurrentMediaTime()
        let dt = now - lastPlaybackTime
        lastPlaybackTime = now
        
        let bpm = Double(score.tempo) * playbackSpeed
        let beatsDelta = dt * (bpm / 60.0)
        
        let prevBeat = currentBeat
        let newBeat = currentBeat + beatsDelta
        let maxBeats = Double(score.timeSignatureTop) + 1.0
        
        if newBeat >= maxBeats {
            // Reached barline: advance to next measure
            currentBeat = 1.0 + (newBeat - maxBeats)
            playedNoteIds.removeAll()
            
            if isLooping && (currentMeasureIndex + 1 >= loopEndMeasure) {
                currentMeasureIndex = max(0, loopStartMeasure - 1)
            } else if currentMeasureIndex + 1 < score.measureCount {
                currentMeasureIndex += 1
            } else {
                stop()
                return
            }
            triggerNotes(around: currentBeat)
        } else {
            currentBeat = newBeat
            triggerNotesBetween(startBeat: prevBeat, endBeat: newBeat)
        }
    }
    
    private func triggerNotesBetween(startBeat: Double, endBeat: Double) {
        guard currentMeasureIndex < score.measures.count else { return }
        let currentMeasure = score.measures[currentMeasureIndex]
        let bpm = Double(score.tempo) * playbackSpeed
        
        for note in currentMeasure.notes where !note.isRest {
            if note.position.beat > startBeat && note.position.beat <= endBeat {
                if !playedNoteIds.contains(note.id) {
                    playedNoteIds.insert(note.id)
                    let durationSeconds = max(0.12, (note.duration.beats * 60.0) / bpm)
                    audioEngine.playNote(
                        midiNote: note.midiNote,
                        velocity: UInt8(note.velocity),
                        duration: durationSeconds
                    )
                }
            }
        }
    }
    
    private func triggerNotes(around beat: Double) {
        guard currentMeasureIndex < score.measures.count else { return }
        let currentMeasure = score.measures[currentMeasureIndex]
        let bpm = Double(score.tempo) * playbackSpeed
        
        for note in currentMeasure.notes where !note.isRest {
            if abs(note.position.beat - beat) <= 0.08 {
                if !playedNoteIds.contains(note.id) {
                    playedNoteIds.insert(note.id)
                    let durationSeconds = max(0.12, (note.duration.beats * 60.0) / bpm)
                    audioEngine.playNote(
                        midiNote: note.midiNote,
                        velocity: UInt8(note.velocity),
                        duration: durationSeconds
                    )
                }
            }
        }
    }
    
    deinit {
        playbackTimer?.invalidate()
    }
}
