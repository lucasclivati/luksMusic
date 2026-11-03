// MusicXMLParserTests.swift
// luksMusicTests
//
// The MusicXML reader against small hand-written files and the public-domain pieces the app seeds.

import XCTest
@testable import luksMusic

final class MusicXMLParserTests: XCTestCase {

    /// Wraps measures in a one-part piano score.
    private func score(_ measures: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="3.1">
          <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
          <part id="P1">\(measures)</part>
        </score-partwise>
        """
    }

    /// The left hand comes after <backup>, so it starts at the barline; a tie holds the note over the next measure.
    func testLeftHandAfterBackupStartsAtTheBarline() throws {
        let xml = score("""
        <measure number="1">
          <attributes><divisions>2</divisions><key><fifths>0</fifths></key>
            <time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves></attributes>
          <direction><sound tempo="96"/></direction>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>half</type><staff>1</staff></note>
          <note><pitch><step>G</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>half</type><staff>1</staff></note>
          <backup><duration>8</duration></backup>
          <note><pitch><step>C</step><octave>3</octave></pitch><duration>2</duration><voice>5</voice><type>quarter</type><staff>2</staff></note>
          <note><chord/><pitch><step>E</step><octave>3</octave></pitch><duration>2</duration><voice>5</voice><type>quarter</type><staff>2</staff></note>
          <note><rest/><duration>2</duration><voice>5</voice><type>quarter</type><staff>2</staff></note>
          <note><pitch><step>G</step><octave>2</octave></pitch><duration>4</duration><tie type="start"/><voice>5</voice><type>half</type><staff>2</staff></note>
        </measure>
        <measure number="2">
          <note><rest measure="yes"/><duration>8</duration><voice>1</voice><staff>1</staff></note>
          <backup><duration>8</duration></backup>
          <note><pitch><step>G</step><octave>2</octave></pitch><duration>8</duration><tie type="stop"/><voice>5</voice><type>whole</type><staff>2</staff></note>
        </measure>
        """)
        let parsed = try MusicXMLParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(parsed.tempo, 96)
        let first = parsed.measures[0]
        XCTAssertNil(first.length)
        XCTAssertEqual(first.notes.filter { $0.staff == .treble }.map(\.position.beat), [1, 3])
        let bass = first.notes.filter { $0.staff == .bass && !$0.isRest }
        XCTAssertEqual(bass.map(\.position.beat), [1, 1, 3])
        // The tied G2 is held for its half note and the whole note after it, which is not struck again
        XCTAssertEqual(bass.last?.length, 6)
        let held = parsed.measures[1].notes.first { $0.staff == .bass }
        XCTAssertEqual(held?.isTieContinuation, true)
        XCTAssertNotNil(parsed.originalMusicXML)
    }

    /// 3/8 counts eighths: a two-sixteenth pickup lasts one beat, tuplets get exact positions, tempo counts eighths.
    func testPickupAndTupletsCountTheTimeSignaturesBeat() throws {
        let xml = score("""
        <measure number="0" implicit="yes">
          <attributes><divisions>12</divisions><key><fifths>0</fifths></key>
            <time><beats>3</beats><beat-type>8</beat-type></time></attributes>
          <direction><sound tempo="60"/></direction>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>3</duration><voice>1</voice><type>16th</type></note>
          <note><pitch><step>D</step><alter>1</alter><octave>5</octave></pitch><duration>3</duration><voice>1</voice><type>16th</type></note>
        </measure>
        <measure number="1">
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>16th</type>
            <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
          <note><pitch><step>D</step><alter>1</alter><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>16th</type>
            <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>16th</type>
            <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
          <note><pitch><step>B</step><octave>4</octave></pitch><duration>12</duration><voice>1</voice><type>quarter</type></note>
        </measure>
        """)
        let parsed = try MusicXMLParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(parsed.timeSignatureTop, 3)
        XCTAssertEqual(parsed.timeSignatureBottom, 8)
        XCTAssertEqual(parsed.tempo, 120)

        let pickup = parsed.measures[0]
        XCTAssertEqual(pickup.length, 1)
        XCTAssertEqual(pickup.notes.map(\.position.beat), [1, 1.5])
        XCTAssertEqual(pickup.notes[1].pitch.accidental, .sharp)

        let measure = parsed.measures[1]
        XCTAssertNil(measure.length)
        let beats = measure.notes.map(\.position.beat)
        for (beat, expected) in zip(beats, [1, 4.0 / 3.0, 5.0 / 3.0, 2]) {
            XCTAssertEqual(beat, expected, accuracy: 0.0001)
        }
        XCTAssertTrue(measure.notes[0].isTriplet)
        XCTAssertEqual(measure.notes[0].heldBeats(beatUnit: 8), 1.0 / 3.0, accuracy: 0.0001)
    }

    /// The seeded pieces read whole: every measure and note of the file, each note inside its measure.
    func testSamplePiecesReadWhole() throws {
        // Measures and notes (not rests or grace notes) of each file, from tools/prepare_sample_scores.py
        let expected: [String: (measures: Int, notes: Int)] = [
            "fur-elise": (127, 1037),
            "minuet-in-g": (64, 428),
            "gymnopedie-1": (78, 461),
            "moonlight-sonata-1": (69, 1183),
        ]
        for (file, counts) in expected {
            let url = try XCTUnwrap(Bundle.main.url(forResource: file, withExtension: "musicxml"), file)
            let parsed = try MusicXMLParser.parse(url: url)
            XCTAssertEqual(parsed.measureCount, counts.measures, file)
            XCTAssertEqual(parsed.measures.reduce(0) { $0 + $1.notes.filter { !$0.isRest }.count }, counts.notes, file)
            for measure in parsed.measures {
                let beats = measure.beats(timeSignatureTop: parsed.timeSignatureTop)
                for note in measure.notes {
                    XCTAssertGreaterThanOrEqual(note.position.beat, 1, "\(file) measure \(measure.number)")
                    XCTAssertLessThan(note.position.beat, beats + 1, "\(file) measure \(measure.number)")
                }
            }
        }

        // Für Elise opens on its E5–D♯5 pickup, one eighth long, and plays in eighths at ♩ = 100
        let furElise = try MusicXMLParser.parse(url: try XCTUnwrap(Bundle.main.url(forResource: "fur-elise", withExtension: "musicxml")))
        XCTAssertEqual(furElise.timeSignatureBottom, 8)
        XCTAssertEqual(furElise.tempo, 200)
        XCTAssertEqual(furElise.measures[0].length, 1)
        XCTAssertEqual(furElise.measures[0].notes.filter { !$0.isRest }.map(\.midiNote), [76, 75])
    }
}
