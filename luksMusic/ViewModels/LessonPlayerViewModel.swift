// LessonPlayerViewModel.swift
// luksMusic
//
// Runs one lesson step by step. Every step asks for notes: a new note is learned by playing its lit key, drills and
// pieces are read from the staff, ear steps are found by listening, and timed steps are played with the metronome.
// The notes can come from the screen's keyboard, a USB keyboard or the microphone; each is checked the same way.
// A finished step waits on a result card, so the next one never starts by surprise. The microphone is told which
// note comes next, and goes deaf while the app is making sound, so it never hears itself.

import AVFoundation
import Foundation
import Observation
import QuartzCore
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
        case readyToStart
        case countIn(Int)
        case playing
        case onTime
        case early
        case late
        case missed
        case chordMissed
    }

    enum TimedPhase: Equatable {
        case notTimed
        case ready
        case running
    }

    /// Wrong keys on one note before its key is shown
    static let mistakesBeforeHint = 2
    private static let secondsPerDemoNote = 0.65
    private static let microphoneKey = "lessons.useMicrophone"
    /// About how long the microphone takes to report a note, taken off when judging its timing
    private static let microphoneDelay = 0.16
    /// The app's own sound still in the room after it stops playing
    private static let soundTail = 0.4

    private(set) var lesson: Lesson
    private(set) var stepIndex = 0
    private(set) var segment = ReadingSegmentState(steps: [])
    private(set) var accidentals: [[Accidental?]] = []
    /// The steps shown together on the staff
    private(set) var pages: [Range<Int>] = []
    private(set) var feedback: Feedback = .none
    private(set) var wrongPitch: Pitch?
    /// The note the app is playing in a demonstration
    private(set) var demoNote: Int?
    private(set) var isFinished = false
    private(set) var cleanNotes = 0
    private(set) var totalNotes = 0
    private(set) var usesMicrophone = false
    private(set) var microphoneMessage: String?
    private(set) var timedPhase: TimedPhase = .notTimed
    /// Which beat of the measure the metronome is on (from 0)
    private(set) var beatInMeasure: Int?
    /// The microphone is on without headphones, so the app stays silent during a timed step
    private(set) var isSilentForMicrophone = false

    let keyboard = PianoKeyboardViewModel()

    @ObservationIgnored private var whiteKeys = 15
    @ObservationIgnored private var demoToken = 0
    @ObservationIgnored private var timedToken = 0
    @ObservationIgnored private var timing: RhythmTiming?
    @ObservationIgnored private var timedStart: CFTimeInterval?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
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
        begin(step: 0)
    }

    /// Takes the microphone for this screen. Called when the screen appears, not in `init`: SwiftUI may build
    /// extra copies of a screen's model and throw them away, and the microphone reports to one listener only.
    func activate() {
        claimMicrophone()
        if !usesMicrophone, UserDefaults.standard.bool(forKey: Self.microphoneKey) {
            setMicrophone(on: true)
        }
    }

    private func claimMicrophone() {
        microphone.onNoteDetected = { [weak self] note in
            self?.notePlayed(note, inputDelay: Self.microphoneDelay)
        }
        microphone.onChordMissed = { [weak self] in
            self?.chordNotHeard()
        }
        lightCurrentKeys()
    }

    // MARK: - State for the Screen

    var step: LessonStep { lesson.steps[stepIndex] }
    var nextLesson: Lesson? { LessonCatalog.lesson(after: lesson) }
    var stars: Int { Lesson.stars(clean: cleanNotes, total: totalNotes) }
    var progress: Double { Double(stepIndex + (isFinished ? 1 : 0)) / Double(max(1, lesson.steps.count)) }
    var isDemonstrating: Bool { feedback == .listening }

    /// The step that comes after this one, for the result card.
    var nextStepTitle: String? {
        stepIndex + 1 < lesson.steps.count ? lesson.steps[stepIndex + 1].title : nil
    }

    var isStepDone: Bool {
        if case .stepDone = feedback { return true }
        return false
    }

    /// The page of the staff on screen: the one with the note being played or heard.
    var page: Range<Int> {
        let focus = demoNote ?? min(segment.current, max(0, segment.steps.count - 1))
        return pages.first { $0.contains(focus) } ?? pages.last ?? 0..<0
    }

    /// Ear steps show a note only once it was found.
    var visibleRange: Range<Int> {
        guard step.kind == .listen, !segment.isComplete else { return page }
        return page.lowerBound..<max(page.lowerBound, min(page.upperBound, segment.current))
    }

    var visibleSteps: [ReadingStep] { Array(segment.steps[visibleRange]) }
    var visibleAccidentals: [[Accidental?]] { Array(accidentals[visibleRange]) }
    var visibleResults: [ReadingStepResult] { Array(segment.results[visibleRange]) }
    /// The note to play, counted on the visible page (a demonstration may show a page ahead of it)
    var visibleCurrent: Int { max(0, segment.current - visibleRange.lowerBound) }
    var visibleDemoNote: Int? { demoNote.map { $0 - visibleRange.lowerBound } }
    var pageNumber: Int { (pages.firstIndex(of: page) ?? 0) + 1 }

    /// How loud the microphone hears the room, from 0 to 1.
    var microphoneLevel: Double { Double(microphone.inputLevel) }

    /// The last note the microphone recognized, named for the step's key.
    var heardNoteName: String? {
        guard usesMicrophone, let midi = microphone.detectedMidiNote else { return nil }
        return ReadingDrill.name(of: ReadingDrill.spelledPitch(midi: midi, keySignature: step.keySignature))
    }

    /// The USB keyboard in use, by name.
    var connectedKeyboardName: String? {
        // iOS always lists its network MIDI session as a source
        midi.connectedDevices.first {
            let name = $0.name.lowercased()
            return !name.contains("network") && !name.contains("session")
        }?.name
    }

    /// A finished step waits for "Continuar".
    var showsContinue: Bool { !isFinished && isStepDone }

    /// Learning a note can't go wrong, so only practice can be repeated.
    var showsRepeat: Bool { isStepDone && step.isScored }

    /// "Ouvir" is offered by ear steps, by pieces and before a timed step starts.
    var showsListen: Bool {
        guard !isFinished, !segment.isComplete else { return false }
        return step.kind == .listen || step.isPiece || timedPhase == .ready
    }

    // MARK: - Going Through the Lesson

    func continueLesson() {
        cancelPending()
        if stepIndex + 1 < lesson.steps.count {
            begin(step: stepIndex + 1)
        } else {
            isFinished = true
            feedback = .none
            timedPhase = .notTimed
            keyboard.targetNoteKeys = []
            microphone.expect(nil)
            LessonProgress.shared.record(lessonID: lesson.id, stars: stars)
        }
    }

    func repeatStep() {
        cancelPending()
        // The new try replaces the one just counted
        if isStepDone, step.isScored {
            totalNotes -= segment.playableCount
            cleanNotes -= segment.cleanCount
        }
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
        microphone.onChordMissed = nil
        microphone.expect(nil)
    }

    /// Plays the current notes, in rhythm when the step is written in measures.
    func playDemo() {
        guard !segment.steps.isEmpty else { return }
        let token = nextDemoToken()
        let notes = segment.steps
        let secondsPerBeat = step.meter == nil ? Self.secondsPerDemoNote : 60.0 / Double(step.tempo)
        let after: Feedback = step.isTimed ? .readyToStart : (step.kind == .listen ? .yourTurn : .prompt)
        let isWaiting = !segment.isComplete
        let lastEnd = notes.last.map { ($0.globalBeat + $0.heldBeats) * secondsPerBeat } ?? 0
        microphone.ignoreInput(for: lastEnd + Self.soundTail)
        wrongPitch = nil
        if isWaiting {
            feedback = .listening
        }
        Task { @MainActor [weak self] in
            var clock = 0.0
            for (index, note) in notes.enumerated() {
                let wait = note.globalBeat * secondsPerBeat - clock
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    clock += wait
                }
                guard let self, self.demoToken == token else { return }
                self.demoNote = index
                if !note.isRest {
                    for key in note.midiNotes {
                        self.audioEngine.playNote(midiNote: UInt8(clamping: key), velocity: 80, duration: note.heldBeats * secondsPerBeat * 0.9)
                    }
                }
            }
            let tail = lastEnd - clock
            if tail > 0 {
                try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
            }
            guard let self, self.demoToken == token else { return }
            self.demoNote = nil
            if isWaiting {
                self.feedback = after
            }
        }
    }

    /// Starts a timed step: one measure of count-in, then the notes.
    func startTimedStep() {
        guard timedPhase == .ready, !segment.steps.isEmpty else { return }
        _ = nextDemoToken()
        demoNote = nil
        timedPhase = .running
        timedToken += 1
        let token = timedToken

        let secondsPerBeat = 60.0 / Double(step.tempo)
        let beats = step.meter ?? 4
        let timing = RhythmTiming(steps: segment.steps, secondsPerBeat: secondsPerBeat)
        self.timing = timing
        let start = CACurrentMediaTime() + Double(beats) * secondsPerBeat + 0.2
        timedStart = start

        // With the microphone over the speaker, the beat is shown and the music is left out
        let makesSound = !usesMicrophone || hasHeadphones
        isSilentForMicrophone = !makesSound
        let playsMusic = step.kind == .playAlong && makesSound
        let steps = segment.steps

        Task { @MainActor [weak self] in
            var nextClick = -beats
            var nextNote = 0
            while let self, self.timedToken == token {
                let elapsed = CACurrentMediaTime() - start
                while Double(nextClick) * secondsPerBeat <= elapsed {
                    let beat = ((nextClick % beats) + beats) % beats
                    self.beatInMeasure = beat
                    if makesSound {
                        self.audioEngine.playNote(midiNote: beat == 0 ? 96 : 89, velocity: 70, duration: 0.05)
                    }
                    if nextClick < 0 {
                        self.feedback = .countIn(-nextClick)
                    }
                    nextClick += 1
                }
                if elapsed >= 0, case .countIn = self.feedback {
                    self.feedback = .playing
                }
                if playsMusic {
                    while nextNote < steps.count, timing.times[nextNote] <= elapsed {
                        let note = steps[nextNote]
                        if !note.isRest {
                            for key in note.midiNotes {
                                self.audioEngine.playNote(midiNote: UInt8(clamping: key), velocity: 55, duration: note.heldBeats * secondsPerBeat * 0.9)
                            }
                        }
                        nextNote += 1
                    }
                }
                while !self.segment.isComplete, timing.isOverdue(step: self.segment.current, elapsed: elapsed) {
                    self.segment.miss()
                    self.feedback = .missed
                    self.lightCurrentKeys()
                }
                if self.segment.isComplete {
                    self.finishStep()
                    return
                }
                try? await Task.sleep(nanoseconds: 15_000_000)
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
        claimMicrophone()
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
        microphone.ignoreInput(for: 0.5)
        notePlayed(note)
    }

    func screenKeyReleased(_ note: Int) {
        audioEngine.stopNote(midiNote: UInt8(clamping: note))
    }

    /// Checks a note from any source against the current step. `inputDelay` is how late this source reports.
    func notePlayed(_ note: Int, inputDelay: Double = 0) {
        guard !isFinished, !isDemonstrating, !segment.isComplete, let current = segment.currentStep else { return }

        var elapsed: Double?
        if step.isTimed {
            guard timedPhase == .running, let timedStart else { return }
            let time = CACurrentMediaTime() - timedStart - inputDelay
            // Keys played during the count-in don't count
            guard time > -0.35 else { return }
            elapsed = time
        }

        let index = segment.current
        switch segment.press(note) {
        case .ignored:
            return
        case .correct(let stepDone):
            flash(note, into: \.correctKeys)
            wrongPitch = nil
            guard stepDone else {
                lightCurrentKeys()
                return
            }
            if let elapsed, let timing {
                judge(timing.verdict(step: index, elapsed: elapsed), step: index)
            } else {
                feedback = .correct(ReadingDrill.name(of: current))
            }
            lightCurrentKeys()
            if segment.isComplete {
                finishStep()
            }
        case .wrong:
            flash(note, into: \.incorrectKeys)
            let pitch = ReadingDrill.spelledPitch(midi: note, keySignature: step.keySignature)
            wrongPitch = pitch
            feedback = .wrong(ReadingDrill.name(of: pitch))
            if !step.isTimed, segment.results[segment.current].mistakes >= Self.mistakesBeforeHint {
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
        let tokens = current.pool.map {
            LessonNotation.draw(count: current.drawCount, from: $0, favoring: current.focus, using: &generator)
        } ?? current.notes
        let shown = current.readingSteps(tokens: tokens)
        segment = ReadingSegmentState(steps: shown)
        // A drill's notes are unrelated to each other, so each shows its own sign
        accidentals = current.isDrill
            ? shown.map { ReadingDrill.printedAccidentals(for: [$0], keySignature: current.keySignature).first ?? [] }
            : ReadingDrill.printedAccidentals(for: shown, keySignature: current.keySignature)
        pages = LessonNotation.pages(of: shown, measured: current.meter != nil)
        wrongPitch = nil
        demoNote = nil
        beatInMeasure = nil
        isSilentForMicrophone = false
        timedStart = nil
        timing = nil
        keyboard.correctKeys = []
        keyboard.incorrectKeys = []
        keyboard.labelStyle = current.kind == .learn ? .solfege : .hidden
        keyboard.marksOctaves = true
        updateKeyboardRange()

        timedPhase = current.isTimed ? .ready : .notTimed
        switch current.kind {
        case .learn, .read:
            feedback = .prompt
            lightCurrentKeys()
        case .listen:
            lightCurrentKeys()
            playDemo()
        case .rhythm, .playAlong:
            feedback = .readyToStart
            lightCurrentKeys()
        }
    }

    /// While learning, the next key stays lit; elsewhere only after the answer was shown. The microphone is told
    /// which notes come next.
    private func lightCurrentKeys() {
        guard let current = segment.currentStep else {
            keyboard.targetNoteKeys = []
            microphone.expect(nil)
            return
        }
        let result = segment.results[segment.current]
        let lit = step.kind == .learn || result.revealed
        keyboard.targetNoteKeys = lit ? current.midiNotes.subtracting(result.played) : []
        microphone.expect(current.midiNotes)
    }

    private func judge(_ verdict: RhythmTiming.Verdict, step index: Int) {
        switch verdict {
        case .onTime:
            feedback = .onTime
        case .early:
            segment.markOffBeat(step: index)
            feedback = .early
        case .late:
            segment.markOffBeat(step: index)
            feedback = .late
        }
    }

    private func chordNotHeard() {
        guard !segment.isComplete, !isDemonstrating, segment.currentStep != nil else { return }
        feedback = .chordMissed
    }

    /// Shows the step's result and waits for "Continuar" or "Repetir".
    private func finishStep() {
        timedToken += 1
        timedPhase = step.isTimed ? .notTimed : timedPhase
        beatInMeasure = nil
        keyboard.targetNoteKeys = []
        microphone.expect(nil)
        let clean = segment.cleanCount
        let total = segment.playableCount
        if step.isScored {
            cleanNotes += clean
            totalNotes += total
        }
        feedback = .stepDone(clean: clean, total: total)
    }

    private func flash(_ note: Int, into keys: ReferenceWritableKeyPath<PianoKeyboardViewModel, Set<Int>>) {
        keyboard[keyPath: keys].insert(note)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            self?.keyboard[keyPath: keys].remove(note)
        }
    }

    private func updateKeyboardRange() {
        guard let module = LessonCatalog.keyboardNotes(for: lesson) else { return }
        let notes = segment.steps.filter { !$0.isRest }.flatMap(\.midiNotes) + Array(step.litMidiKeys)
        let needed = notes.min().flatMap { low in notes.max().map { low...$0 } } ?? module
        let current = keyboard.rangeEnd > keyboard.rangeStart ? keyboard.rangeStart...keyboard.rangeEnd : nil
        let keys = ReadingDrill.keyboardRange(segment: needed, hand: module, whiteKeys: whiteKeys, current: current)
        guard keys.lowerBound != keyboard.rangeStart || keys.upperBound != keyboard.rangeEnd else { return }
        keyboard.rangeStart = keys.lowerBound
        keyboard.rangeEnd = keys.upperBound
        keyboard.buildKeys()
    }

    private var hasHeadphones: Bool {
        let headphones: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains { headphones.contains($0.portType) }
    }

    private func cancelPending() {
        timedToken += 1
        _ = nextDemoToken()
        demoNote = nil
        beatInMeasure = nil
    }

    private func nextDemoToken() -> Int {
        demoToken += 1
        return demoToken
    }
}
