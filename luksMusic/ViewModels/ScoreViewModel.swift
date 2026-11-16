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
    
    // Transposition in semitones (0 = original key)
    var transpositionSemitones: Int = 0

    // Keys under the playback cursor for the interactive keyboard (kept while paused)
    var activeMidiNotes: Set<Int> = []

    // The same keys by hand (treble staff = right hand, bass staff = left hand) and their names ("Sol4, Sol5", or
    // "G4, G5" in English)
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
    
    // Metronome: a click on every beat while the piece plays, accented on the first beat of each measure
    var isMetronomeOn: Bool = false
    /// Clicks so far, so the view can flash on each; `metronomeAccent` tells whether the last was a first beat
    private(set) var metronomeClicks: Int = 0
    private(set) var metronomeAccent: Bool = false

    /// What the player repeats at a barline: nothing, the measure the cursor is in (so moving the cursor moves the
    /// loop, like the web player), or the whole piece.
    enum LoopMode {
        case off, measure, piece

        /// The mode the dock's button switches to.
        var next: LoopMode {
            switch self {
            case .off: return .measure
            case .measure: return .piece
            case .piece: return .off
            }
        }
    }

    var loopMode: LoopMode = .off

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
        (beatsBefore(measure: currentMeasureIndex) + currentBeat - 1) * 60 / Double(max(1, score.tempo))
    }

    /// Length of the piece in seconds at the written tempo.
    var totalSeconds: Double {
        beatsBefore(measure: measures.count) * 60 / Double(max(1, score.tempo))
    }

    /// Beats from the start of the piece to measure `index` (a pickup counts only its own beats).
    private func beatsBefore(measure index: Int) -> Double {
        measures.prefix(index).reduce(0) { $0 + $1.beats(timeSignatureTop: score.timeSignatureTop) }
    }

    // MARK: - Initialization

    init(score: Score) {
        self.score = score
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
        // Starting on a beat clicks it; otherwise the next beat crossed does
        if currentBeat - currentBeat.rounded(.down) < 0.02 {
            clickMetronome(onBeat: Int(currentBeat.rounded(.down)))
        }

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
        // A repeated measure is where the loop starts; otherwise the piece starts over
        if loopMode != .measure {
            currentMeasureIndex = 0
        }
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
        let notes = measure.soundingNotes(at: onset, beatUnit: score.timeSignatureBottom)
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
    private static let lettersBySemitone = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// The notes with their octave, lowest first: in solfège ("Dó3, Sol3"), or with letters ("C3, G3") when the app
    /// is in English; spelled from the score unless transposed.
    private func noteNames(_ notes: [Note], letters: Bool = AppLanguage.usesLetterNames) -> String {
        let named = notes.map { note -> (midi: Int, name: String) in
            let midi = Int(note.midiNote) + transpositionSemitones
            if transpositionSemitones == 0 {
                let noteName = note.pitch.noteName
                let syllable = letters ? noteName.rawValue : (Self.solfege[noteName] ?? noteName.rawValue)
                let accidental = note.pitch.accidental == .natural ? "" : note.pitch.accidental.symbol
                return (midi, "\(syllable)\(accidental)\(note.pitch.octave)")
            }
            let names = letters ? Self.lettersBySemitone : Self.solfegeBySemitone
            return (midi, "\(names[((midi % 12) + 12) % 12])\(midi / 12 - 1)")
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

    /// Back to the first note of the piece, or of the measure being repeated.
    func restart() {
        seek(toMeasure: loopMode == .measure ? currentMeasureIndex : 0, beat: 1.0)
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
        // The timer stalls while a drag holds the main run loop (scrolling the score); playback resumes where it
        // stopped, since a jump past barlines would strike every skipped measure's notes at once
        let dt = min(now - lastPlaybackTime, 0.25)
        lastPlaybackTime = now

        let bpm = Double(score.tempo) * playbackSpeed
        let measures = self.measures
        let measureLength = currentMeasureIndex < measures.count
            ? measures[currentMeasureIndex].beats(timeSignatureTop: score.timeSignatureTop)
            : beatsPerMeasure
        guard let step = Self.clockStep(measure: currentMeasureIndex, beat: currentBeat, advancingBy: dt * bpm / 60,
                                        measureLength: measureLength, measureCount: measures.count,
                                        loopMode: loopMode) else {
            stop()
            return
        }

        let prevBeat = currentBeat
        if step.measure != currentMeasureIndex {
            currentMeasureIndex = step.measure
        }
        currentBeat = step.beat
        if step.crossedBarline {
            // A new measure, or the repeated one again: its notes sound afresh from the first beat to the clock
            playedNoteIds.removeAll()
            triggerNotesBetween(startBeat: 0.95, endBeat: currentBeat)
        } else {
            triggerNotesBetween(startBeat: prevBeat, endBeat: currentBeat)
        }
        if let beat = step.clickBeat {
            clickMetronome(onBeat: beat)
        }
        refreshActiveNotes()
    }

    /// Where the playback clock stands after one tick, and the beat whose metronome click fell due in it.
    struct ClockStep: Equatable {
        var measure: Int
        var beat: Double
        /// The tick passed the barline, into the next measure or back to the start of a repeated one
        var crossedBarline: Bool
        var clickBeat: Int?
    }

    /// Moves the clock `beats` on from `beat` in measure `measure`, which lasts `measureLength` beats. Past the barline
    /// the remainder carries into the next measure, into the same one when repeating it, or into the first when
    /// repeating the piece; `nil` when the piece ends. Kept apart from the timer so it can be tested.
    static func clockStep(measure: Int, beat: Double, advancingBy beats: Double, measureLength: Double,
                          measureCount: Int, loopMode: LoopMode) -> ClockStep? {
        let newBeat = beat + beats
        let barline = measureLength + 1
        guard newBeat >= barline else {
            let crossed = Int(newBeat.rounded(.down))
            return ClockStep(measure: measure, beat: newBeat, crossedBarline: false,
                             clickBeat: crossed > Int(beat.rounded(.down)) ? crossed : nil)
        }
        let next: Int
        switch loopMode {
        case .measure:
            next = measure
        case .piece:
            next = measure + 1 < measureCount ? measure + 1 : 0
        case .off:
            guard measure + 1 < measureCount else { return nil }
            next = measure + 1
        }
        return ClockStep(measure: next, beat: 1 + (newBeat - barline), crossedBarline: true, clickBeat: 1)
    }

    /// Beat 1 is the first of the measure and gets the accented click.
    private func clickMetronome(onBeat beat: Int) {
        guard isMetronomeOn else { return }
        audioEngine.playClick(accent: beat == 1)
        metronomeAccent = beat == 1
        metronomeClicks += 1
    }
    
    private func triggerNotesBetween(startBeat: Double, endBeat: Double) {
        let measures = self.measures
        guard currentMeasureIndex < measures.count else { return }
        let currentMeasure = measures[currentMeasureIndex]
        let bpm = Double(score.tempo) * playbackSpeed
        
        for note in currentMeasure.notes where isStruck(note) {
            if note.position.beat > startBeat && note.position.beat <= endBeat {
                if !playedNoteIds.contains(note.id) {
                    playedNoteIds.insert(note.id)
                    let durationSeconds = max(0.12, (note.heldBeats(beatUnit: score.timeSignatureBottom) * 60.0) / bpm)
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
        
        for note in currentMeasure.notes where isStruck(note) {
            if abs(note.position.beat - beat) <= 0.08 {
                if !playedNoteIds.contains(note.id) {
                    playedNoteIds.insert(note.id)
                    let durationSeconds = max(0.12, (note.heldBeats(beatUnit: score.timeSignatureBottom) * 60.0) / bpm)
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
    
    /// Notes the player strikes: not rests, not the held end of a tie, and not on a muted hand.
    private func isStruck(_ note: Note) -> Bool {
        !note.isRest && note.isTieContinuation != true && !isMuted(note.staff)
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
