// Lesson.swift
// luksMusic
//
// The "Aprender" course as data: modules of lessons, each a list of steps. Every step asks for notes to be played:
// a new note is learned by playing it, then read without help, then used in a short piece. Notes are written as
// text so lessons read like a score:
//   "C4"  "F#4"  "Bb3"           a note
//   "C4:h"  "D4:q."  "E4:e"      with a value: w h q e s, and "." for a dot (a quarter when left out)
//   "R:q"                        a rest
//   "C4+E4+G4"                   notes played together
//   "C4/t"  "C4/b"               forced onto the treble or the bass staff

import Foundation
import Observation

struct LessonEvent: Equatable {
    let pitches: [Pitch]
    let duration: NoteDuration
    let isRest: Bool
    let forcedStaff: Staff?
}

enum LessonNotation {
    /// Reads "C4", "F#4" or "Bb3".
    static func pitch(from text: String) -> Pitch? {
        guard let first = text.first, let name = NoteName(rawValue: String(first)),
              let octave = Int(text.drop { !$0.isNumber && $0 != "-" }) else { return nil }
        let middle = text.dropFirst().prefix { !$0.isNumber && $0 != "-" }
        let accidental: Accidental
        switch middle {
        case "": accidental = .natural
        case "#": accidental = .sharp
        case "b": accidental = .flat
        default: return nil
        }
        return Pitch(noteName: name, octave: octave, accidental: accidental)
    }

    private static let durations: [String: NoteDuration] = [
        "w": .whole, "h.": .dottedHalf, "h": .half, "q.": .dottedQuarter, "q": .quarter,
        "e.": .dottedEighth, "e": .eighth, "s": .sixteenth,
    ]

    /// Reads one written event, or nil when the text is not valid notation.
    static func event(from token: String) -> LessonEvent? {
        var text = Substring(token)
        var staff: Staff?
        if let slash = text.firstIndex(of: "/") {
            switch text[text.index(after: slash)...] {
            case "t": staff = .treble
            case "b": staff = .bass
            default: return nil
            }
            text = text[..<slash]
        }
        var duration = NoteDuration.quarter
        if let colon = text.firstIndex(of: ":") {
            guard let value = durations[String(text[text.index(after: colon)...])] else { return nil }
            duration = value
            text = text[..<colon]
        }
        if text == "R" {
            return LessonEvent(pitches: [], duration: duration, isRest: true, forcedStaff: staff)
        }
        let pitches = text.split(separator: "+").map { pitch(from: String($0)) }
        guard !pitches.isEmpty, !pitches.contains(where: { $0 == nil }) else { return nil }
        return LessonEvent(pitches: pitches.compactMap { $0 }, duration: duration, isRest: false, forcedStaff: staff)
    }

    /// `count` notes drawn from `pool`, never the same one twice in a row. Notes in `focus` (the ones just
    /// learned) come up twice as often as the others, and each of them at least once.
    static func draw<G: RandomNumberGenerator>(count: Int, from pool: [String], favoring focus: [String] = [],
                                               using generator: inout G) -> [String] {
        guard !pool.isEmpty, count > 0 else { return [] }
        let weights = pool.map { focus.contains($0) ? 2.0 : 1.0 }
        var drawn: [String] = []
        while drawn.count < count {
            let choices = pool.indices.filter { pool.count == 1 || pool[$0] != drawn.last }
            let total = choices.reduce(0) { $0 + weights[$1] }
            var roll = Double.random(in: 0..<total, using: &generator)
            var chosen = choices[0]
            for index in choices {
                roll -= weights[index]
                if roll < 0 {
                    chosen = index
                    break
                }
            }
            drawn.append(pool[chosen])
        }
        for note in focus where pool.contains(note) && !drawn.contains(note) {
            let spot = drawn.indices.shuffled(using: &generator).first { index in
                !focus.contains(drawn[index])
                    && (index == 0 || drawn[index - 1] != note)
                    && (index + 1 == drawn.count || drawn[index + 1] != note)
            }
            if let spot {
                drawn[spot] = note
            }
        }
        return drawn
    }

    /// The columns shown at once, since a phone's staff fits about eight. Measures are kept whole; without
    /// measures the notes are split into even pages.
    static func pages(of steps: [ReadingStep], measured: Bool, columns: Int = 8) -> [Range<Int>] {
        guard !steps.isEmpty else { return [] }
        guard measured else {
            let count = (steps.count + columns - 1) / columns
            let size = (steps.count + count - 1) / count
            return stride(from: 0, to: steps.count, by: size).map { $0..<min(steps.count, $0 + size) }
        }
        var pages: [Range<Int>] = []
        var start = 0
        var index = 0
        while index < steps.count {
            let measure = steps[index].measureIndex
            var end = index
            while end < steps.count && steps[end].measureIndex == measure {
                end += 1
            }
            if end - start > columns && index > start {
                pages.append(start..<index)
                start = index
            }
            index = end
        }
        pages.append(start..<steps.count)
        return pages
    }
}

struct LessonStep: Identifiable {
    enum Kind {
        /// Something new: its notes are named on the staff and their keys lit. Playing them goes on; they don't
        /// count toward the stars.
        case learn
        /// Only the staff: the notes must be read. Drawn at random from `pool`, it is a drill.
        case read
        /// The app plays the notes and they are found by ear; each appears on the staff once played
        case listen
        /// Played in time with the metronome
        case rhythm
        /// Played in time while the app plays the music too
        case playAlong
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let text: String
    /// The events on the staff, in order
    let notes: [String]
    /// Keys lit while learning, when they differ from the notes on the staff
    let litKeys: [String]?
    let staff: Staff
    /// Both staves: notes from middle C up go on the treble staff, the others on the bass staff
    let isGrand: Bool
    /// Sharps (+) or flats (-) in the key signature
    let keySignature: Int
    /// Beats per measure when the step is written in measures
    let meter: Int?
    let tempo: Int
    /// A drill: `drawCount` notes from this pool, instead of `notes`
    let pool: [String]?
    /// The notes of the pool just learned, drawn more often
    let focus: [String]
    let drawCount: Int

    init(_ kind: Kind, _ title: String, _ text: String, notes: String = "", litKeys: String? = nil,
         staff: Staff = .treble, grand: Bool = false, key: Int = 0, meter: Int? = nil, tempo: Int = 72,
         pool: String? = nil, focus: String = "", draw: Int = 10) {
        self.kind = kind
        self.title = title
        self.text = text
        self.notes = notes.split(separator: " ").map(String.init)
        self.litKeys = litKeys?.split(separator: " ").map(String.init)
        self.staff = staff
        self.isGrand = grand
        self.keySignature = key
        self.meter = meter
        self.tempo = tempo
        self.pool = pool?.split(separator: " ").map(String.init)
        self.focus = focus.split(separator: " ").map(String.init)
        self.drawCount = draw
    }

    var isTimed: Bool { kind == .rhythm || kind == .playAlong }
    /// Learning a note isn't scored; everything else counts toward the lesson's stars
    var isScored: Bool { kind != .learn }
    var isDrill: Bool { pool != nil }
    /// A written piece, read at one's own pace: it can be heard first
    var isPiece: Bool { kind == .read && meter != nil }

    /// The events as the staff and the answer checking expect them. Without a meter each event takes one column.
    func readingSteps(tokens: [String]) -> [ReadingStep] {
        var beat = 0.0
        return tokens.compactMap(LessonNotation.event(from:)).map { event in
            let length = meter == nil ? 1.0 : event.duration.beats
            let measure = meter.map { Int((beat + 0.0001) / Double($0)) } ?? 0
            let position = NotePosition(beat: beat + 1)
            let notes: [Note]
            if event.isRest {
                notes = [Note.rest(duration: event.duration, staff: event.forcedStaff ?? staff, position: position)]
            } else {
                notes = event.pitches.map { pitch in
                    let target = event.forcedStaff ?? (isGrand ? (pitch.midiNoteNumber >= 60 ? Staff.treble : .bass) : staff)
                    return Note(pitch: pitch, duration: event.duration, staff: target, position: position)
                }
                .sorted { $0.midiNote < $1.midiNote }
            }
            defer { beat += length }
            return ReadingStep(measureIndex: measure, measureNumber: 0, beat: beat + 1, globalBeat: beat,
                               notes: notes, heldBeats: length)
        }
    }

    var readingSteps: [ReadingStep] { readingSteps(tokens: notes) }

    /// The MIDI numbers of the keys lit while learning, when they differ from the notes on the staff.
    var litMidiKeys: Set<Int> {
        if let litKeys {
            return Set(litKeys.compactMap(LessonNotation.pitch(from:)).map { Int($0.midiNoteNumber) })
        }
        return Set(readingSteps.filter { !$0.isRest }.flatMap(\.midiNotes))
    }

    /// Every key this step writes, lights or may draw.
    var allMidiNotes: [Int] {
        let written = (notes + (pool ?? [])).compactMap(LessonNotation.event(from:)).flatMap(\.pitches)
        let lit = (litKeys ?? []).compactMap(LessonNotation.pitch(from:))
        return (written + lit).map { Int($0.midiNoteNumber) }
    }
}

struct Lesson: Identifiable {
    let id: String
    let title: String
    let summary: String
    let steps: [LessonStep]

    /// Every note the lesson writes or lights, for choosing the keyboard's keys.
    var midiRange: ClosedRange<Int>? {
        let notes = steps.flatMap(\.allMidiNotes)
        guard let low = notes.min(), let high = notes.max() else { return nil }
        return low...high
    }

    /// Stars for how many notes were right on the first try.
    static func stars(clean: Int, total: Int) -> Int {
        guard total > 0 else { return 3 }
        let share = Double(clean) / Double(total)
        return share >= 0.9 ? 3 : (share >= 0.7 ? 2 : 1)
    }
}

struct LessonModule: Identifiable {
    let id: String
    let title: String
    let summary: String
    let lessons: [Lesson]
}

/// When each note of a timed exercise should sound, and how to judge a key played around that moment.
struct RhythmTiming {
    enum Verdict: Equatable {
        case onTime
        case early
        case late
    }

    /// Seconds from the first beat to each step
    let times: [Double]
    /// How far from its moment a key still counts as on time
    let tolerances: [Double]

    init(steps: [ReadingStep], secondsPerBeat: Double) {
        let onsets = steps.map { $0.globalBeat * secondsPerBeat }
        times = onsets
        tolerances = onsets.indices.map { index in
            let gap = index + 1 < onsets.count ? onsets[index + 1] - onsets[index] : steps[index].heldBeats * secondsPerBeat
            return min(0.22, gap * 0.45)
        }
    }

    func verdict(step: Int, elapsed: Double) -> Verdict {
        let difference = elapsed - times[step]
        if abs(difference) <= tolerances[step] { return .onTime }
        return difference < 0 ? .early : .late
    }

    /// The moment to play this step has passed: a late key still counts until the next note is due.
    func isOverdue(step: Int, elapsed: Double) -> Bool {
        let limit = step + 1 < times.count ? times[step + 1] - tolerances[step + 1] : times[step] + tolerances[step] * 3
        return elapsed > max(times[step] + tolerances[step], limit)
    }
}

/// The best result of each lesson, kept on the device. A lesson opens when the one before it was finished.
@MainActor
@Observable
final class LessonProgress {
    static let shared = LessonProgress()

    private static let starsKey = "lessons.stars"
    private static let unlockedKey = "lessons.unlockAll"

    private(set) var stars: [String: Int]
    private(set) var unlocksEverything: Bool

    init(defaults: UserDefaults = .standard) {
        stars = defaults.dictionary(forKey: Self.starsKey) as? [String: Int] ?? [:]
        unlocksEverything = defaults.bool(forKey: Self.unlockedKey)
    }

    func record(lessonID: String, stars earned: Int) {
        stars[lessonID] = max(stars[lessonID] ?? 0, earned)
        UserDefaults.standard.set(stars, forKey: Self.starsKey)
    }

    func setUnlocksEverything(_ value: Bool) {
        unlocksEverything = value
        UserDefaults.standard.set(value, forKey: Self.unlockedKey)
    }

    func isOpen(_ lesson: Lesson, in lessons: [Lesson]) -> Bool {
        guard !unlocksEverything, let index = lessons.firstIndex(where: { $0.id == lesson.id }), index > 0 else { return true }
        return (stars[lessons[index - 1].id] ?? 0) > 0
    }
}
