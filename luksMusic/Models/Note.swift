import Foundation

// MARK: - NoteName

/// Represents the seven natural note names in Western music.
enum NoteName: String, Codable, CaseIterable, Comparable {
    case C, D, E, F, G, A, B

    /// The semitone offset from C within a single octave (C = 0, B = 11 before accidentals).
    var baseSemitone: Int {
        switch self {
        case .C: return 0
        case .D: return 2
        case .E: return 4
        case .F: return 5
        case .G: return 7
        case .A: return 9
        case .B: return 11
        }
    }

    static func < (lhs: NoteName, rhs: NoteName) -> Bool {
        lhs.baseSemitone < rhs.baseSemitone
    }
}

// MARK: - Accidental

/// Represents the accidental applied to a note.
enum Accidental: String, Codable, CaseIterable {
    case natural
    case sharp
    case flat
    case doubleSharp
    case doubleFlat

    /// The semitone offset this accidental applies.
    var semitoneOffset: Int {
        switch self {
        case .natural:     return 0
        case .sharp:       return 1
        case .flat:        return -1
        case .doubleSharp: return 2
        case .doubleFlat:  return -2
        }
    }

    /// A display-friendly symbol for rendering.
    var symbol: String {
        switch self {
        case .natural:     return "♮"
        case .sharp:       return "♯"
        case .flat:        return "♭"
        case .doubleSharp: return "𝄪"
        case .doubleFlat:  return "𝄫"
        }
    }
}

// MARK: - KeySignature

/// Key signature representation for piano scores.
enum KeySignature: Int, Codable, CaseIterable {
    case cMajor = 0
    case gMajor = 1
    case dMajor = 2
    case aMajor = 3
    case eMajor = 4
    case bMajor = 5
    case fSharpMajor = 6
    case cSharpMajor = 7
    case fMajor = -1
    case bFlatMajor = -2
    case eFlatMajor = -3
    case aFlatMajor = -4
    case dFlatMajor = -5
    case gFlatMajor = -6
    case cFlatMajor = -7

    /// Display name of key
    var displayName: String {
        switch self {
        case .cMajor: return "C Major / A Minor"
        case .gMajor: return "G Major (1♯)"
        case .dMajor: return "D Major (2♯)"
        case .aMajor: return "A Major (3♯)"
        case .eMajor: return "E Major (4♯)"
        case .bMajor: return "B Major (5♯)"
        case .fSharpMajor: return "F♯ Major (6♯)"
        case .cSharpMajor: return "C♯ Major (7♯)"
        case .fMajor: return "F Major (1♭)"
        case .bFlatMajor: return "B♭ Major (2♭)"
        case .eFlatMajor: return "E♭ Major (3♭)"
        case .aFlatMajor: return "A♭ Major (4♭)"
        case .dFlatMajor: return "D♭ Major (5♭)"
        case .gFlatMajor: return "G♭ Major (6♭)"
        case .cFlatMajor: return "C♭ Major (7♭)"
        }
    }

    /// Number of sharps (>0) or flats (<0)
    var accidentalCount: Int {
        rawValue
    }
}

// MARK: - Pitch

/// Represents the absolute pitch of a note, combining note name, octave, and accidental.
///
/// Uses scientific pitch notation where middle C is C4.
struct Pitch: Codable, Hashable {
    /// The base note name (C through B).
    var noteName: NoteName

    /// The octave in scientific pitch notation (middle C = octave 4).
    var octave: Int

    /// The accidental modifier applied to the note.
    var accidental: Accidental

    /// The MIDI note number (0–127) corresponding to this pitch.
    ///
    /// Calculated as `(octave + 1) * 12 + baseSemitone + accidentalOffset`.
    /// Middle C (C4) equals MIDI note 60.
    var midiNoteNumber: UInt8 {
        let raw = (octave + 1) * 12 + noteName.baseSemitone + accidental.semitoneOffset
        return UInt8(clamping: max(0, min(127, raw)))
    }

    /// A human-readable description such as "C♯4" or "B♭3".
    var displayName: String {
        let accidentalStr = accidental == .natural ? "" : accidental.symbol
        return "\(noteName.rawValue)\(accidentalStr)\(octave)"
    }

    /// The frequency in Hz using A4 = 440 Hz equal temperament.
    var frequency: Double {
        let midiDouble = Double(midiNoteNumber)
        return 440.0 * pow(2.0, (midiDouble - 69.0) / 12.0)
    }

    init(noteName: NoteName, octave: Int, accidental: Accidental = .natural) {
        self.noteName = noteName
        self.octave = octave
        self.accidental = accidental
    }
}

// MARK: - NoteDuration

/// Represents the rhythmic duration of a note or rest.
enum NoteDuration: String, Codable, CaseIterable {
    case whole
    case dottedHalf
    case half
    case dottedQuarter
    case quarter
    case dottedEighth
    case eighth
    case dottedSixteenth
    case sixteenth
    case thirtySecond

    /// Duration expressed as a fraction of a whole note (1.0 = whole note).
    var relativeDuration: Double {
        switch self {
        case .whole:            return 1.0
        case .dottedHalf:       return 0.75
        case .half:             return 0.5
        case .dottedQuarter:    return 0.375
        case .quarter:          return 0.25
        case .dottedEighth:     return 0.1875
        case .eighth:           return 0.125
        case .dottedSixteenth:  return 0.09375
        case .sixteenth:        return 0.0625
        case .thirtySecond:     return 0.03125
        }
    }

    /// The number of beats this duration occupies in 4/4 time.
    var beats: Double {
        relativeDuration * 4.0
    }

    /// A display-friendly name.
    var displayName: String {
        switch self {
        case .whole:            return "Whole"
        case .dottedHalf:       return "Dotted Half"
        case .half:             return "Half"
        case .dottedQuarter:    return "Dotted Quarter"
        case .quarter:          return "Quarter"
        case .dottedEighth:     return "Dotted Eighth"
        case .eighth:           return "Eighth"
        case .dottedSixteenth:  return "Dotted Sixteenth"
        case .sixteenth:        return "Sixteenth"
        case .thirtySecond:     return "Thirty-Second"
        }
    }
}

// MARK: - Staff

/// Identifies which staff a note belongs to on the piano grand staff.
enum Staff: String, Codable, CaseIterable {
    /// The upper staff, typically played by the right hand.
    case treble
    /// The lower staff, typically played by the left hand.
    case bass
}

// MARK: - Articulation

/// Musical articulation markings that affect how a note is performed.
enum Articulation: String, Codable, CaseIterable {
    case staccato
    case legato
    case accent
    case tenuto
    case fermata
    case marcato
    case staccatissimo
    case portato
    case tremoloSingle
    case tremoloDouble
    case trill

    /// The symbol or abbreviation used in notation.
    var symbol: String {
        switch self {
        case .staccato:        return "•"
        case .legato:          return "⁀"
        case .accent:          return ">"
        case .tenuto:          return "–"
        case .fermata:         return "𝄐"
        case .marcato:         return "^"
        case .staccatissimo:   return "▾"
        case .portato:         return "–•"
        case .tremoloSingle:   return "/"
        case .tremoloDouble:   return "//"
        case .trill:           return "tr"
        }
    }
}

// MARK: - Dynamic

/// Musical dynamic markings indicating volume or intensity.
enum Dynamic: String, Codable, CaseIterable, Comparable {
    case ppp
    case pp
    case p
    case mp
    case mf
    case f
    case ff
    case fff
    case sfz
    case sfp
    case fp
    case rfz
    case crescendo
    case decrescendo

    /// Approximate MIDI velocity (0–127) for this dynamic level.
    var midiVelocity: Int {
        switch self {
        case .ppp:          return 16
        case .pp:           return 33
        case .p:            return 49
        case .mp:           return 64
        case .mf:           return 80
        case .f:            return 96
        case .ff:           return 112
        case .fff:          return 127
        case .sfz:          return 120
        case .sfp:          return 100
        case .fp:           return 96
        case .rfz:          return 112
        case .crescendo:    return 80
        case .decrescendo:  return 64
        }
    }

    /// Display-friendly text for the dynamic marking.
    var displayName: String {
        rawValue
    }

    private var sortOrder: Int {
        switch self {
        case .ppp: return 0
        case .pp: return 1
        case .p: return 2
        case .mp: return 3
        case .mf: return 4
        case .f: return 5
        case .ff: return 6
        case .fff: return 7
        case .sfz: return 8
        case .sfp: return 9
        case .fp: return 10
        case .rfz: return 11
        case .crescendo: return 12
        case .decrescendo: return 13
        }
    }

    static func < (lhs: Dynamic, rhs: Dynamic) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - NotePosition

/// Represents the rhythmic position of a note within its measure.
struct NotePosition: Codable, Hashable, Comparable {
    /// The beat position within the measure (1-based, e.g., 1.0 = beat 1, 2.5 = the "and" of beat 2).
    var beat: Double

    static func < (lhs: NotePosition, rhs: NotePosition) -> Bool {
        lhs.beat < rhs.beat
    }
}

// MARK: - Note

/// Represents a single musical note (or rest) within a piano score.
///
/// Each note carries pitch, duration, articulation, dynamics, and positional
/// information needed for both notation rendering and MIDI playback.
struct Note: Identifiable, Codable, Hashable {
    /// Unique identifier for this note.
    var id: UUID

    /// The pitch of the note (ignored if `isRest` is true).
    var pitch: Pitch

    /// The rhythmic duration of this note or rest.
    var duration: NoteDuration

    /// MIDI velocity controlling the loudness of the note (0–127).
    var velocity: Int

    /// Whether this element is a rest rather than a sounding note.
    var isRest: Bool

    /// Whether this note is tied to the following note of the same pitch.
    var isTied: Bool

    /// Which staff of the piano grand staff this note belongs to.
    var staff: Staff

    /// The voice number (1–4) for polyphonic writing on a single staff.
    var voice: Int

    /// Optional articulation marking affecting performance.
    var articulation: Articulation?

    /// Optional dynamic marking indicating volume.
    var dynamic: Dynamic?

    /// Optional fingering suggestion (1 = thumb, 5 = pinky).
    var fingerNumber: Int?

    /// The rhythmic position of this note within its measure.
    var position: NotePosition

    /// The MIDI note number (0–127) computed from the pitch.
    ///
    /// Returns 0 for rests.
    var midiNote: UInt8 {
        isRest ? 0 : pitch.midiNoteNumber
    }

    /// Calculated staff position relative to the middle line of the staff.
    /// For Treble clef, middle line is B4 (MIDI 71).
    /// For Bass clef, middle line is D3 (MIDI 50).
    var staffPosition: Int {
        guard !isRest else { return 0 }
        let midi = Int(midiNote)
        if staff == .treble {
            // E4 (MIDI 64) is line 1 (bottom). B4 (MIDI 71) is line 3 (center).
            // Let's compute diatonic step from C4 (MIDI 60 = -2 step below bottom line)
            return diatonicStep(from: 71, targetMIDI: midi)
        } else {
            // G2 (MIDI 43) is line 1. D3 (MIDI 50) is line 3 (center).
            return diatonicStep(from: 50, targetMIDI: midi)
        }
    }

    /// Helper converting MIDI pitch difference to diatonic staff line/space difference.
    private func diatonicStep(from centerMIDI: Int, targetMIDI: Int) -> Int {
        let diatonicOffsets = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6] // semitones to diatonic steps
        let diff = targetMIDI - centerMIDI
        let octaves = diff >= 0 ? diff / 12 : (diff - 11) / 12
        let semitoneInOct = ((diff % 12) + 12) % 12
        return octaves * 7 + diatonicOffsets[semitoneInOct]
    }

    /// Whether note stem should point up (true) or down (false) based on staff position.
    var stemUp: Bool {
        staffPosition < 0
    }

    /// Number of ledger lines needed above staff
    var ledgerLinesAbove: Int {
        if staffPosition > 4 {
            return (staffPosition - 4 + 1) / 2
        }
        return 0
    }

    /// Number of ledger lines needed below staff
    var ledgerLinesBelow: Int {
        if staffPosition < -4 {
            return (abs(staffPosition) - 4 + 1) / 2
        }
        return 0
    }

    /// The duration of this note in seconds at the given tempo (BPM).
    func durationInSeconds(tempo: Int) -> Double {
        let beatsPerSecond = Double(tempo) / 60.0
        return duration.beats / beatsPerSecond
    }

    init(
        id: UUID = UUID(),
        pitch: Pitch,
        duration: NoteDuration = .quarter,
        velocity: Int = 80,
        isRest: Bool = false,
        isTied: Bool = false,
        staff: Staff = .treble,
        voice: Int = 1,
        articulation: Articulation? = nil,
        dynamic: Dynamic? = nil,
        fingerNumber: Int? = nil,
        position: NotePosition = NotePosition(beat: 1.0)
    ) {
        self.id = id
        self.pitch = pitch
        self.duration = duration
        self.velocity = min(127, max(0, velocity))
        self.isRest = isRest
        self.isTied = isTied
        self.staff = staff
        self.voice = min(4, max(1, voice))
        self.articulation = articulation
        self.dynamic = dynamic
        self.fingerNumber = fingerNumber.map { min(5, max(1, $0)) }
        self.position = position
    }

    /// Creates a rest of the specified duration.
    static func rest(
        duration: NoteDuration = .quarter,
        staff: Staff = .treble,
        voice: Int = 1,
        position: NotePosition = NotePosition(beat: 1.0)
    ) -> Note {
        Note(
            pitch: Pitch(noteName: .C, octave: 4),
            duration: duration,
            velocity: 0,
            isRest: true,
            staff: staff,
            voice: voice,
            position: position
        )
    }
}
