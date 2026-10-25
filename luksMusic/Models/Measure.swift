import Foundation

// MARK: - BarlineType

/// The type of barline that appears at the end of a measure.
enum BarlineType: String, Codable, CaseIterable {
    /// A standard single barline.
    case single
    /// A double (thin) barline, often used before key/time signature changes.
    case double
    /// A final barline (thin-thick), marking the end of the piece.
    case final
    /// A repeat-start barline with dots.
    case repeatStart
    /// A repeat-end barline with dots.
    case repeatEnd
    /// A combined repeat-end and repeat-start barline.
    case repeatBoth

    /// The display symbol or description for this barline type.
    var displayName: String {
        switch self {
        case .single:      return "Single"
        case .double:      return "Double"
        case .final:       return "Final"
        case .repeatStart:  return "Repeat Start"
        case .repeatEnd:    return "Repeat End"
        case .repeatBoth:   return "Repeat Both"
        }
    }
}

// MARK: - Measure

/// Represents a single measure (bar) within a piano score.
///
/// A measure contains all notes for both treble and bass staves, along with
/// optional overrides for time signature, key signature, and tempo that
/// differ from the score-level defaults.
struct Measure: Identifiable, Codable, Hashable {
    /// Unique identifier for this measure.
    var id: UUID

    /// The sequential measure number within the score (1-based).
    var number: Int

    /// All notes contained in this measure across both staves and all voices.
    var notes: [Note]

    /// Optional time signature numerator override. `nil` means inherited from the score.
    var timeSignatureNumerator: Int?

    /// Optional time signature denominator override. `nil` means inherited from the score.
    var timeSignatureDenominator: Int?

    /// Optional key signature override. `nil` means inherited from the score.
    var keySignature: KeySignature?

    /// Optional tempo override in BPM. `nil` means inherited from the score.
    var tempo: Int?

    /// The type of barline drawn at the end of this measure.
    var barlineType: BarlineType

    /// Optional rehearsal mark displayed above this measure (e.g., "A", "B", "Coda").
    var rehearsalMark: String?

    // MARK: - Computed Properties

    /// Notes belonging to the treble (upper) staff.
    var trebleNotes: [Note] {
        notes.filter { $0.staff == .treble }
    }

    /// Notes belonging to the bass (lower) staff.
    var bassNotes: [Note] {
        notes.filter { $0.staff == .bass }
    }

    /// Notes sorted chronologically by their beat position within the measure.
    var sortedNotes: [Note] {
        notes.sorted { $0.position.beat < $1.position.beat }
    }

    /// The total number of beats occupied by notes in this measure.
    var totalBeats: Double {
        notes.reduce(0.0) { $0 + $1.duration.beats }
    }

    /// Whether this measure has a time signature change from the score default.
    var hasTimeSignatureChange: Bool {
        timeSignatureNumerator != nil || timeSignatureDenominator != nil
    }

    /// Whether this measure has a key signature change from the score default.
    var hasKeySignatureChange: Bool {
        keySignature != nil
    }

    /// Whether this measure has a tempo change from the score default.
    var hasTempoChange: Bool {
        tempo != nil
    }

    /// Whether this measure contains any notes (excluding rests).
    var hasSoundingNotes: Bool {
        notes.contains { !$0.isRest }
    }

    /// The number of distinct voices used in this measure.
    var voiceCount: Int {
        Set(notes.map(\.voice)).count
    }

    /// Returns notes filtered by a specific voice number.
    /// - Parameter voice: The voice number (1–4).
    /// - Returns: An array of notes belonging to the specified voice.
    func notes(forVoice voice: Int) -> [Note] {
        notes.filter { $0.voice == voice }
    }

    /// Returns notes filtered by staff and voice.
    /// - Parameters:
    ///   - staff: The target staff (treble or bass).
    ///   - voice: The voice number (1–4).
    /// - Returns: Filtered and sorted notes.
    func notes(forStaff staff: Staff, voice: Int) -> [Note] {
        notes
            .filter { $0.staff == staff && $0.voice == voice }
            .sorted { $0.position.beat < $1.position.beat }
    }

    init(
        id: UUID = UUID(),
        number: Int,
        notes: [Note] = [],
        timeSignatureNumerator: Int? = nil,
        timeSignatureDenominator: Int? = nil,
        keySignature: KeySignature? = nil,
        tempo: Int? = nil,
        barlineType: BarlineType = .single,
        rehearsalMark: String? = nil
    ) {
        self.id = id
        self.number = number
        self.notes = notes
        self.timeSignatureNumerator = timeSignatureNumerator
        self.timeSignatureDenominator = timeSignatureDenominator
        self.keySignature = keySignature
        self.tempo = tempo
        self.barlineType = barlineType
        self.rehearsalMark = rehearsalMark
    }

    /// Creates an empty measure with the given number.
    static func empty(number: Int) -> Measure {
        Measure(number: number)
    }
}
