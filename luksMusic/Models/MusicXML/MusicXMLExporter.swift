// MusicXMLExporter.swift
// luksMusic
//
// Generates standard MusicXML 3.1 files from Score models, for export to notation apps
// and for the in-app score renderer.

import Foundation

/// Exporter that serializes a `Score` into standard MusicXML format.
final class MusicXMLExporter {

    /// Divisions per quarter note: divisible by 3 (triplets) and 8 (32nd notes).
    private static let divisions = 24

    /// Notes that start together with the same length and tuplet, written as one chord.
    private struct Event {
        let onset: Int
        let length: Int
        let isTriplet: Bool
        var notes: [Note]
    }

    /// Export a score as a valid MusicXML XML string.
    static func export(_ score: Score) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="3.1">
          <work>
            <work-title>\(escapeXML(score.title))</work-title>
          </work>
          <identification>
            <creator type="composer">\(escapeXML(score.composer))</creator>
            <encoding>
              <software>luksMusic iOS</software>
              <encoding-date>\(ISO8601DateFormatter().string(from: Date()))</encoding-date>
            </encoding>
          </identification>
          <part-list>
            <score-part id="P1">
              <part-name>Piano</part-name>
              <score-instrument id="P1-I1">
                <instrument-name>Acoustic Grand Piano</instrument-name>
              </score-instrument>
              <midi-instrument id="P1-I1">
                <midi-channel>1</midi-channel>
                <midi-program>1</midi-program>
              </midi-instrument>
            </score-part>
          </part-list>
          <part id="P1">
        """

        let measures = score.measures
        let totalMeasures = max(1, measures.count)
        let measureLength = max(1, score.timeSignatureTop * divisions * 4 / max(1, score.timeSignatureBottom))
        // Note positions count beats of the time signature's unit (eighths in 3/8); durations count quarters
        let beatLength = Double(divisions) * 4.0 / Double(max(1, score.timeSignatureBottom))
        // The tempo counts the same beat unit; <sound tempo> is always in quarter notes per minute
        let beatUnit = ["2": "half", "8": "eighth", "16": "16th"][String(score.timeSignatureBottom)] ?? "quarter"
        let quarterTempo = Double(score.tempo) * 4.0 / Double(max(1, score.timeSignatureBottom))

        for (index, measure) in measures.enumerated() {
            let measureNum = measure.number > 0 ? measure.number : (index + 1)
            xml += "\n    <measure number=\"\(measureNum)\">"

            // First measure includes attributes
            if index == 0 {
                xml += """

                      <attributes>
                        <divisions>\(divisions)</divisions>
                        <key>
                          <fifths>\(score.keySignatureValue)</fifths>
                        </key>
                        <time>
                          <beats>\(score.timeSignatureTop)</beats>
                          <beat-type>\(score.timeSignatureBottom)</beat-type>
                        </time>
                        <staves>2</staves>
                        <clef number="1">
                          <sign>G</sign>
                          <line>2</line>
                        </clef>
                        <clef number="2">
                          <sign>F</sign>
                          <line>4</line>
                        </clef>
                      </attributes>
                      <direction placement="above">
                        <direction-type>
                          <metronome>
                            <beat-unit>\(beatUnit)</beat-unit>
                            <per-minute>\(score.tempo)</per-minute>
                          </metronome>
                        </direction-type>
                        <staff>1</staff>
                        <sound tempo=\"\(quarterTempo)\"/>
                      </direction>
                """
            }

            // Each staff is written as one or more voices; <backup> returns to the start of the measure
            // before the next voice, since MusicXML reads the notes of a measure in time order.
            let voices = staffVoices(measure.trebleNotes, staff: 1, firstVoice: 1, measureLength: measureLength, beatLength: beatLength)
                + staffVoices(measure.bassNotes, staff: 2, firstVoice: 5, measureLength: measureLength, beatLength: beatLength)
            for (voiceIndex, voice) in voices.enumerated() {
                xml += voice.xml
                if voiceIndex < voices.count - 1 && voice.end > 0 {
                    xml += "\n      <backup>\n        <duration>\(voice.end)</duration>\n      </backup>"
                }
            }

            // Barlines
            if measure.barlineType == .final || index == totalMeasures - 1 {
                xml += """

                      <barline location="right">
                        <bar-style>light-heavy</bar-style>
                      </barline>
                """
            }

            xml += "\n    </measure>"
        }

        xml += """

          </part>
        </score-partwise>
        """

        return xml
    }

    /// Export score to a temporary or document file URL.
    static func exportToFile(_ score: Score, to fileURL: URL) throws {
        let xmlString = export(score)
        guard let data = xmlString.data(using: .utf8) else {
            throw MusicXMLParserError.parsingFailed("Failed to encode XML to UTF-8")
        }
        try data.write(to: fileURL)
    }

    // MARK: - Voices

    /// Splits a staff's notes into voices so overlapping notes never share one, and writes each voice.
    private static func staffVoices(_ notes: [Note], staff: Int, firstVoice: Int, measureLength: Int, beatLength: Double) -> [(xml: String, end: Int)] {
        var events: [Event] = []
        for note in notes.sorted(by: { $0.position.beat < $1.position.beat }) {
            let onset = max(0, Int(((note.position.beat - 1.0) * beatLength).rounded()))
            let written = max(1, Int((note.duration.beats * (note.isTriplet ? 2.0 / 3.0 : 1.0) * Double(divisions)).rounded()))
            // Never let a note run past the barline, which would shift every following measure
            let length = min(written, max(1, measureLength - onset))
            if let i = events.firstIndex(where: { $0.onset == onset && $0.length == length && $0.isTriplet == note.isTriplet }) {
                events[i].notes.append(note)
            } else {
                events.append(Event(onset: onset, length: length, isTriplet: note.isTriplet, notes: [note]))
            }
        }
        events.sort { $0.onset < $1.onset }

        var lanes: [[Event]] = []
        var laneEnds: [Int] = []
        for event in events {
            if let lane = laneEnds.firstIndex(where: { $0 <= event.onset }) {
                lanes[lane].append(event)
                laneEnds[lane] = event.onset + event.length
            } else {
                lanes.append([event])
                laneEnds.append(event.onset + event.length)
            }
        }

        // An empty staff still shows a whole-measure rest
        if lanes.isEmpty {
            let rest = "\n      <note>\n        <rest measure=\"yes\"/>\n        <duration>\(measureLength)</duration>\n        <voice>\(firstVoice)</voice>\n        <staff>\(staff)</staff>\n      </note>"
            return [(rest, measureLength)]
        }

        return lanes.enumerated().map { (laneIndex, lane) -> (xml: String, end: Int) in
            let voice = firstVoice + laneIndex
            var xml = ""
            var position = 0
            var tupletProgress = 0
            for event in lane {
                if event.onset > position {
                    // Gaps in the main voice read as rests; extra voices just skip ahead
                    xml += laneIndex == 0
                        ? restsXML(event.onset - position, voice: voice, staff: staff)
                        : forwardXML(event.onset - position, voice: voice, staff: staff)
                }

                var tuplet: String? = nil
                if event.isTriplet {
                    if tupletProgress == 0 { tuplet = "start" }
                    tupletProgress += event.length
                    if tupletProgress >= event.length * 3 {
                        tuplet = tuplet == "start" ? nil : "stop"
                        tupletProgress = 0
                    }
                } else {
                    tupletProgress = 0
                }

                xml += eventXML(event, voice: voice, staff: staff, tuplet: tuplet)
                position = event.onset + event.length
            }
            if laneIndex == 0 && position < measureLength {
                xml += restsXML(measureLength - position, voice: voice, staff: staff)
                position = measureLength
            }
            return (xml, position)
        }
    }

    private static func eventXML(_ event: Event, voice: Int, staff: Int, tuplet: String?) -> String {
        var xml = ""
        let lyric = event.notes.compactMap(\.lyric).first
        for (i, note) in event.notes.enumerated() {
            xml += "\n      <note>"
            if i > 0 {
                xml += "\n        <chord/>"
            }
            if note.isRest {
                xml += "\n        <rest/>"
            } else {
                xml += "\n        <pitch>\n          <step>\(note.pitch.noteName.rawValue)</step>"
                let alter = note.pitch.accidental.semitoneOffset
                if alter != 0 {
                    xml += "\n          <alter>\(alter)</alter>"
                }
                xml += "\n          <octave>\(note.pitch.octave)</octave>\n        </pitch>"
            }
            xml += "\n        <duration>\(event.length)</duration>"
            xml += "\n        <voice>\(voice)</voice>"
            xml += "\n        <type>\(xmlType(for: note.duration))</type>"
            if isDotted(note.duration) {
                xml += "\n        <dot/>"
            }
            if event.isTriplet {
                xml += "\n        <time-modification>\n          <actual-notes>3</actual-notes>\n          <normal-notes>2</normal-notes>\n        </time-modification>"
            }
            xml += "\n        <staff>\(staff)</staff>"

            var notations = ""
            if i == 0, let tuplet {
                notations += "\n          <tuplet type=\"\(tuplet)\" bracket=\"no\"/>"
            }
            if let finger = note.fingerNumber {
                notations += "\n          <technical>\n            <fingering>\(finger)</fingering>\n          </technical>"
            }
            if !notations.isEmpty {
                xml += "\n        <notations>\(notations)\n        </notations>"
            }
            if i == 0, let lyric {
                xml += "\n        <lyric number=\"1\">\n          <syllabic>single</syllabic>\n          <text>\(escapeXML(lyric.trimmingCharacters(in: .whitespaces)))</text>\n        </lyric>"
            }
            xml += "\n      </note>"
        }
        return xml
    }

    /// Rests filling `length` divisions with standard values; any remainder becomes an invisible skip.
    private static func restsXML(_ length: Int, voice: Int, staff: Int) -> String {
        let values: [(length: Int, type: String, dotted: Bool)] = [
            (96, "whole", false), (72, "half", true), (48, "half", false), (36, "quarter", true),
            (24, "quarter", false), (18, "eighth", true), (12, "eighth", false), (9, "16th", true),
            (6, "16th", false), (3, "32nd", false)
        ]
        var remaining = length
        var xml = ""
        for value in values {
            while remaining >= value.length {
                xml += "\n      <note>\n        <rest/>\n        <duration>\(value.length)</duration>\n        <voice>\(voice)</voice>\n        <type>\(value.type)</type>"
                if value.dotted {
                    xml += "\n        <dot/>"
                }
                xml += "\n        <staff>\(staff)</staff>\n      </note>"
                remaining -= value.length
            }
        }
        if remaining > 0 {
            xml += forwardXML(remaining, voice: voice, staff: staff)
        }
        return xml
    }

    private static func forwardXML(_ length: Int, voice: Int, staff: Int) -> String {
        "\n      <forward>\n        <duration>\(length)</duration>\n        <voice>\(voice)</voice>\n        <staff>\(staff)</staff>\n      </forward>"
    }

    // MARK: - Private Helpers

    private static func xmlType(for duration: NoteDuration) -> String {
        switch duration {
        case .whole: return "whole"
        case .dottedHalf, .half: return "half"
        case .dottedQuarter, .quarter: return "quarter"
        case .dottedEighth, .eighth: return "eighth"
        case .dottedSixteenth, .sixteenth: return "16th"
        case .thirtySecond: return "32nd"
        }
    }

    private static func isDotted(_ duration: NoteDuration) -> Bool {
        switch duration {
        case .dottedHalf, .dottedQuarter, .dottedEighth, .dottedSixteenth: return true
        default: return false
        }
    }

    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
