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
final class MusicXMLParser: NSObject, XMLParserDelegate {
    
    // MARK: - State
    private var scoreTitle: String = "Imported Score"
    private var composer: String = "Unknown"
    private var currentElement: String = ""
    private var currentText: String = ""
    
    // Score properties
    private var tempo: Int = 120
    private var timeSignatureTop: Int = 4
    private var timeSignatureBottom: Int = 4
    private var keySignatureValue: Int = 0
    private var divisions: Int = 1 // MusicXML divisions per quarter note
    
    // Measure state
    private var measures: [Measure] = []
    private var currentMeasureNumber: Int = 0
    private var currentMeasureNotes: [Note] = []
    private var currentStaff: Staff = .treble
    private var currentVoice: Int = 1
    
    // Note state
    private var inNote: Bool = false
    private var isRest: Bool = false
    private var isChord: Bool = false
    private var step: String = "C"
    private var octave: Int = 4
    private var alter: Int = 0
    private var durationDivisions: Int = 1
    private var noteType: String = "quarter"
    private var isDotted: Bool = false
    private var isTied: Bool = false
    private var fingerNumber: Int?
    private var currentBeatPosition: Double = 1.0
    
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
        
        let score = Score(
            title: scoreTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            composer: composer.trimmingCharacters(in: .whitespacesAndNewlines),
            difficulty: estimateDifficulty(measures: measures),
            source: .imported,
            tempo: tempo,
            keySignatureValue: keySignatureValue,
            timeSignatureTop: timeSignatureTop,
            timeSignatureBottom: timeSignatureBottom,
            measures: measures
        )
        return score
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        switch elementName {
        case "measure":
            currentMeasureNumber = Int(attributeDict["number"] ?? "\(measures.count + 1)") ?? (measures.count + 1)
            currentMeasureNotes = []
            currentBeatPosition = 1.0
            
        case "note":
            inNote = true
            isRest = false
            isChord = false
            step = "C"
            octave = 4
            alter = 0
            durationDivisions = divisions
            noteType = "quarter"
            isDotted = false
            isTied = false
            fingerNumber = nil
            currentStaff = .treble
            currentVoice = 1
            
        case "rest":
            isRest = true
            
        case "chord":
            isChord = true
            
        case "dot":
            isDotted = true
            
        case "tie", "tied":
            isTied = true
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName {
        case "work-title", "movement-title":
            if !trimmed.isEmpty && scoreTitle == "Imported Score" {
                scoreTitle = trimmed
            }
        case "creator":
            if !trimmed.isEmpty {
                composer = trimmed
            }
        case "divisions":
            if let div = Int(trimmed), div > 0 {
                divisions = div
            }
        case "beats":
            if let beats = Int(trimmed) {
                timeSignatureTop = beats
            }
        case "beat-type":
            if let beatType = Int(trimmed) {
                timeSignatureBottom = beatType
            }
        case "fifths":
            if let fifths = Int(trimmed) {
                keySignatureValue = fifths
            }
        case "sound":
            // Tempo attribute or content
            break
            
        // Note attributes
        case "step":
            step = trimmed
        case "octave":
            octave = Int(trimmed) ?? 4
        case "alter":
            alter = Int(trimmed) ?? 0
        case "duration":
            durationDivisions = Int(trimmed) ?? divisions
        case "type":
            noteType = trimmed
        case "staff":
            if trimmed == "2" {
                currentStaff = .bass
            } else {
                currentStaff = .treble
            }
        case "voice":
            currentVoice = Int(trimmed) ?? 1
        case "fingering":
            fingerNumber = Int(trimmed)
            
        case "note":
            inNote = false
            buildAndAddNote()
            
        case "measure":
            let measure = Measure(
                number: currentMeasureNumber,
                notes: currentMeasureNotes,
                timeSignatureNumerator: nil,
                timeSignatureDenominator: nil,
                keySignature: KeySignature(rawValue: keySignatureValue),
                tempo: nil
            )
            measures.append(measure)
            
        default:
            break
        }
    }
    
    // MARK: - Helpers
    
    private func buildAndAddNote() {
        let noteName = NoteName(rawValue: step) ?? .C
        let accidental: Accidental
        switch alter {
        case 1: accidental = .sharp
        case -1: accidental = .flat
        case 2: accidental = .doubleSharp
        case -2: accidental = .doubleFlat
        default: accidental = .natural
        }
        
        let pitch = Pitch(noteName: noteName, octave: octave, accidental: accidental)
        
        let duration: NoteDuration
        switch noteType {
        case "whole": duration = isDotted ? .whole : .whole
        case "half": duration = isDotted ? .dottedHalf : .half
        case "quarter": duration = isDotted ? .dottedQuarter : .quarter
        case "eighth": duration = isDotted ? .dottedEighth : .eighth
        case "16th", "sixteenth": duration = isDotted ? .dottedSixteenth : .sixteenth
        case "32nd", "thirty-second": duration = .thirtySecond
        default:
            // Fallback from divisions
            let beatFraction = Double(durationDivisions) / Double(max(1, divisions))
            if beatFraction >= 3.5 { duration = .whole }
            else if beatFraction >= 2.5 { duration = .dottedHalf }
            else if beatFraction >= 1.8 { duration = .half }
            else if beatFraction >= 1.3 { duration = .dottedQuarter }
            else if beatFraction >= 0.8 { duration = .quarter }
            else if beatFraction >= 0.4 { duration = .eighth }
            else { duration = .sixteenth }
        }
        
        let note = Note(
            pitch: pitch,
            duration: duration,
            velocity: isRest ? 0 : 80,
            isRest: isRest,
            isTied: isTied,
            staff: currentStaff,
            voice: currentVoice,
            fingerNumber: fingerNumber,
            position: NotePosition(beat: currentBeatPosition)
        )
        
        currentMeasureNotes.append(note)
        
        // If not a chord, advance beat position
        if !isChord {
            currentBeatPosition += duration.beats
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
