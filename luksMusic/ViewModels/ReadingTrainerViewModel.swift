// ReadingTrainerViewModel.swift
// luksMusic
//
// The sight-reading drill: shows a few notes of one hand at a time, checks the keys pressed on the screen's
// keyboard, marks each note right or wrong, and moves through the piece in order or at random. The position in
// the piece is remembered per score and hand, so learning a piece can continue on another day.

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ReadingTrainerViewModel {

    /// What the line under the staff says.
    enum Feedback: Equatable {
        case prompt(chord: Int)
        case correct(String)
        case wrong(String)
        case revealed(String)
        case segmentDone(clean: Int, total: Int)
        case noNotes
    }

    static let segmentSizes = [1, 3, 4, 6, 8]

    /// Wrong keys on one step before its answer is shown
    private static let mistakesBeforeHint = 3

    let title: String
    let keySignature: Int

    private(set) var hand: ReadingHand
    private(set) var order: ReadingOrder
    private(set) var segmentSize: Int
    /// Goes to the next segment by itself when every note was right on the first try
    private(set) var advancesAutomatically: Bool
    private(set) var keyLabels: ReadingKeyLabels

    private(set) var steps: [ReadingStep] = []
    private(set) var segmentStart: Int = 0
    private(set) var segment = ReadingSegmentState(steps: [])
    private(set) var accidentals: [[Accidental?]] = []
    private(set) var feedback: Feedback = .noNotes
    /// The wrong key just pressed, drawn faintly on the staff where it would be written
    private(set) var wrongPitch: Pitch?
    /// Step being played back by "Ouvir"
    private(set) var listeningStep: Int?

    // Session results
    private(set) var answered: Int = 0
    private(set) var answeredClean: Int = 0
    private(set) var streak: Int = 0
    private(set) var bestStreak: Int = 0

    /// The on-screen keyboard (range, key labels, right and wrong flashes, hints)
    let keyboard = PianoKeyboardViewModel()
    @ObservationIgnored private var whiteKeys: Int = 15

    private let measures: [Measure]
    private let timeSignatureTop: Int
    private let beatUnit: Int
    private let tempo: Int
    private let storageKey: String
    @ObservationIgnored private var handRange: ClosedRange<Int>?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private var feedbackToken = 0
    @ObservationIgnored private var advanceToken = 0
    @ObservationIgnored private var listenToken = 0
    private let audioEngine = AudioEngineService.shared

    // MARK: - Setup

    /// - Parameters:
    ///   - storageKey: identifies the score for the remembered position
    ///   - spellsFromKey: the score's notes only carry MIDI numbers (online scores), so they are renamed for the
    ///     key their notes suggest
    init(score: Score, storageKey: String, spellsFromKey: Bool = false) {
        var measures = score.measures
        var keySignature = score.keySignatureValue
        if spellsFromKey {
            let respelled = ReadingDrill.respelled(measures)
            measures = respelled.measures
            keySignature = respelled.keySignature
        }
        self.title = score.title
        self.measures = measures
        self.keySignature = keySignature
        self.timeSignatureTop = max(1, score.timeSignatureTop)
        self.beatUnit = max(1, score.timeSignatureBottom)
        self.tempo = max(20, score.tempo)
        self.storageKey = storageKey

        let defaults = Self.defaults
        self.hand = ReadingHand(rawValue: defaults.string(forKey: Self.handKey) ?? "") ?? .right
        self.order = ReadingOrder(rawValue: defaults.string(forKey: Self.orderKey) ?? "") ?? .sequential
        let size = defaults.integer(forKey: Self.sizeKey)
        self.segmentSize = Self.segmentSizes.contains(size) ? size : 3
        self.advancesAutomatically = defaults.object(forKey: Self.autoAdvanceKey) as? Bool ?? true
        self.keyLabels = ReadingKeyLabels(rawValue: defaults.string(forKey: Self.keyLabelsKey) ?? "") ?? .solfege

        applyKeyLabels()
        loadSteps(resume: true)
    }

    // MARK: - Settings

    func setHand(_ newHand: ReadingHand) {
        guard newHand != hand else { return }
        hand = newHand
        Self.defaults.set(newHand.rawValue, forKey: Self.handKey)
        loadSteps(resume: true)
    }

    func setOrder(_ newOrder: ReadingOrder) {
        guard newOrder != order else { return }
        order = newOrder
        Self.defaults.set(newOrder.rawValue, forKey: Self.orderKey)
        if newOrder == .random {
            showSegment(at: randomStart())
        } else {
            // Back to where the piece was being read in order
            let saved = Self.defaults.integer(forKey: positionKey)
            showSegment(at: alignedStart(saved < steps.count ? saved : 0))
        }
    }

    func setSegmentSize(_ size: Int) {
        guard size != segmentSize, size > 0 else { return }
        segmentSize = size
        Self.defaults.set(size, forKey: Self.sizeKey)
        showSegment(at: order == .sequential ? alignedStart(segmentStart) : min(segmentStart, max(0, steps.count - size)))
    }

    func setAdvancesAutomatically(_ value: Bool) {
        advancesAutomatically = value
        Self.defaults.set(value, forKey: Self.autoAdvanceKey)
    }

    func setKeyLabels(_ labels: ReadingKeyLabels) {
        keyLabels = labels
        Self.defaults.set(labels.rawValue, forKey: Self.keyLabelsKey)
        applyKeyLabels()
    }

    /// Called with the white keys that fit the screen's width.
    func setWhiteKeyCount(_ count: Int) {
        guard count != whiteKeys else { return }
        whiteKeys = count
        updateKeyboardRange()
    }

    // MARK: - Progress Through the Piece

    /// Segments of the piece in order, and which one is shown (1-based).
    var segmentNumber: Int { segmentStart / max(1, segmentSize) + 1 }
    var segmentCount: Int { ReadingDrill.segmentCount(stepCount: steps.count, size: segmentSize) }

    /// "Compassos 3–4" for the shown segment ("Anacruse" for a pickup, measure 0).
    var measuresLabel: String {
        guard let first = segment.steps.first?.measureNumber, let last = segment.steps.last?.measureNumber else { return "" }
        if first == 0 {
            switch last {
            case 0: return "Anacruse"
            case 1: return "Anacruse e compasso 1"
            default: return "Anacruse e compassos 1–\(last)"
            }
        }
        return first == last ? "Compasso \(first)" : "Compassos \(first)–\(last)"
    }

    var canGoBack: Bool { order == .sequential && segmentStart > 0 }

    var cleanPercentage: Int {
        answered == 0 ? 0 : Int((Double(answeredClean) / Double(answered) * 100).rounded())
    }

    func nextSegment() {
        guard !steps.isEmpty else { return }
        if order == .random {
            showSegment(at: randomStart())
        } else {
            let next = segmentStart + segmentSize
            showSegment(at: next < steps.count ? next : 0)
        }
    }

    func previousSegment() {
        guard order == .sequential, segmentStart > 0 else { return }
        showSegment(at: max(0, segmentStart - segmentSize))
    }

    func repeatSegment() {
        showSegment(at: segmentStart)
    }

    func restartPiece() {
        showSegment(at: 0)
    }

    // MARK: - Keys

    func keyPressed(_ midi: Int) {
        audioEngine.playNote(midiNote: UInt8(clamping: midi), velocity: 85)
        guard !segment.isComplete, let step = segment.currentStep else { return }

        switch segment.press(midi) {
        case .ignored:
            return
        case .correct(let stepDone):
            flash(correct: midi)
            wrongPitch = nil
            if stepDone {
                keyboard.targetNoteKeys = []
                finishStep(step)
            } else {
                // A chord's remaining keys stay lit when its answer was shown
                let result = segment.results[segment.current]
                keyboard.targetNoteKeys = result.revealed ? step.midiNotes.subtracting(result.played) : []
                setFeedback(.prompt(chord: step.midiNotes.count - result.played.count))
            }
        case .wrong:
            flash(wrong: midi)
            let pitch = ReadingDrill.spelledPitch(midi: midi, keySignature: keySignature)
            wrongPitch = pitch
            setFeedback(.wrong(ReadingDrill.name(of: pitch)), clearsAfter: 1.6)
            if segment.results[segment.current].mistakes >= Self.mistakesBeforeHint {
                reveal()
            }
        }
    }

    func keyReleased(_ midi: Int) {
        audioEngine.stopNote(midiNote: UInt8(clamping: midi))
    }

    /// Shows the current step's keys on the keyboard and its name.
    func reveal() {
        guard let step = segment.currentStep else { return }
        segment.reveal()
        keyboard.targetNoteKeys = step.midiNotes.subtracting(segment.results[segment.current].played)
        setFeedback(.revealed(ReadingDrill.name(of: step)))
    }

    /// Plays the segment at the score's tempo, lighting each step as it sounds.
    func listen() {
        listenToken += 1
        let token = listenToken
        let steps = segment.steps
        guard let first = steps.first else { return }
        let secondsPerBeat = 60.0 / Double(tempo)
        Task { @MainActor [weak self] in
            var previousBeat = first.globalBeat
            for (index, step) in steps.enumerated() {
                // Long rests in this hand are shortened so the notes stay together
                let wait = min(2.0, (step.globalBeat - previousBeat) * secondsPerBeat)
                previousBeat = step.globalBeat
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
                guard let self, self.listenToken == token else { return }
                self.listeningStep = index
                let length = min(1.6, max(0.25, step.heldBeats * secondsPerBeat))
                for midi in step.midiNotes {
                    self.audioEngine.playNote(midiNote: UInt8(clamping: midi), velocity: 80, duration: length)
                }
            }
            let last = steps.last.map { min(1.6, max(0.25, $0.heldBeats * secondsPerBeat)) } ?? 0.5
            try? await Task.sleep(nanoseconds: UInt64(last * 1_000_000_000))
            guard let self, self.listenToken == token else { return }
            self.listeningStep = nil
        }
    }

    func stop() {
        listenToken += 1
        advanceToken += 1
        listeningStep = nil
        audioEngine.stopAllNotes()
    }

    // MARK: - Private

    private func loadSteps(resume: Bool) {
        stop()
        steps = ReadingDrill.steps(in: measures, hand: hand, timeSignatureTop: timeSignatureTop, beatUnit: beatUnit)
        let midiNotes = steps.flatMap(\.midiNotes)
        handRange = midiNotes.min().flatMap { low in midiNotes.max().map { low...$0 } }
        keyboard.rangeStart = 0
        keyboard.rangeEnd = 0
        guard !steps.isEmpty else {
            segment = ReadingSegmentState(steps: [])
            accidentals = []
            feedback = .noNotes
            keyboard.rangeStart = 48
            keyboard.rangeEnd = 72
            keyboard.buildKeys()
            return
        }
        if order == .random {
            showSegment(at: randomStart())
        } else {
            let saved = resume ? Self.defaults.integer(forKey: positionKey) : 0
            showSegment(at: alignedStart(saved < steps.count ? saved : 0))
        }
    }

    private func showSegment(at start: Int) {
        stop()
        let range = ReadingDrill.segment(startingAt: start, size: segmentSize, stepCount: steps.count)
        segmentStart = range.lowerBound
        let shown = Array(steps[range])
        segment = ReadingSegmentState(steps: shown)
        accidentals = ReadingDrill.printedAccidentals(for: shown, keySignature: keySignature)
        wrongPitch = nil
        keyboard.targetNoteKeys = []
        keyboard.correctKeys = []
        keyboard.incorrectKeys = []
        setFeedback(shown.isEmpty ? .noNotes : .prompt(chord: shown[0].midiNotes.count))
        if order == .sequential {
            Self.defaults.set(segmentStart, forKey: positionKey)
        }
        updateKeyboardRange()
    }

    private func finishStep(_ step: ReadingStep) {
        let result = segment.results[segment.current - 1]
        answered += 1
        if result.isClean {
            answeredClean += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }

        guard segment.isComplete else {
            setFeedback(.correct(ReadingDrill.name(of: step)), clearsAfter: 1.2)
            return
        }

        let clean = segment.cleanCount
        setFeedback(.segmentDone(clean: clean, total: segment.steps.count))
        if advancesAutomatically && clean == segment.steps.count {
            advanceToken += 1
            let token = advanceToken
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                guard let self, self.advanceToken == token, self.segment.isComplete else { return }
                self.nextSegment()
            }
        }
    }

    /// Shows `feedback`; after `clearsAfter` seconds the line goes back to asking for the current step.
    private func setFeedback(_ newFeedback: Feedback, clearsAfter delay: Double? = nil) {
        feedbackToken += 1
        feedback = newFeedback
        guard let delay else { return }
        let token = feedbackToken
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.feedbackToken == token, let step = self.segment.currentStep else { return }
            self.wrongPitch = nil
            let missing = step.midiNotes.count - self.segment.results[self.segment.current].played.count
            self.feedback = .prompt(chord: missing)
        }
    }

    private func flash(correct midi: Int) {
        keyboard.correctKeys.insert(midi)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            self?.keyboard.correctKeys.remove(midi)
        }
    }

    private func flash(wrong midi: Int) {
        keyboard.incorrectKeys.insert(midi)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            self?.keyboard.incorrectKeys.remove(midi)
        }
    }

    private func updateKeyboardRange() {
        // Every key of the segment stays on screen, so the keyboard doesn't move while it is read
        let notes = segment.steps.flatMap(\.midiNotes)
        guard let low = notes.min(), let high = notes.max() else { return }
        let current = keyboard.rangeEnd > keyboard.rangeStart ? keyboard.rangeStart...keyboard.rangeEnd : nil
        let range = ReadingDrill.keyboardRange(segment: low...high, hand: handRange, whiteKeys: whiteKeys, current: current)
        guard range.lowerBound != keyboard.rangeStart || range.upperBound != keyboard.rangeEnd else { return }
        keyboard.rangeStart = range.lowerBound
        keyboard.rangeEnd = range.upperBound
        keyboard.buildKeys()
    }

    private func applyKeyLabels() {
        switch keyLabels {
        case .solfege:
            keyboard.labelStyle = .solfege
        case .letters:
            keyboard.labelStyle = .letter
        case .octavesOnly, .hidden:
            keyboard.labelStyle = .hidden
        }
        keyboard.marksOctaves = keyLabels != .hidden
    }

    private func alignedStart(_ start: Int) -> Int {
        max(0, start) / max(1, segmentSize) * max(1, segmentSize)
    }

    private func randomStart() -> Int {
        ReadingDrill.randomStart(stepCount: steps.count, size: segmentSize, avoiding: segmentStart, using: &generator)
    }

    // MARK: - Remembered Settings

    private static var defaults: UserDefaults { .standard }
    private static let handKey = "readingTrainer.hand"
    private static let orderKey = "readingTrainer.order"
    private static let sizeKey = "readingTrainer.segmentSize"
    private static let autoAdvanceKey = "readingTrainer.autoAdvance"
    private static let keyLabelsKey = "readingTrainer.keyLabels"

    private var positionKey: String { "readingTrainer.position.\(storageKey).\(hand.rawValue)" }
}

/// What the drill's keyboard writes on its keys.
enum ReadingKeyLabels: String, CaseIterable, Identifiable {
    case solfege
    case letters
    case octavesOnly
    case hidden

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solfege: return "Dó Ré Mi"
        case .letters: return "C D E"
        case .octavesOnly: return "Só os Dós"
        case .hidden: return "Sem nomes"
        }
    }
}
