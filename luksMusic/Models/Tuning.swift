// Tuning.swift
// luksMusic
//
// The tuner's music theory, apart from the microphone so it can be tested: frequency to the nearest note and how
// many cents off it is, for any A4 reference, and the guitar's standard tuning.

import Foundation

/// What the tuner tunes: the six guitar strings, or any piano key (chromatic).
enum TunerMode: String, CaseIterable, Identifiable {
    case guitar
    case piano

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guitar: return String(localized: "Violão")
        case .piano: return String(localized: "Piano")
        }
    }

    /// The lowest pitch the microphone listens for: below drop D on the guitar, the piano's A0
    var lowestFrequency: Double {
        switch self {
        case .guitar: return 60
        case .piano: return 26
        }
    }

    /// The highest pitch the microphone listens for: the 12th fret of the high E string, the piano's C8
    var highestFrequency: Double {
        switch self {
        case .guitar: return 1_400
        case .piano: return 4_300
        }
    }
}

/// How far the heard pitch is from a note.
struct TuningReading: Equatable {
    /// The note the pitch is compared with
    let midi: Int
    /// Negative is flat (below the note), positive is sharp
    let cents: Double
    /// The pitch heard
    let frequency: Double
    /// The note's exact pitch at the chosen A4
    let targetFrequency: Double

    /// Within ±5 cents counts as in tune
    static let inTuneCents = 5.0

    var isInTune: Bool { abs(cents) <= Self.inTuneCents }
    var isFlat: Bool { cents < -Self.inTuneCents }
    var isSharp: Bool { cents > Self.inTuneCents }
}

enum Tuning {

    static let defaultA4 = 440.0
    /// The reference A can be set from baroque pitch (415) to a semitone above 440 (466)
    static let a4Range = 415.0...466.0

    /// The piano's keys, A0 to C8
    static let pianoRange = 21...108

    /// Standard guitar tuning, low to high: E2 A2 D3 G3 B3 E4
    static let guitarStrings = [40, 45, 50, 55, 59, 64]

    private static let solfegeNames = ["Dó", "Dó♯", "Ré", "Ré♯", "Mi", "Fá", "Fá♯", "Sol", "Sol♯", "Lá", "Lá♯", "Si"]
    private static let letterNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    /// The exact pitch of a MIDI note when A4 (MIDI 69) is `a4` Hz.
    static func frequency(ofMidi midi: Int, a4: Double = defaultA4) -> Double {
        a4 * pow(2.0, (Double(midi) - 69.0) / 12.0)
    }

    /// Cents from `target` to `frequency` (100 cents to a semitone, 1200 to an octave).
    static func cents(from target: Double, to frequency: Double) -> Double {
        1200.0 * log2(frequency / target)
    }

    /// The nearest note to `frequency` within `range`, and how far off it is. Nil when the pitch is outside the range
    /// by more than half a semitone, or isn't a pitch.
    static func nearestNote(to frequency: Double, a4: Double = defaultA4, in range: ClosedRange<Int> = pianoRange) -> TuningReading? {
        guard frequency > 0, frequency.isFinite, a4 > 0 else { return nil }
        let exact = 69.0 + 12.0 * log2(frequency / a4)
        let midi = Int(exact.rounded())
        guard range.contains(midi) else { return nil }
        let target = Self.frequency(ofMidi: midi, a4: a4)
        return TuningReading(midi: midi, cents: cents(from: target, to: frequency), frequency: frequency, targetFrequency: target)
    }

    /// Index in `guitarStrings` of the string whose pitch is closest to `frequency`.
    static func nearestGuitarString(to frequency: Double, a4: Double = defaultA4) -> Int? {
        guard frequency > 0, frequency.isFinite else { return nil }
        return guitarStrings.indices.min { first, second in
            abs(cents(from: Self.frequency(ofMidi: guitarStrings[first], a4: a4), to: frequency))
                < abs(cents(from: Self.frequency(ofMidi: guitarStrings[second], a4: a4), to: frequency))
        }
    }

    /// The heard pitch against one guitar string, however far off it is (a string can be tuned up from far below).
    static func reading(for frequency: Double, string index: Int, a4: Double = defaultA4) -> TuningReading? {
        guard frequency > 0, frequency.isFinite, guitarStrings.indices.contains(index) else { return nil }
        let midi = guitarStrings[index]
        let target = Self.frequency(ofMidi: midi, a4: a4)
        return TuningReading(midi: midi, cents: cents(from: target, to: frequency), frequency: frequency, targetFrequency: target)
    }

    /// The note's name without its octave: "Mi" in Portuguese, "E" in English.
    static func noteName(_ midi: Int, letters: Bool = AppLanguage.usesLetterNames) -> String {
        let names = letters ? letterNames : solfegeNames
        return names[((midi % 12) + 12) % 12]
    }

    /// The note's octave in scientific pitch notation (middle C is C4).
    static func octave(_ midi: Int) -> Int {
        Int((Double(midi) / 12.0).rounded(.down)) - 1
    }

    /// The A4 reference kept inside the allowed range, in whole hertz.
    static func clampedA4(_ value: Double) -> Double {
        min(a4Range.upperBound, max(a4Range.lowerBound, value.rounded()))
    }
}
