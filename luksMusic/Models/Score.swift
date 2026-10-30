// Score.swift
// luksMusic
//
// Core SwiftData model representing a piano score.

import Foundation
import SwiftData

// MARK: - Enums

/// Difficulty level of a musical score.
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"

    var id: String { rawValue }

    /// Name shown in the app (the raw value is what the library stores).
    var displayName: String {
        switch self {
        case .beginner: return "Iniciante"
        case .intermediate: return "Intermediário"
        case .advanced: return "Avançado"
        case .expert: return "Virtuoso"
        }
    }

    /// Display color name (used to resolve SwiftUI Color).
    var colorName: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "yellow"
        case .advanced: return "orange"
        case .expert: return "red"
        }
    }
}

/// How the score was originally added to the library.
enum ScoreSource: String, Codable, CaseIterable, Identifiable {
    case manual = "Manual"
    case imported = "Imported"
    case scanned = "Scanned"

    var id: String { rawValue }

    /// Name shown in the app (the raw value is what the library stores).
    var displayName: String {
        switch self {
        case .manual: return "Criadas no app"
        case .imported: return "Importadas"
        case .scanned: return "Digitalizadas"
        }
    }

    /// SF Symbol name for this source type.
    var iconName: String {
        switch self {
        case .manual: return "pencil"
        case .imported: return "arrow.down.doc"
        case .scanned: return "camera"
        }
    }
}

/// The rendering/highlight state of a note during practice or playback.
enum NotePlaybackState: String, Codable {
    case upcoming
    case current
    case correct
    case incorrect
    case played
}

// MARK: - Score Model (SwiftData)

/// A musical piano score stored in the user's library.
@Model
final class Score {
    var id: UUID
    var title: String
    var composer: String
    var difficulty: Difficulty
    var source: ScoreSource
    var isFavorite: Bool
    var isPublic: Bool = false
    var dateCreated: Date
    var lastModified: Date
    var lastPracticed: Date?
    var estimatedDuration: TimeInterval
    var thumbnailData: Data?

    /// Tempo in BPM (Beats Per Minute).
    var tempo: Int

    /// Key signature: positive = count of sharps, negative = count of flats (0 = C Major / A Minor).
    var keySignatureValue: Int

    /// Time signature numerator (e.g. 4 in 4/4).
    var timeSignatureTop: Int

    /// Time signature denominator (e.g. 4 in 4/4).
    var timeSignatureBottom: Int

    /// JSON-encoded array of `Measure` objects for persistence.
    var measuresData: Data?

    init(
        title: String = "Untitled Piano Piece",
        composer: String = "Anonymous",
        difficulty: Difficulty = .beginner,
        source: ScoreSource = .manual,
        isFavorite: Bool = false,
        isPublic: Bool = false,
        tempo: Int = 120,
        keySignatureValue: Int = 0,
        timeSignatureTop: Int = 4,
        timeSignatureBottom: Int = 4,
        estimatedDuration: TimeInterval = 0,
        measures: [Measure] = []
    ) {
        self.id = UUID()
        self.title = title
        self.composer = composer
        self.difficulty = difficulty
        self.source = source
        self.isFavorite = isFavorite
        self.isPublic = isPublic
        self.dateCreated = Date()
        self.lastModified = Date()
        self.lastPracticed = nil
        self.estimatedDuration = estimatedDuration
        self.thumbnailData = nil
        self.tempo = tempo
        self.keySignatureValue = keySignatureValue
        self.timeSignatureTop = timeSignatureTop
        self.timeSignatureBottom = timeSignatureBottom
        self.measuresData = try? JSONEncoder().encode(measures)
    }

    /// Decoded measures array from JSON.
    var measures: [Measure] {
        get {
            guard let data = measuresData else { return [] }
            return (try? JSONDecoder().decode([Measure].self, from: data)) ?? []
        }
        set {
            measuresData = try? JSONEncoder().encode(newValue)
            lastModified = Date()
        }
    }

    /// Total note count across all measures and staves.
    var totalNoteCount: Int {
        measures.reduce(0) { $0 + $1.notes.filter { !$0.isRest }.count }
    }

    /// Total measure count.
    var measureCount: Int {
        measures.count
    }

    /// Key signature readable name (e.g., "C Major", "G Major", "F Major").
    var keySignatureName: String {
        switch keySignatureValue {
        case 0: return "C Major / A Minor"
        case 1: return "G Major / E Minor (1♯)"
        case 2: return "D Major / B Minor (2♯)"
        case 3: return "A Major / F♯ Minor (3♯)"
        case 4: return "E Major / C♯ Minor (4♯)"
        case 5: return "B Major / G♯ Minor (5♯)"
        case 6: return "F♯ Major / D♯ Minor (6♯)"
        case 7: return "C♯ Major / A♯ Minor (7♯)"
        case -1: return "F Major / D Minor (1♭)"
        case -2: return "B♭ Major / G Minor (2♭)"
        case -3: return "E♭ Major / C Minor (3♭)"
        case -4: return "A♭ Major / F Minor (4♭)"
        case -5: return "D♭ Major / B♭ Minor (5♭)"
        case -6: return "G♭ Major / E♭ Minor (6♭)"
        case -7: return "C♭ Major / A♭ Minor (7♭)"
        default: return "C Major"
        }
    }
}
