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

    // Keys under the playback cursor for the interactive keyboard (kept while paused)
    var activeMidiNotes: Set<Int> = []

    // The same keys by hand (treble staff = right hand, bass staff = left hand) and their names ("Sol4, Sol5")
    var activeTrebleMidi: Set<Int> = []
    var activeBassMidi: Set<Int> = []
    var trebleNoteNames: String = ""
    var bassNoteNames: String = ""

    // Onset the cursor rests on in the current measure (drives the engraved score's cursor)
    var cursorBeat: Double = 1.0
    
    // Hands mixer
    var trebleVolume: Double = 0.95
    var bassVolume: Double = 0.9
    var trebleMuted: Bool = false
    var bassMuted: Bool = false
    
    // Looping
    var isLooping: Bool = false
    var loopStartMeasure: Int = 1
    var loopEndMeasure: Int = 1
    
    // Audio engine connection
    private let audioEngine = AudioEngineService.shared
    private var playbackTimer: Timer?
    private var lastPlaybackTime: TimeInterval = 0.0
    private var playedNoteIds: Set<UUID> = []
    
    /// `score.measures` decodes JSON on every access and playback reads it 50 times a second, so keep the decoded copy
    @ObservationIgnored private var measuresCache: (modified: Date, measures: [Measure])?
    
    private var measures: [Measure] {
        if let cache = measuresCache, cache.modified == score.lastModified {
            return cache.measures
        }
        let decoded = score.measures
        measuresCache = (score.lastModified, decoded)
        return decoded
    }
    
    // MARK: - Transposition Helpers
    
    // Indexed by the major tonic's pitch class (0 = C)
    private static let fifthsByTonic = [0, -5, 2, -3, 4, -1, -6, 1, -4, 3, -2, 5]
    private static let keyTextByTonic = ["C, a", "D♭, b♭", "D, b", "E♭, c", "E, c♯", "F, d", "F♯, d♯", "G, e", "A♭, f", "A, f♯", "B♭, g", "B, g♯"]

    private var transposedTonic: Int {
        let tonic = (score.keySignatureValue * 7 % 12 + 12) % 12
        return ((tonic + transpositionSemitones) % 12 + 12) % 12
    }

    var currentKeySignatureValue: Int {
        Self.fifthsByTonic[transposedTonic]
    }

    var transpositionKeyText: String {
        Self.keyTextByTonic[transposedTonic]
    }

    // MARK: - Timeline

    /// Beats in one measure, in the time signature's unit (the unit the player's clock counts).
    var beatsPerMeasure: Double {
        Double(max(1, score.timeSignatureTop))
    }

    /// Position of the cursor in the piece, in seconds at the written tempo.
    var elapsedSeconds: Double {
        (Double(currentMeasureIndex) * beatsPerMeasure + currentBeat - 1) * 60 / Double(max(1, score.tempo))
    }

    /// Length of the piece in seconds at the written tempo.
    var totalSeconds: Double {
        Double(score.measureCount) * beatsPerMeasure * 60 / Double(max(1, score.tempo))
    }

    // MARK: - Initialization

    init(score: Score) {
        self.score = score
        self.loopEndMeasure = max(1, score.measureCount)
        refreshActiveNotes()
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
        refreshActiveNotes()
    }

    func seekToMeasure(_ index: Int) {
        seek(toMeasure: index, beat: 1.0)
    }

    /// Moves the cursor to the note closest to `beat` in the given measure.
    func seek(toMeasure index: Int, beat: Double) {
        guard index >= 0 && index < score.measureCount else { return }
        currentMeasureIndex = index
        currentBeat = measures[index].nearestOnset(to: beat)
        playedNoteIds.removeAll()
        triggerNotes(around: currentBeat)
        refreshActiveNotes()
    }

    /// Recomputes the keys under the cursor; call after anything that moves the cursor or changes transposition.
    func refreshActiveNotes() {
        let measures = self.measures
        guard currentMeasureIndex < measures.count else {
            activeMidiNotes = []
            return
        }
        let measure = measures[currentMeasureIndex]
        let onset = measure.cursorBeat(at: currentBeat)
        if onset != cursorBeat {
            cursorBeat = onset
        }
        let notes = measure.soundingNotes(at: onset)
        let treble = notes.filter { $0.staff == .treble }
        let bass = notes.filter { $0.staff == .bass }
        let trebleMidi = Set(treble.map { Int($0.midiNote) + transpositionSemitones })
        let bassMidi = Set(bass.map { Int($0.midiNote) + transpositionSemitones })
        if trebleMidi != activeTrebleMidi {
            activeTrebleMidi = trebleMidi
            trebleNoteNames = noteNames(treble)
        }
        if bassMidi != activeBassMidi {
            activeBassMidi = bassMidi
            bassNoteNames = noteNames(bass)
        }
        let midi = trebleMidi.union(bassMidi)
        if midi != activeMidiNotes {
            activeMidiNotes = midi
        }
    }

    private static let solfege: [NoteName: String] = [.C: "Dó", .D: "Ré", .E: "Mi", .F: "Fá", .G: "Sol", .A: "Lá", .B: "Si"]
    private static let solfegeBySemitone = ["Dó", "Dó♯", "Ré", "Mi♭", "Mi", "Fá", "Fá♯", "Sol", "Lá♭", "Lá", "Si♭", "Si"]

    /// The notes in solfège with their octave, lowest first ("Dó3, Sol3"); spelled from the score unless transposed.
    private func noteNames(_ notes: [Note]) -> String {
        let named = notes.map { note -> (midi: Int, name: String) in
            let midi = Int(note.midiNote) + transpositionSemitones
            if transpositionSemitones == 0, let syllable = Self.solfege[note.pitch.noteName] {
                let accidental = note.pitch.accidental == .natural ? "" : note.pitch.accidental.symbol
                return (midi, "\(syllable)\(accidental)\(note.pitch.octave)")
            }
            return (midi, "\(Self.solfegeBySemitone[((midi % 12) + 12) % 12])\(midi / 12 - 1)")
        }
        var seen = Set<Int>()
        return named
            .sorted { $0.midi < $1.midi }
            .filter { seen.insert($0.midi).inserted }
            .map { $0.name }
            .joined(separator: ", ")
    }

    // MARK: - Note Steps

    /// Moves the cursor to the next note or rest, crossing into the next measure after the last one.
    func stepForward() {
        let measures = self.measures
        guard currentMeasureIndex < measures.count else { return }
        if let next = Self.onsets(of: measures[currentMeasureIndex]).first(where: { $0 > cursorBeat + 0.001 }) {
            seek(toMeasure: currentMeasureIndex, beat: next)
        } else if currentMeasureIndex + 1 < measures.count {
            seek(toMeasure: currentMeasureIndex + 1, beat: Self.onsets(of: measures[currentMeasureIndex + 1]).first ?? 1.0)
        }
    }

    /// Moves the cursor to the previous note or rest, back into the previous measure from the first one.
    func stepBackward() {
        let measures = self.measures
        guard currentMeasureIndex < measures.count else { return }
        if let previous = Self.onsets(of: measures[currentMeasureIndex]).last(where: { $0 < cursorBeat - 0.001 }) {
            seek(toMeasure: currentMeasureIndex, beat: previous)
        } else if currentMeasureIndex > 0 {
            seek(toMeasure: currentMeasureIndex - 1, beat: Self.onsets(of: measures[currentMeasureIndex - 1]).last ?? 1.0)
        }
    }

    /// Back to the first note of the piece.
    func restart() {
        seek(toMeasure: 0, beat: 1.0)
    }

    private static func onsets(of measure: Measure) -> [Double] {
        Set(measure.notes.map(\.position.beat)).sorted()
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
        refreshActiveNotes()
    }
    
    private func triggerNotesBetween(startBeat: Double, endBeat: Double) {
        let measures = self.measures
        guard currentMeasureIndex < measures.count else { return }
        let currentMeasure = measures[currentMeasureIndex]
        let bpm = Double(score.tempo) * playbackSpeed
        
        for note in currentMeasure.notes where !note.isRest && !isMuted(note.staff) {
            if note.position.beat > startBeat && note.position.beat <= endBeat {
                if !playedNoteIds.contains(note.id) {
                    playedNoteIds.insert(note.id)
                    let durationSeconds = max(0.12, (note.duration.beats * 60.0) / bpm)
                    let transposedMidi = UInt8(clamping: Int(note.midiNote) + transpositionSemitones)
                    
                    audioEngine.playNote(
                        midiNote: transposedMidi,
                        velocity: UInt8(clamping: Int(Double(note.velocity) * volume(for: note.staff))),
                        duration: durationSeconds
                    )
                }
            }
        }
    }
    
    private func triggerNotes(around beat: Double) {
        let measures = self.measures
        guard currentMeasureIndex < measures.count else { return }
        let currentMeasure = measures[currentMeasureIndex]
        let bpm = Double(score.tempo) * playbackSpeed
        
        for note in currentMeasure.notes where !note.isRest && !isMuted(note.staff) {
            if abs(note.position.beat - beat) <= 0.08 {
                if !playedNoteIds.contains(note.id) {
                    playedNoteIds.insert(note.id)
                    let durationSeconds = max(0.12, (note.duration.beats * 60.0) / bpm)
                    let transposedMidi = UInt8(clamping: Int(note.midiNote) + transpositionSemitones)
                    
                    audioEngine.playNote(
                        midiNote: transposedMidi,
                        velocity: UInt8(clamping: Int(Double(note.velocity) * volume(for: note.staff))),
                        duration: durationSeconds
                    )
                }
            }
        }
    }
    
    private func isMuted(_ staff: Staff) -> Bool {
        staff == .treble ? trebleMuted : bassMuted
    }
    
    private func volume(for staff: Staff) -> Double {
        staff == .treble ? trebleVolume : bassVolume
    }
    
    deinit {
        playbackTimer?.invalidate()
    }
}
