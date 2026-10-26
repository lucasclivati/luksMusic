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
    
    // Transposition in semitones (0 = original key)
    var transpositionSemitones: Int = 0
    
    // Active MIDI note numbers for interactive keyboard visualization
    var activeMidiNotes: Set<Int> = []
    
    // Looping
    var isLooping: Bool = false
    var loopStartMeasure: Int = 1
    var loopEndMeasure: Int = 1
    
    // Audio engine connection
    private let audioEngine = AudioEngineService.shared
    private var playbackTimer: Timer?
    private var lastPlaybackTime: TimeInterval = 0.0
    private var playedNoteIds: Set<UUID> = []
    
    // MARK: - Transposition Helpers
    
    var currentKeySignatureValue: Int {
        let norm = (transpositionSemitones % 12 + 12) % 12
        switch norm {
        case 0: return -3 // Eb major / c minor (3 flats)
        case 1: return 4  // E major / c# minor (4 sharps)
        case 2: return -1 // F major / d minor (1 flat)
        case 3: return -6 // Gb major / eb minor (6 flats)
        case 4: return 1  // G major / e minor (1 sharp)
        case 5: return -4 // Ab major / f minor (4 flats)
        case 6: return 3  // A major / f# minor (3 sharps)
        case 7: return -2 // Bb major / g minor (2 flats)
        case 8: return 5  // B major / g# minor (5 sharps)
        case 9: return 0  // C major / a minor (0)
        case 10: return -5 // Db major / bb minor (5 flats)
        case 11: return 2  // D major / b minor (2 sharps)
        default: return -3
        }
    }
    
    var transpositionKeyText: String {
        let norm = (transpositionSemitones % 12 + 12) % 12
        switch norm {
        case 0: return "E♭, c"
        case 1: return "E, c♯"
        case 2: return "F, d"
        case 3: return "F♯, d♯"
        case 4: return "G, e"
        case 5: return "A♭, f"
        case 6: return "A, f♯"
        case 7: return "B♭, g"
        case 8: return "B, g♯"
        case 9: return "C, a"
        case 10: return "D♭, b♭"
        case 11: return "D, b"
        default: return "E♭, c"
        }
    }
    
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
        activeMidiNotes.removeAll()
        audioEngine.stopAllNotes()
    }
    
    func stop() {
        pause()
        currentMeasureIndex = isLooping ? (loopStartMeasure - 1) : 0
        currentBeat = 1.0
        playedNoteIds.removeAll()
        activeMidiNotes.removeAll()
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
                    let transposedMidi = UInt8(clamping: Int(note.midiNote) + transpositionSemitones)
                    
                    audioEngine.playNote(
                        midiNote: transposedMidi,
                        velocity: UInt8(note.velocity),
                        duration: durationSeconds
                    )
                    
                    let midiInt = Int(transposedMidi)
                    activeMidiNotes.insert(midiInt)
                    DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds) { [weak self] in
                        self?.activeMidiNotes.remove(midiInt)
                    }
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
                    let transposedMidi = UInt8(clamping: Int(note.midiNote) + transpositionSemitones)
                    
                    audioEngine.playNote(
                        midiNote: transposedMidi,
                        velocity: UInt8(note.velocity),
                        duration: durationSeconds
                    )
                    
                    let midiInt = Int(transposedMidi)
                    activeMidiNotes.insert(midiInt)
                    DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds) { [weak self] in
                        self?.activeMidiNotes.remove(midiInt)
                    }
                }
            }
        }
    }
    
    deinit {
        playbackTimer?.invalidate()
    }
}
