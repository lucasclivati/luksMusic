// MusicXMLExporter.swift
// luksMusic
//
// Generates standard MusicXML 3.0/3.1 files from Score models for export to notation apps.

import Foundation

/// Exporter that serializes a `Score` into standard MusicXML format.
final class MusicXMLExporter {
    
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
        
        for (index, measure) in measures.enumerated() {
            let measureNum = measure.number > 0 ? measure.number : (index + 1)
            xml += "\n    <measure number=\"\(measureNum)\">"
            
            // First measure includes attributes
            if index == 0 {
                xml += """
                
                      <attributes>
                        <divisions>4</divisions>
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
                            <beat-unit>quarter</beat-unit>
                            <per-minute>\(score.tempo)</per-minute>
                          </metronome>
                        </direction-type>
                        <sound tempo=\"\(score.tempo)\"/>
                      </direction>
                """
            }
            
            // Notes
            for note in measure.notes {
                xml += "\n      <note>"
                if note.isRest {
                    xml += "\n        <rest/>"
                } else {
                    let alterVal = note.pitch.accidental.semitoneOffset
                    xml += """
                    
                            <pitch>
                              <step>\(note.pitch.noteName.rawValue)</step>
                    """
                    if alterVal != 0 {
                        xml += "\n          <alter>\(alterVal)</alter>"
                    }
                    xml += """
                    
                              <octave>\(note.pitch.octave)</octave>
                            </pitch>
                    """
                }
                
                let divisionsDuration = max(1, Int(note.duration.beats * 4.0))
                xml += "\n        <duration>\(divisionsDuration)</duration>"
                xml += "\n        <voice>\(note.voice)</voice>"
                xml += "\n        <type>\(xmlType(for: note.duration))</type>"
                xml += "\n        <staff>\(note.staff == .treble ? 1 : 2)</staff>"
                
                if let finger = note.fingerNumber {
                    xml += """
                    
                            <notations>
                              <technical>
                                <fingering>\(finger)</fingering>
                              </technical>
                            </notations>
                    """
                }
                
                xml += "\n      </note>"
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
    
    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
