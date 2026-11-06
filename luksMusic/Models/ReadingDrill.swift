// ReadingDrill.swift
// luksMusic
//
// Rules of the sight-reading drill ("Treino de leitura"), kept apart from the screen so they can be tested:
// one hand's notes as steps (the keys struck together), the segments shown to the player, the accidentals
// printed against the key signature, note names, and the window of keys the phone's keyboard shows.

import Foundation

/// The hand being read: the right hand reads the treble staff, the left hand the bass staff.
enum ReadingHand: String, CaseIterable, Identifiable {
    case right
    case left

    var id: String { rawValue }

    var staff: Staff { self == .right ? .treble : .bass }

    var displayName: String { self == .right ? "Mão direita" : "Mão esquerda" }
}

/// How one segment follows another.
enum ReadingOrder: String, CaseIterable, Identifiable {
    /// Through the piece from the start, segment after segment
    case sequential
    /// Any segment of the piece
    case random

    var id: String { rawValue }

    var displayName: String { self == .sequential ? "Em sequência" : "Aleatório" }
}

/// The keys one hand strikes together at one moment of the piece.
struct ReadingStep: Equatable {
    /// Index of the measure in the score
    let measureIndex: Int
    /// The measure's printed number (0 for a pickup)
    let measureNumber: Int
    /// Onset in the measure, in the time signature's beat (from 1)
    let beat: Double
    /// Beats from the start of the piece to the onset
    let globalBeat: Double
    /// The notes, lowest first, one per key
    let notes: [Note]
    /// How long the longest note is held, in the time signature's beat
    let heldBeats: Double

    var midiNotes: Set<Int> { Set(notes.map { Int($0.midiNote) }) }
}

/// What the player did on one step of the current segment.
struct ReadingStepResult: Equatable {
    /// Keys of the step already found
    var played: Set<Int> = []
    /// Wrong keys pressed while on this step
    var mistakes: Int = 0
    /// The answer was shown (hint, or too many mistakes)
    var revealed: Bool = false
    var isDone: Bool = false

    /// Right on the first try: no wrong key and no hint.
    var isClean: Bool { isDone && mistakes == 0 && !revealed }
}

/// The outcome of one key press.
enum ReadingPress: Equatable {
    /// A key of the step; `stepDone` when it was the step's last missing key
    case correct(stepDone: Bool)
    /// A key of the step that was already found, or a press after the segment ended
    case ignored
    case wrong
}

/// One segment being read: which step is next and how each step went.
struct ReadingSegmentState: Equatable {
    let steps: [ReadingStep]
    private(set) var results: [ReadingStepResult]
    private(set) var current: Int = 0

    init(steps: [ReadingStep]) {
        self.steps = steps
        self.results = Array(repeating: ReadingStepResult(), count: steps.count)
    }

    var isComplete: Bool { current >= steps.count }

    /// Steps read right on the first try.
    var cleanCount: Int { results.filter(\.isClean).count }

    var currentStep: ReadingStep? { isComplete ? nil : steps[current] }

    /// Checks a key against the current step. A chord's keys may come one at a time, in any order.
    mutating func press(_ midi: Int) -> ReadingPress {
        guard current < steps.count else { return .ignored }
        let target = steps[current].midiNotes
        guard target.contains(midi) else {
            results[current].mistakes += 1
            return .wrong
        }
        guard !results[current].played.contains(midi) else { return .ignored }
        results[current].played.insert(midi)
        guard target.isSubset(of: results[current].played) else { return .correct(stepDone: false) }
        results[current].isDone = true
        current += 1
        return .correct(stepDone: true)
    }

    /// Shows the current step's answer; the step no longer counts as right on the first try.
    mutating func reveal() {
        guard current < steps.count else { return }
        results[current].revealed = true
    }
}

enum ReadingDrill {

    /// Lowest and highest keys of an 88-key piano.
    static let pianoRange = 21...108

    // MARK: - Steps and Segments

    /// The hand's notes grouped by onset, in playing order. Rests and the held ends of ties are left out, since
    /// no key is struck for them.
    static func steps(in measures: [Measure], hand: ReadingHand, timeSignatureTop: Int, beatUnit: Int) -> [ReadingStep] {
        var steps: [ReadingStep] = []
        var measureStart = 0.0
        for (index, measure) in measures.enumerated() {
            // A short first measure numbered 0 is a pickup; other unnumbered measures count from their position
            let number = measure.number > 0 ? measure.number : (index == 0 && measure.length != nil ? 0 : index + 1)
            let struck = measure.notes.filter { $0.staff == hand.staff && !$0.isRest && $0.isTieContinuation != true }
            // Onsets a rounding error apart (triplets) are one moment
            let byOnset = Dictionary(grouping: struck) { ($0.position.beat * 1000).rounded() / 1000 }
            for beat in byOnset.keys.sorted() {
                var seen = Set<Int>()
                let notes = (byOnset[beat] ?? [])
                    .sorted { $0.midiNote < $1.midiNote }
                    .filter { seen.insert(Int($0.midiNote)).inserted }
                steps.append(ReadingStep(
                    measureIndex: index,
                    measureNumber: number,
                    beat: beat,
                    globalBeat: measureStart + beat - 1,
                    notes: notes,
                    heldBeats: notes.map { $0.heldBeats(beatUnit: beatUnit) }.max() ?? 1
                ))
            }
            measureStart += measure.beats(timeSignatureTop: timeSignatureTop)
        }
        return steps
    }

    /// Number of segments when the piece is read in order, `size` steps at a time (the last one may be shorter).
    static func segmentCount(stepCount: Int, size: Int) -> Int {
        stepCount == 0 ? 0 : (stepCount + max(1, size) - 1) / max(1, size)
    }

    /// The steps of the segment that starts at `start`.
    static func segment(startingAt start: Int, size: Int, stepCount: Int) -> Range<Int> {
        let lower = max(0, min(start, stepCount))
        return lower..<min(stepCount, lower + max(1, size))
    }

    /// A random segment start, different from `previous` when the piece has more than one.
    static func randomStart<G: RandomNumberGenerator>(stepCount: Int, size: Int, avoiding previous: Int?,
                                                      using generator: inout G) -> Int {
        let last = max(0, stepCount - max(1, size))
        guard last > 0 else { return 0 }
        var start = Int.random(in: 0...last, using: &generator)
        if start == previous {
            start = (start + max(1, size)) % (last + 1)
            if start == previous {
                start = (start + 1) % (last + 1)
            }
        }
        return start
    }

    // MARK: - Key Signature and Accidentals

    private static let sharpOrder: [NoteName] = [.F, .C, .G, .D, .A, .E, .B]

    /// The alteration the key signature gives a letter: +1 sharp, -1 flat, 0 none.
    static func keyAlteration(of letter: NoteName, keySignature: Int) -> Int {
        let count = min(7, abs(keySignature))
        if keySignature > 0 {
            return sharpOrder.prefix(count).contains(letter) ? 1 : 0
        }
        if keySignature < 0 {
            return sharpOrder.reversed().prefix(count).contains(letter) ? -1 : 0
        }
        return 0
    }

    static func accidental(forAlteration alteration: Int) -> Accidental {
        switch alteration {
        case 2: return .doubleSharp
        case 1: return .sharp
        case -1: return .flat
        case -2: return .doubleFlat
        default: return .natural
        }
    }

    /// The accidental printed before each note of `steps` (same shape as the steps' notes), or nil where the key
    /// signature, or an accidental printed earlier in the same measure of the segment, already gives the note.
    static func printedAccidentals(for steps: [ReadingStep], keySignature: Int) -> [[Accidental?]] {
        var inEffect: [String: Int] = [:]
        return steps.map { step in
            step.notes.map { note in
                let key = "\(step.measureIndex)-\(note.pitch.noteName.rawValue)\(note.pitch.octave)"
                let alteration = note.pitch.accidental.semitoneOffset
                let current = inEffect[key] ?? keyAlteration(of: note.pitch.noteName, keySignature: keySignature)
                inEffect[key] = alteration
                return alteration == current ? nil : accidental(forAlteration: alteration)
            }
        }
    }

    // MARK: - Spelling Scores Read Without Note Names

    /// The key signature whose major scale holds the most notes (ties go to the fewest accidentals), for scores
    /// whose data only has MIDI numbers.
    static func estimatedKeySignature(midiNotes: [Int]) -> Int {
        guard !midiNotes.isEmpty else { return 0 }
        var histogram = [Int](repeating: 0, count: 12)
        for midi in midiNotes {
            histogram[((midi % 12) + 12) % 12] += 1
        }
        let majorScale = [0, 2, 4, 5, 7, 9, 11]
        var best = 0
        var bestCount = -1
        for fifths in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6] {
            let tonic = ((fifths * 7) % 12 + 12) % 12
            let count = majorScale.reduce(0) { $0 + histogram[(tonic + $1) % 12] }
            if count > bestCount {
                best = fifths
                bestCount = count
            }
        }
        return best
    }

    /// Names a key the way a score in `keySignature` would: the key's own notes keep their letter (F♯ in G major,
    /// B♭ in F major); other black keys are sharps in sharp keys, flats in flat keys, and C♯ E♭ F♯ A♭ B♭ in C.
    static func spelledPitch(midi: Int, keySignature: Int) -> Pitch {
        let pitchClass = ((midi % 12) + 12) % 12
        let octave = Int((Double(midi) / 12).rounded(.down)) - 1
        for letter in NoteName.allCases {
            let alteration = keyAlteration(of: letter, keySignature: keySignature)
            guard alteration != 0 else { continue }
            let sounding = letter.baseSemitone + alteration
            if (sounding + 12) % 12 == pitchClass {
                // C♭ belongs to the octave above its key, B♯ to the one below
                let octaveShift = sounding < 0 ? 1 : (sounding >= 12 ? -1 : 0)
                return Pitch(noteName: letter, octave: octave + octaveShift, accidental: accidental(forAlteration: alteration))
            }
        }
        let naturals: [Int: NoteName] = [0: .C, 2: .D, 4: .E, 5: .F, 7: .G, 9: .A, 11: .B]
        if let letter = naturals[pitchClass] {
            return Pitch(noteName: letter, octave: octave, accidental: .natural)
        }
        let sharps: [Int: NoteName] = [1: .C, 3: .D, 6: .F, 8: .G, 10: .A]
        let flats: [Int: NoteName] = [1: .D, 3: .E, 6: .G, 8: .A, 10: .B]
        let useSharp = keySignature > 0 || (keySignature == 0 && (pitchClass == 1 || pitchClass == 6))
        if useSharp, let letter = sharps[pitchClass] {
            return Pitch(noteName: letter, octave: octave, accidental: .sharp)
        }
        return Pitch(noteName: flats[pitchClass] ?? .C, octave: octave, accidental: .flat)
    }

    /// The measures with every note renamed for the estimated key, and that key.
    static func respelled(_ measures: [Measure]) -> (measures: [Measure], keySignature: Int) {
        let midiNotes = measures.flatMap { $0.notes.filter { !$0.isRest }.map { Int($0.midiNote) } }
        let keySignature = estimatedKeySignature(midiNotes: midiNotes)
        let renamed = measures.map { measure -> Measure in
            var measure = measure
            measure.notes = measure.notes.map { note in
                guard !note.isRest else { return note }
                var note = note
                note.pitch = spelledPitch(midi: Int(note.midiNote), keySignature: keySignature)
                return note
            }
            return measure
        }
        return (renamed, keySignature)
    }

    // MARK: - Note Names

    private static let solfege: [NoteName: String] = [.C: "Dó", .D: "Ré", .E: "Mi", .F: "Fá", .G: "Sol", .A: "Lá", .B: "Si"]

    /// "Mi5", "Fá♯4", "Si♭3".
    static func name(of pitch: Pitch) -> String {
        let symbol = pitch.accidental == .natural ? "" : pitch.accidental.symbol
        return "\(solfege[pitch.noteName] ?? pitch.noteName.rawValue)\(symbol)\(pitch.octave)"
    }

    /// A step's notes named from the highest down, the way they stack on the staff: "Mi5 · Dó5".
    static func name(of step: ReadingStep) -> String {
        step.notes.reversed().map { name(of: $0.pitch) }.joined(separator: " · ")
    }

    // MARK: - Keyboard Window

    static func isWhite(_ midi: Int) -> Bool {
        ![1, 3, 6, 8, 10].contains(((midi % 12) + 12) % 12)
    }

    /// The white key at or below `midi`.
    static func whiteAtOrBelow(_ midi: Int) -> Int {
        var key = midi
        while !isWhite(key) { key -= 1 }
        return key
    }

    /// The white key at or above `midi`.
    static func whiteAtOrAbove(_ midi: Int) -> Int {
        var key = midi
        while !isWhite(key) { key += 1 }
        return key
    }

    /// The white key `count` white keys away from the white key `from` (left when negative).
    static func white(from: Int, moving count: Int) -> Int {
        var key = from
        var remaining = abs(count)
        while remaining > 0 {
            key += count > 0 ? 1 : -1
            if isWhite(key) { remaining -= 1 }
        }
        return key
    }

    /// White keys from `lower` through `upper`.
    static func whiteCount(_ lower: Int, _ upper: Int) -> Int {
        guard lower <= upper else { return 0 }
        return (lower...upper).filter(isWhite).count
    }

    /// The keys the phone shows: `whiteKeys` white keys, from a white key to a white key. The hand's whole range
    /// when it fits, so the keyboard never moves; otherwise `current` while it still holds the segment, else a
    /// window around the segment that starts on a C when it can. A segment wider than the window gets all its keys.
    static func keyboardRange(segment: ClosedRange<Int>, hand: ClosedRange<Int>?, whiteKeys: Int,
                              current: ClosedRange<Int>?) -> ClosedRange<Int> {
        let whiteKeys = max(7, whiteKeys)

        if let hand {
            let lower = whiteAtOrBelow(hand.lowerBound)
            let upper = whiteAtOrAbove(hand.upperBound)
            let needed = whiteCount(lower, upper)
            if needed <= whiteKeys {
                return window(startingAt: white(from: lower, moving: -((whiteKeys - needed) / 2)), whiteKeys: whiteKeys)
            }
        }

        if let current, current.lowerBound <= segment.lowerBound, segment.upperBound <= current.upperBound,
           whiteCount(current.lowerBound, current.upperBound) == whiteKeys {
            return current
        }

        let lower = whiteAtOrBelow(segment.lowerBound)
        let upper = whiteAtOrAbove(segment.upperBound)
        let needed = whiteCount(lower, upper)
        guard needed < whiteKeys else {
            return max(pianoRange.lowerBound, lower)...min(pianoRange.upperBound, upper)
        }
        let slack = whiteKeys - needed
        let centered = white(from: lower, moving: -(slack / 2))
        // Any start from `slack` white keys left of the segment up to its lowest key keeps it on screen
        let candidates = (0...slack).map { white(from: lower, moving: -$0) }
        let start = candidates
            .filter { $0 % 12 == 0 }
            .min { abs($0 - centered) < abs($1 - centered) } ?? centered
        return window(startingAt: start, whiteKeys: whiteKeys)
    }

    /// `whiteKeys` white keys from `start`, kept on the piano.
    private static func window(startingAt start: Int, whiteKeys: Int) -> ClosedRange<Int> {
        var lower = max(pianoRange.lowerBound, start)
        var upper = white(from: lower, moving: whiteKeys - 1)
        if upper > pianoRange.upperBound {
            upper = pianoRange.upperBound
            lower = max(pianoRange.lowerBound, white(from: upper, moving: -(whiteKeys - 1)))
        }
        return lower...upper
    }
}
