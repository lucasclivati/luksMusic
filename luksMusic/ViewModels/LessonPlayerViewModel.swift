// LessonPlayerViewModel.swift
// luksMusic
//
// Runs one lesson step by step. The notes can come from the screen's keyboard, a USB keyboard or the microphone;
// each is checked the same way. The microphone goes deaf while the app is making sound, so it never hears itself.

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class LessonPlayerViewModel {

    enum Feedback: Equatable {
        case none
        case prompt
        case correct(String)
        case wrong(String)
        case revealed(String)
        case listening
        case yourTurn
        case stepDone(clean: Int, total: Int)
    }

    /// Wrong keys on one note before its key is shown
    private static let mistakesBeforeHint = 3
    private static let secondsPerDemoNote = 0.65
    private static let microphoneKey = "lessons.useMicrophone"

    private(set) var lesson: Lesson
    private(set) var stepIndex = 0
    private(set) var segment = ReadingSegmentState(steps: [])
    private(set) var accidentals: [[Accidental?]] = []
    private(set) var feedback: Feedback = .none
    private(set) var wrongPitch: Pitch?
    /// The note the app is playing in "Ouça e repita"
    private(set) var demoNote: Int?
    private(set) var isFinished = false
    private(set) var cleanNotes = 0
    private(set) var totalNotes = 0
    private(set) var usesMicrophone = false
    private(set) var microphoneMessage: String?

    let keyboard = PianoKeyboardViewModel()

    @ObservationIgnored private var whiteKeys = 15
    @ObservationIgnored private var demoToken = 0
    @ObservationIgnored private var advanceToken = 0
    @ObservationIgnored private let midiInput = MIDIKeyInput()
    private let audioEngine = AudioEngineService.shared
    private let microphone = MicrophonePitchService.shared
    private let midi = MIDIService.shared

    init(lesson: Lesson) {
        self.lesson = lesson
        midiInput.start(
            onNoteOn: { [weak self] note in
                self?.keyboard.midiActiveKeys.insert(note)
                self?.notePlayed(note)
            },
            onNoteOff: { [weak self] note in
                self?.keyboard.midiActiveKeys.remove(note)
            }
        )
        microphone.onNoteDetected = { [weak self] note in
            self?.notePlayed(note)
        }
        begin(step: 0)
        if UserDefaults.standard.bool(forKey: Self.microphoneKey) {
            setMicrophone(on: true)
        }
    }

    // MARK: - State for the Screen

    var step: LessonStep { lesson.steps[stepIndex] }
    var nextLesson: Lesson? { LessonCatalog.lesson(after: lesson) }
    var stars: Int { Lesson.stars(clean: cleanNotes, total: totalNotes) }
    var progress: Double { Double(stepIndex + (isFinished ? 1 : 0)) / Double(max(1, lesson.steps.count)) }
    var isDemonstrating: Bool { feedback == .listening }

    /// The USB keyboard in use, by name.
    var connectedKeyboardName: String? {
        // iOS always lists its network MIDI session as a source
        midi.connectedDevices.first {
            let name = $0.name.lowercased()
            return !name.contains("network") && !name.contains("session")
        }?.name
    }

    /// A finished exercise with mistakes waits for "Repetir" or "Continuar"; explanations wait for "Continuar".
    var showsContinue: Bool {
        guard !isFinished else { return false }
        if case .stepDone = feedback { return true }
        return step.kind == .explain
    }

    var showsRepeat: Bool {
        if case .stepDone = feedback { return true }
        return false
    }

    // MARK: - Going Through the Lesson

    func continueLesson() {
        cancelPending()
        if stepIndex + 1 < lesson.steps.count {
            begin(step: stepIndex + 1)
        } else {
            isFinished = true
            feedback = .none
            keyboard.targetNoteKeys = []
        }
    }

    func repeatStep() {
        cancelPending()
        // The new try replaces the one just counted
        totalNotes -= segment.steps.count
        cleanNotes -= segment.cleanCount
        begin(step: stepIndex)
    }

    func restartLesson() {
        open(lesson)
    }

    func open(_ newLesson: Lesson) {
        cancelPending()
        lesson = newLesson
        isFinished = false
        cleanNotes = 0
        totalNotes = 0
        begin(step: 0)
    }

    func stop() {
        cancelPending()
        audioEngine.stopAllNotes()
        microphone.stopListening()
        microphone.onNoteDetected = nil
    }

    /// Plays the current notes again.
    func playDemo() {
        guard step.isExercise || !step.notes.isEmpty else { return }
        let token = nextDemoToken()
        let wasWaiting = !segment.isComplete && step.isExercise
        let notes = step.readingSteps
        let seconds = Self.secondsPerDemoNote
        microphone.ignoreInput(for: Double(notes.count) * seconds + 0.6)
        if wasWaiting {
            feedback = .listening
        }
        Task { @MainActor [weak self] in
            for (index, note) in notes.enumerated() {
                guard let self, self.demoToken == token else { return }
                self.demoNote = index
                for midi in note.midiNotes {
                    self.audioEngine.playNote(midiNote: UInt8(clamping: midi), velocity: 80, duration: seconds * 0.9)
                }
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            guard let self, self.demoToken == token else { return }
            self.demoNote = nil
            if wasWaiting {
                self.feedback = .yourTurn
            }
        }
    }

    // MARK: - Input

    func setMicrophone(on: Bool) {
        usesMicrophone = on
        UserDefaults.standard.set(on, forKey: Self.microphoneKey)
        microphoneMessage = nil
        guard on else {
            microphone.stopListening()
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.microphone.startListening()
            } catch {
                self.usesMicrophone = false
                UserDefaults.standard.set(false, forKey: Self.microphoneKey)
                self.microphoneMessage = "Não foi possível usar o microfone. Confira a permissão nos Ajustes do iPhone."
            }
        }
    }

    func setWhiteKeyCount(_ count: Int) {
        guard count != whiteKeys else { return }
        whiteKeys = count
        updateKeyboardRange()
    }

    /// A key tapped on the screen, which sounds through the app.
    func screenKeyPressed(_ note: Int) {
        audioEngine.playNote(midiNote: UInt8(clamping: note), velocity: 85)
        // The phone's speaker must not count as the piano
        microphone.ignoreInput(for: 0.7)
        notePlayed(note)
    }

    func screenKeyReleased(_ note: Int) {
        audioEngine.stopNote(midiNote: UInt8(clamping: note))
    }

    /// Checks a note from any source against the current exercise.
    func notePlayed(_ note: Int) {
        guard !isFinished, step.isExercise, !isDemonstrating, !segment.isComplete, let current = segment.currentStep else { return }

        switch segment.press(note) {
        case .ignored:
            return
        case .correct(let stepDone):
            flash(note, into: \.correctKeys)
            wrongPitch = nil
            guard stepDone else { return }
            feedback = .correct(ReadingDrill.name(of: current))
            lightCurrentKeys()
            if segment.isComplete {
                finishExercise()
            }
        case .wrong:
            flash(note, into: \.incorrectKeys)
            let pitch = ReadingDrill.spelledPitch(midi: note, keySignature: 0)
            wrongPitch = pitch
            feedback = .wrong(ReadingDrill.name(of: pitch))
            if segment.results[segment.current].mistakes >= Self.mistakesBeforeHint {
                segment.reveal()
                feedback = .revealed(ReadingDrill.name(of: current))
                lightCurrentKeys()
            }
        }
    }

    // MARK: - Private

    private func begin(step index: Int) {
        stepIndex = index
        let current = lesson.steps[index]
        let shown = current.readingSteps
        segment = ReadingSegmentState(steps: shown)
        accidentals = ReadingDrill.printedAccidentals(for: shown, keySignature: 0)
        wrongPitch = nil
        demoNote = nil
        keyboard.correctKeys = []
        keyboard.incorrectKeys = []
        keyboard.labelStyle = current.kind == .alone || current.kind == .listen ? .hidden : .solfege
        keyboard.marksOctaves = true
        updateKeyboardRange()

        switch current.kind {
        case .explain:
            feedback = .none
            keyboard.targetNoteKeys = current.litMidiKeys
        case .guided, .alone:
            feedback = .prompt
            lightCurrentKeys()
        case .listen:
            keyboard.targetNoteKeys = []
            playDemo()
        }
    }

    /// In guided steps the next key stays lit; elsewhere only after the answer was shown.
    private func lightCurrentKeys() {
        guard let current = segment.currentStep else {
            keyboard.targetNoteKeys = []
            return
        }
        let result = segment.results[segment.current]
        let lit = step.kind == .guided || result.revealed
        keyboard.targetNoteKeys = lit ? current.midiNotes.subtracting(result.played) : []
    }

    private func finishExercise() {
        let clean = segment.cleanCount
        let total = segment.steps.count
        cleanNotes += clean
        totalNotes += total
        feedback = .stepDone(clean: clean, total: total)
        guard clean == total else { return }

        advanceToken += 1
        let token = advanceToken
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, self.advanceToken == token else { return }
            self.continueLesson()
        }
    }

    private func flash(_ note: Int, into keys: ReferenceWritableKeyPath<PianoKeyboardViewModel, Set<Int>>) {
        keyboard[keyPath: keys].insert(note)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            self?.keyboard[keyPath: keys].remove(note)
        }
    }

    private func updateKeyboardRange() {
        guard let range = LessonCatalog.keyboardNotes(for: lesson) else { return }
        let keys = ReadingDrill.keyboardRange(segment: range, hand: range, whiteKeys: whiteKeys, current: nil)
        guard keys.lowerBound != keyboard.rangeStart || keys.upperBound != keyboard.rangeEnd else { return }
        keyboard.rangeStart = keys.lowerBound
        keyboard.rangeEnd = keys.upperBound
        keyboard.buildKeys()
    }

    private func cancelPending() {
        advanceToken += 1
        _ = nextDemoToken()
        demoNote = nil
    }

    private func nextDemoToken() -> Int {
        demoToken += 1
        return demoToken
    }
}
