// MusicXMLParser.swift
// luksMusic
//
// Native MusicXML parser converting standard MusicXML files into luksMusic Score models.

import Foundation

/// Errors that can occur during MusicXML parsing.
enum MusicXMLParserError: LocalizedError {
    case dataCorrupted
    case missingPart
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .dataCorrupted:
            return "The MusicXML file data is invalid or corrupted."
        case .missingPart:
            return "No musical parts found in the MusicXML score."
        case .parsingFailed(let reason):
            return "MusicXML parsing failed: \(reason)"
        }
    }
}

/// Parses MusicXML 3.0/3.1 partwise XML files into luksMusic `Score` and `Measure` models.
///
/// Reads the first part (a piano's two staves). Positions and lengths count the time signature's beat (eighths in
/// 3/8, halves in 2/2) like the rest of the app, and come from each note's `<duration>`, so the hands written one
/// after the other (`<backup>`, `<forward>`), tuplets and ties land where the file puts them. Repeats are read as
/// written. The score keeps the file, which the score viewer draws as is.
final class MusicXMLParser: NSObject, XMLParserDelegate {

    // MARK: - State
    private var scoreTitle: String = "Imported Score"
    private var composer: String = "Unknown"
    private var hasComposer = false
    private var creatorType: String?
    private var currentText: String = ""

    // Score properties
    private var quarterTempo: Double?
    private var timeSignatureTop: Int = 4
    private var timeSignatureBottom: Int = 4
    private var hasTimeSignature = false
    private var keySignatureValue: Int = 0
    private var hasKeySignature = false
    private var divisions: Int = 1 // MusicXML divisions per quarter note

    // Part and measure state
    private var partCount = 0
    private var measures: [Measure] = []
    private var currentMeasureNumber: Int = 0
    private var currentMeasureNotes: [Note] = []
    // Where the next note starts, where the last one started and the furthest point reached, in divisions
    private var position = 0
    private var lastNoteStart = 0
    private var measureEnd = 0
    private var inBackup = false
    private var inForward = false

    // Note state
    private var inNote: Bool = false
    private var isRest: Bool = false
    private var isChord: Bool = false
    private var isGrace: Bool = false
    private var isCue: Bool = false
    private var step: String = "C"
    private var octave: Int = 4
    private var alter: Int = 0
    private var durationDivisions: Int = 0
    private var noteType: String = ""
    private var dots: Int = 0
    private var tieStart: Bool = false
    private var tieStop: Bool = false
    private var actualNotes: Int = 1
    private var normalNotes: Int = 1
    private var fingerNumber: Int?
    private var currentStaff: Staff = .treble
    private var currentVoice: Int = 1

    /// Notes whose tie is still open, by staff and pitch, so the notes tied to them add to how long they are held
    private var openTies: [String: (measure: Int, note: Int)] = [:]

    // MARK: - Public Interface

    /// Parse MusicXML data and return a `Score` object.
    static func parse(data: Data) throws -> Score {
        let parser = MusicXMLParser()
        return try parser.parseData(data)
    }

    /// Parse MusicXML from a local file URL.
    static func parse(url: URL) throws -> Score {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    // MARK: - Internal Parsing

    private func parseData(_ data: Data) throws -> Score {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw xmlParser.parserError ?? MusicXMLParserError.parsingFailed("Unknown XML error")
        }
        guard !measures.isEmpty else {
            throw MusicXMLParserError.missingPart
        }

        // <sound tempo> counts quarters a minute; the player counts the time signature's beat
        let tempo = max(20, Int(((quarterTempo ?? 100) * Double(timeSignatureBottom) / 4.0).rounded()))
        let totalBeats = measures.reduce(0.0) { $0 + $1.beats(timeSignatureTop: timeSignatureTop) }
        let score = Score(
            title: scoreTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            composer: composer.trimmingCharacters(in: .whitespacesAndNewlines),
            difficulty: estimateDifficulty(measures: measures),
            source: .imported,
            tempo: tempo,
            keySignatureValue: keySignatureValue,
            timeSignatureTop: timeSignatureTop,
            timeSignatureBottom: timeSignatureBottom,
            estimatedDuration: totalBeats * 60.0 / Double(tempo),
            measures: measures
        )
        score.musicXMLData = data
        return score
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        if elementName == "part" {
            partCount += 1
        }
        // Only the first part is read
        guard partCount <= 1 else { return }

        switch elementName {
        case "creator":
            creatorType = attributeDict["type"]

        case "measure":
            currentMeasureNumber = Int(attributeDict["number"] ?? "") ?? (measures.count + 1)
            currentMeasureNotes = []
            position = 0
            lastNoteStart = 0
            measureEnd = 0

        case "note":
            inNote = true
            isRest = false
            isChord = false
            isGrace = false
            isCue = false
            step = "C"
            octave = 4
            alter = 0
            durationDivisions = 0
            noteType = ""
            dots = 0
            tieStart = false
            tieStop = false
            actualNotes = 1
            normalNotes = 1
            fingerNumber = nil
            currentStaff = .treble
            currentVoice = 1

        case "rest":
            isRest = true

        case "chord":
            isChord = true

        case "grace":
            isGrace = true

        case "cue":
            isCue = true

        case "dot":
            dots += 1

        case "tie":
            // <tie> is the sound; <tied> repeats it as a notation
            if attributeDict["type"] == "start" { tieStart = true }
            if attributeDict["type"] == "stop" { tieStop = true }

        case "backup":
            inBackup = true

        case "forward":
            inForward = true

        case "sound":
            if quarterTempo == nil, let value = attributeDict["tempo"].flatMap(Double.init), value > 0 {
                quarterTempo = value
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard partCount <= 1 else { return }
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "work-title", "movement-title":
            if !trimmed.isEmpty && scoreTitle == "Imported Score" {
                scoreTitle = trimmed
            }
        case "creator":
            if !trimmed.isEmpty && !hasComposer && (creatorType == nil || creatorType == "composer") {
                composer = trimmed
                hasComposer = true
            }
        case "divisions":
            if let div = Int(trimmed), div > 0 {
                divisions = div
            }
        case "beats":
            if !hasTimeSignature, let beats = Int(trimmed) {
                timeSignatureTop = beats
            }
        case "beat-type":
            if !hasTimeSignature, let beatType = Int(trimmed) {
                timeSignatureBottom = beatType
                hasTimeSignature = true
            }
        case "fifths":
            if !hasKeySignature, let fifths = Int(trimmed) {
                keySignatureValue = fifths
                hasKeySignature = true
            }

        // Note attributes
        case "step":
            step = trimmed
        case "octave":
            octave = Int(trimmed) ?? 4
        case "alter":
            alter = Int(trimmed) ?? Int(Double(trimmed)?.rounded() ?? 0)
        case "duration":
            let value = Int(trimmed) ?? 0
            if inBackup {
                position = max(0, position - value)
            } else if inForward {
                position += value
                measureEnd = max(measureEnd, position)
            } else if inNote {
                durationDivisions = value
            }
        case "backup":
            inBackup = false
        case "forward":
            inForward = false
        case "type":
            if inNote { noteType = trimmed }
        case "actual-notes":
            actualNotes = Int(trimmed) ?? 1
        case "normal-notes":
            normalNotes = Int(trimmed) ?? 1
        case "staff":
            if inNote { currentStaff = trimmed == "1" ? .treble : .bass }
        case "voice":
            if inNote { currentVoice = Int(trimmed) ?? 1 }
        case "fingering":
            fingerNumber = Int(trimmed)

        case "note":
            inNote = false
            buildAndAddNote()

        case "measure":
            let length = beats(measureEnd)
            let measure = Measure(
                number: currentMeasureNumber,
                notes: currentMeasureNotes,
                timeSignatureNumerator: nil,
                timeSignatureDenominator: nil,
                keySignature: KeySignature(rawValue: keySignatureValue),
                tempo: nil,
                // A pickup or the half measure before a repeat lasts what it holds
                length: measureEnd > 0 && abs(length - Double(timeSignatureTop)) > 0.001 ? length : nil
            )
            measures.append(measure)

        default:
            break
        }
    }

    // MARK: - Helpers

    /// Divisions (quarter / `divisions`) in the time signature's beat.
    private func beats(_ divisionCount: Int) -> Double {
        Double(divisionCount) / Double(max(1, divisions)) * Double(timeSignatureBottom) / 4.0
    }

    private func buildAndAddNote() {
        // Grace and cue notes take no time and are not played
        guard !isGrace, !isCue else { return }

        let start = isChord ? lastNoteStart : position
        if !isChord {
            lastNoteStart = position
            position += durationDivisions
            measureEnd = max(measureEnd, position)
        }

        let accidental: Accidental
        switch alter {
        case 1: accidental = .sharp
        case -1: accidental = .flat
        case 2: accidental = .doubleSharp
        case -2: accidental = .doubleFlat
        default: accidental = .natural
        }
        let pitch = Pitch(noteName: NoteName(rawValue: step) ?? .C, octave: octave, accidental: accidental)
        let length = beats(durationDivisions)

        // The held end of a tie adds its length to the note it continues, which stays the one struck
        let tieKey = "\(currentStaff.rawValue)-\(pitch.midiNoteNumber)"
        var continuesTie = false
        if tieStop, !isRest, let open = openTies[tieKey] {
            extendNote(at: open, by: length)
            continuesTie = true
            if !tieStart {
                openTies[tieKey] = nil
            }
        }

        let note = Note(
            pitch: pitch,
            duration: noteDuration(),
            velocity: isRest ? 0 : 80,
            isRest: isRest,
            isTied: tieStart && !isRest,
            staff: currentStaff,
            voice: currentVoice,
            fingerNumber: fingerNumber,
            isTriplet: actualNotes == 3 && normalNotes == 2,
            position: NotePosition(beat: 1.0 + beats(start)),
            length: isRest ? nil : length,
            isTieContinuation: continuesTie ? true : nil
        )
        currentMeasureNotes.append(note)

        if tieStart, !isRest, !continuesTie {
            openTies[tieKey] = (measures.count, currentMeasureNotes.count - 1)
        }
    }

    /// Adds `beats` to how long the note at `location` is held (in this measure or an earlier one).
    private func extendNote(at location: (measure: Int, note: Int), by beats: Double) {
        if location.measure == measures.count {
            guard location.note < currentMeasureNotes.count else { return }
            currentMeasureNotes[location.note].length = (currentMeasureNotes[location.note].length ?? 0) + beats
        } else if location.measure < measures.count, location.note < measures[location.measure].notes.count {
            measures[location.measure].notes[location.note].length = (measures[location.measure].notes[location.note].length ?? 0) + beats
        }
    }

    /// The written value from `<type>` and its dots, or the closest one to `<duration>` when there is no type.
    private func noteDuration() -> NoteDuration {
        switch noteType {
        case "whole", "breve": return .whole
        case "half": return dots > 0 ? .dottedHalf : .half
        case "quarter": return dots > 0 ? .dottedQuarter : .quarter
        case "eighth": return dots > 0 ? .dottedEighth : .eighth
        case "16th": return dots > 0 ? .dottedSixteenth : .sixteenth
        case "32nd", "64th", "128th": return .thirtySecond
        default:
            let quarters = Double(durationDivisions) / Double(max(1, divisions)) * Double(actualNotes) / Double(max(1, normalNotes))
            return NoteDuration.allCases.min { abs($0.beats - quarters) < abs($1.beats - quarters) } ?? .quarter
        }
    }

    private func estimateDifficulty(measures: [Measure]) -> Difficulty {
        let noteCount = measures.reduce(0) { $0 + $1.notes.count }
        let hasSixteenths = measures.contains { $0.notes.contains { $0.duration == .sixteenth || $0.duration == .thirtySecond } }
        let hasComplexKey = abs(keySignatureValue) >= 3

        if noteCount > 300 || (hasSixteenths && hasComplexKey) {
            return .advanced
        } else if noteCount > 150 || hasSixteenths || hasComplexKey {
            return .intermediate
        } else {
            return .beginner
        }
    }
}
