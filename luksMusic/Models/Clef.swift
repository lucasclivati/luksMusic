// Clef.swift
// luksMusic
//
// The clefs a staff is written in (sol, fá and dó) and which one each hand's staff shows. The choice is kept per
// hand and shared by the score player and the reading drill: the score's own clefs, one clef throughout, or the
// clef that needs the fewest ledger lines, changing as the music climbs or falls.

import Foundation

enum Clef: String, CaseIterable, Identifiable {
    case treble
    case bass
    /// The C clef on the middle line
    case alto

    var id: String { rawValue }

    /// The clef a piano staff usually has: treble for the right hand, bass for the left
    init(_ staff: Staff) {
        self = staff == .treble ? .treble : .bass
    }

    var displayName: String {
        switch self {
        case .treble: return "Clave de sol"
        case .bass: return "Clave de fá"
        case .alto: return "Clave de dó"
        }
    }

    /// Diatonic steps from C0 to the note on the middle line: B4, D3 and middle C
    var middleLine: Int {
        switch self {
        case .treble: return 34
        case .bass: return 22
        case .alto: return 28
        }
    }

    /// Diatonic steps from the middle line to where the pitch is written (+1 is one step up)
    func position(of pitch: Pitch) -> Int {
        pitch.octave * 7 + pitch.noteName.diatonicIndex - middleLine
    }

    /// Ledger lines the pitch needs above or below the five lines
    func ledgerLines(for pitch: Pitch) -> Int {
        let distance = abs(position(of: pitch))
        return distance >= 6 ? (distance - 4) / 2 : 0
    }

    /// Where the key signature's sharps or flats go, in steps above the bottom line, in the order they are written
    func keySignatureSteps(sharps: Bool) -> [Int] {
        switch (self, sharps) {
        case (.treble, true): return [8, 5, 9, 6, 3, 7, 4]
        case (.treble, false): return [4, 7, 3, 6, 2, 5, 1]
        case (.bass, true): return [6, 3, 7, 4, 1, 5, 2]
        case (.bass, false): return [2, 5, 1, 4, 0, 3, -1]
        case (.alto, true): return [7, 4, 8, 5, 2, 6, 3]
        case (.alto, false): return [3, 6, 2, 5, 1, 4, 0]
        }
    }

    /// The clef that writes the pitches with the fewest ledger lines. Ties keep `usual`, then the other piano clef;
    /// the alto clef is a candidate only when `usesAlto`.
    static func fewestLedgerLines(for pitches: [Pitch], usual: Clef, usesAlto: Bool) -> Clef {
        var candidates: [Clef] = [usual, usual == .bass ? .treble : .bass]
        if usesAlto {
            candidates.append(.alto)
        }
        func total(_ clef: Clef) -> Int {
            pitches.reduce(0) { $0 + clef.ledgerLines(for: $1) }
        }
        return candidates.min { total($0) < total($1) } ?? usual
    }
}

/// Which clef a hand's staff shows.
enum ClefChoice: String, CaseIterable, Identifiable {
    /// The score's own clefs (in the reading drill, sol for the right hand and fá for the left)
    case score
    /// The clef with the fewest ledger lines, changing as the music climbs or falls
    case automatic
    case treble
    case bass
    case alto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .score: return "Original"
        case .automatic: return "Automática"
        case .treble: return "Sol"
        case .bass: return "Fá"
        case .alto: return "Dó"
        }
    }

    var detail: String {
        switch self {
        case .score: return "Como a partitura escreve"
        case .automatic: return "Muda conforme as notas"
        case .treble: return "Clave de sol em tudo"
        case .bass: return "Clave de fá em tudo"
        case .alto: return "Clave de dó em tudo"
        }
    }

    /// The clef shown throughout, for a choice that does not depend on the notes
    var fixedClef: Clef? {
        switch self {
        case .treble: return .treble
        case .bass: return .bass
        case .alto: return .alto
        case .score, .automatic: return nil
        }
    }

    // Remembered choices, shared by the score player and the reading drill
    static let rightHandKey = "clefChoice.right"
    static let leftHandKey = "clefChoice.left"
    /// Whether the automatic choice may use the alto clef besides sol and fá
    static let automaticUsesAltoKey = "clefChoice.automaticUsesAlto"

    /// The remembered choice's key for a hand (the treble staff is the right hand's)
    static func key(for staff: Staff) -> String {
        staff == .treble ? rightHandKey : leftHandKey
    }
}
