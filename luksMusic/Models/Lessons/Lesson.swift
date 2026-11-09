// Lesson.swift
// luksMusic
//
// The "Aprender" course as data: modules of lessons, each a list of steps that explain something or ask for
// notes to be played. Notes are written as text ("C4", "F#4", "Bb3") so lessons read like a score.

import Foundation

struct LessonStep: Identifiable {
    enum Kind {
        /// Text with the notes on the staff and their keys lit; nothing to play
        case explain
        /// The keys to play are lit and named
        case guided
        /// Only the staff: the notes must be read
        case alone
        /// The app plays the notes, then they are played back from the staff
        case listen
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let text: String
    /// The notes on the staff, in order
    let notes: [String]
    /// Keys lit during an explanation, when they differ from the notes on the staff
    let litKeys: [String]?
    let staff: Staff

    init(_ kind: Kind, _ title: String, _ text: String, notes: String = "", litKeys: String? = nil, staff: Staff = .treble) {
        self.kind = kind
        self.title = title
        self.text = text
        self.notes = notes.split(separator: " ").map(String.init)
        self.litKeys = litKeys?.split(separator: " ").map(String.init)
        self.staff = staff
    }

    var isExercise: Bool { kind != .explain }

    /// The notes as the staff and the answer checking expect them.
    var readingSteps: [ReadingStep] {
        notes.compactMap(LessonNotation.pitch(from:)).enumerated().map { index, pitch in
            let note = Note(pitch: pitch, staff: staff, position: NotePosition(beat: Double(index) + 1))
            return ReadingStep(measureIndex: 0, measureNumber: 0, beat: Double(index) + 1, globalBeat: Double(index),
                               notes: [note], heldBeats: 1)
        }
    }

    /// The MIDI numbers of the keys lit during an explanation.
    var litMidiKeys: Set<Int> {
        Set((litKeys ?? notes).compactMap(LessonNotation.pitch(from:)).map { Int($0.midiNoteNumber) })
    }
}

struct Lesson: Identifiable {
    let id: String
    let title: String
    let summary: String
    let steps: [LessonStep]

    /// Every note the lesson writes or lights, for choosing the keyboard's keys.
    var midiRange: ClosedRange<Int>? {
        let notes = steps.flatMap { $0.notes + ($0.litKeys ?? []) }
            .compactMap(LessonNotation.pitch(from:))
            .map { Int($0.midiNoteNumber) }
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
}
