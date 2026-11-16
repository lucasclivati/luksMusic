// MusicXMLParser.swift
// luksMusic
//
// Native MusicXML parser converting standard MusicXML files, plain or compressed (.mxl), into luksMusic Score models.

import Foundation

/// Errors that can occur during MusicXML parsing.
enum MusicXMLParserError: LocalizedError {
    case dataCorrupted
    case missingPart
    case missingScoreFile
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .dataCorrupted:
            return "O arquivo MusicXML está danificado ou não é válido."
        case .missingPart:
            return "A partitura MusicXML não tem nenhuma parte."
        case .missingScoreFile:
            return "O arquivo .mxl não contém uma partitura MusicXML."
        case .parsingFailed(let reason):
            return "Não foi possível ler o MusicXML: \(reason)"
        }
    }
}

/// Parses MusicXML 3.0/3.1 partwise XML files into luksMusic `Score` and `Measure` models.
///
/// Positions and lengths count the time signature's beat (eighths in 3/8, halves in 2/2) like the rest of the app,
/// and come from each note's `<duration>`, so the hands written one after the other (`<backup>`, `<forward>`),
/// tuplets and ties land where the file puts them. Repeats are read as written. The score keeps the MusicXML text
/// (the file inside an .mxl), which the score viewer draws as is.
///
/// Every part is played. A part's measures join the first part's in order, and each part counts its own divisions
/// and ties. Staff 1 of a part is the treble staff (the right hand) and any lower staff the bass (the left hand), so a
/// piano duet's two players share the hands. A part on one staff in a score of several parts (a flute, a cello) is
/// one player's line, so it stays on one hand for the whole piece: the bass when its first clef is F, else the treble.
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
    private var divisions: Int = 1 // MusicXML divisions per quarter note, set by each part

    // Part and measure state
    private var scorePartCount = 0
    private var measures: [Measure] = []
    /// Measures read in the current part; its next one joins the measure at this index
    private var partMeasureCount = 0
    /// Where in `measures` the measure being read goes, and how many notes earlier parts left there
    private var measureIndex = 0
    private var measureBase = 0
    private var partStaves = 1
    private var partClefSign: String?
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

    /// Parse MusicXML data, plain or compressed (.mxl), and return a `Score` object.
    static func parse(data: Data) throws -> Score {
        let parser = MusicXMLParser()
        let xml = try data.starts(with: ZipArchive.signature) ? scoreFile(inMXL: data) : data
        return try parser.parseData(xml)
    }

    /// Parse MusicXML (.musicxml, .xml or .mxl) from a local file URL.
    static func parse(url: URL) throws -> Score {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    /// The MusicXML file inside compressed MusicXML (.mxl), a ZIP archive: the one META-INF/container.xml names,
    /// else the first .musicxml or .xml file outside META-INF.
    static func scoreFile(inMXL data: Data) throws -> Data {
        let archive = try ZipArchive(data: data)
        if let container = archive.entry(atPath: "META-INF/container.xml"),
           let path = try MXLContainerReader.rootFilePath(in: archive.contents(of: container)),
           let rootFile = archive.entry(atPath: path) {
            return try archive.contents(of: rootFile)
        }
        guard let file = archive.entries.first(where: { entry in
            let path = entry.path.lowercased()
            return !path.hasPrefix("meta-inf/") && (path.hasSuffix(".musicxml") || path.hasSuffix(".xml"))
        }) else {
            throw MusicXMLParserError.missingScoreFile
        }
        return try archive.contents(of: file)
    }

    // MARK: - Internal Parsing

    /// Reads plain MusicXML; the score keeps `data` as its file.
    private func parseData(_ data: Data) throws -> Score {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw MusicXMLParserError.dataCorrupted
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

        switch elementName {
        case "creator":
            creatorType = attributeDict["type"]

        case "score-part":
            scorePartCount += 1

        case "part":
            // Divisions, staves, clefs and ties belong to the part
            partMeasureCount = 0
            divisions = 1
            partStaves = 1
            partClefSign = nil
            openTies = [:]

        case "measure":
            measureIndex = partMeasureCount
            measureBase = measureIndex < measures.count ? measures[measureIndex].notes.count : 0
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
            currentStaff = singleStaffHand ?? .treble
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
        case "staves":
            partStaves = Int(trimmed) ?? 1
        case "sign":
            if partClefSign == nil { partClefSign = trimmed }

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
            if inNote, singleStaffHand == nil { currentStaff = trimmed == "1" ? .treble : .bass }
        case "voice":
            if inNote { currentVoice = Int(trimmed) ?? 1 }
        case "fingering":
            fingerNumber = Int(trimmed)

        case "note":
            inNote = false
            buildAndAddNote()

        case "measure":
            let end = beats(measureEnd)
            // A pickup or the half measure before a repeat lasts what it holds
            let length: Double? = measureEnd > 0 && abs(end - Double(timeSignatureTop)) > 0.001 ? end : nil
            if measureIndex < measures.count {
                // A later part joins the first part's measure at the same place, which lasts as long as its longest part
                measures[measureIndex].notes += currentMeasureNotes
                if end > measures[measureIndex].beats(timeSignatureTop: timeSignatureTop) + 0.001 {
                    measures[measureIndex].length = length
                }
            } else {
                let measure = Measure(
                    number: currentMeasureNumber,
                    notes: currentMeasureNotes,
                    timeSignatureNumerator: nil,
                    timeSignatureDenominator: nil,
                    keySignature: KeySignature(rawValue: keySignatureValue),
                    tempo: nil,
                    length: length
                )
                measures.append(measure)
            }
            partMeasureCount += 1

        default:
            break
        }
    }

    // MARK: - Helpers

    /// The hand every note of the current part plays when it is a part on one staff in a score of several parts,
    /// chosen by its first clef (its notes' `<staff>` is then ignored). A score of one part reads `<staff>`.
    private var singleStaffHand: Staff? {
        guard scorePartCount > 1, partStaves < 2 else { return nil }
        return partClefSign == "F" ? .bass : .treble
    }

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
            openTies[tieKey] = (measureIndex, measureBase + currentMeasureNotes.count - 1)
        }
    }

    /// Adds `beats` to how long the note at `location` (its index once the measure is in `measures`) is held, in
    /// this measure or an earlier one.
    private func extendNote(at location: (measure: Int, note: Int), by beats: Double) {
        if location.measure == measureIndex {
            let note = location.note - measureBase
            guard note >= 0, note < currentMeasureNotes.count else { return }
            currentMeasureNotes[note].length = (currentMeasureNotes[note].length ?? 0) + beats
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

/// Reads the path of an .mxl's score file from its META-INF/container.xml: the first `<rootfile>`.
private final class MXLContainerReader: NSObject, XMLParserDelegate {
    private var path: String?

    static func rootFilePath(in data: Data) -> String? {
        let reader = MXLContainerReader()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = reader
        _ = xmlParser.parse()
        return reader.path
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard elementName == "rootfile", path == nil, let fullPath = attributeDict["full-path"] else { return }
        path = fullPath
        parser.abortParsing()
    }
}
