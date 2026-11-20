// MusicXMLParserTest.kt — port of luksMusicTests/MusicXMLParserTests.swift: the MusicXML reader against small
// hand-written files, the .mxl fixtures and the public-domain pieces the app seeds.
package com.lukstrike.luksmusic.core.musicxml

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.BarlineType
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.NoteName
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.Staff
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class MusicXMLParserTest {

    /** Wraps measures in a one-part piano score. */
    private fun score(measures: String) = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="3.1">
          <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
          <part id="P1">$measures</part>
        </score-partwise>
    """.trimIndent()

    private fun parse(xml: String) = MusicXMLParser.parse(xml.toByteArray())

    /** The left hand comes after <backup>, so it starts at the barline; a tie holds the note over the next measure. */
    @Test
    fun leftHandAfterBackupStartsAtTheBarline() {
        val xml = score("""
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
        val (parsed, musicXml) = parse(xml)
        assertEquals(96, parsed.tempo)
        val first = parsed.measures[0]
        assertNull(first.length)
        assertEquals(listOf(1.0, 3.0), first.notes.filter { it.staff == Staff.TREBLE }.map { it.beat })
        val bass = first.notes.filter { it.staff == Staff.BASS && !it.isRest }
        assertEquals(listOf(1.0, 1.0, 3.0), bass.map { it.beat })
        // The tied G2 is held for its half note and the whole note after it, which is not struck again
        assertEquals(6.0, bass.last().length)
        val held = parsed.measures[1].notes.first { it.staff == Staff.BASS }
        assertEquals(true, held.isTieContinuation)
        assertEquals(xml, musicXml)
    }

    /** 3/8 counts eighths: a two-sixteenth pickup lasts one beat, tuplets get exact positions, tempo counts eighths. */
    @Test
    fun pickupAndTupletsCountTheTimeSignaturesBeat() {
        val tuplet = "<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>"
        val xml = score("""
        <measure number="0" implicit="yes">
          <attributes><divisions>12</divisions><key><fifths>0</fifths></key>
            <time><beats>3</beats><beat-type>8</beat-type></time></attributes>
          <direction><sound tempo="60"/></direction>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>3</duration><voice>1</voice><type>16th</type></note>
          <note><pitch><step>D</step><alter>1</alter><octave>5</octave></pitch><duration>3</duration><voice>1</voice><type>16th</type></note>
        </measure>
        <measure number="1">
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>16th</type>$tuplet</note>
          <note><pitch><step>D</step><alter>1</alter><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>16th</type>$tuplet</note>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>16th</type>$tuplet</note>
          <note><pitch><step>B</step><octave>4</octave></pitch><duration>12</duration><voice>1</voice><type>quarter</type></note>
        </measure>
        """)
        val parsed = parse(xml).score
        assertEquals(3, parsed.timeSignatureTop)
        assertEquals(8, parsed.timeSignatureBottom)
        assertEquals(120, parsed.tempo)

        val pickup = parsed.measures[0]
        assertEquals(1.0, pickup.length)
        assertEquals(listOf(1.0, 1.5), pickup.notes.map { it.beat })
        assertEquals(Accidental.SHARP, pickup.notes[1].pitch.accidental)

        val measure = parsed.measures[1]
        assertNull(measure.length)
        val expected = listOf(1.0, 4.0 / 3.0, 5.0 / 3.0, 2.0)
        measure.notes.map { it.beat }.zip(expected).forEach { (beat, want) -> assertEquals(want, beat, 0.0001) }
        assertTrue(measure.notes[0].isTriplet)
        assertEquals(1.0 / 3.0, measure.notes[0].heldBeats(8), 0.0001)
    }

    /** The seeded pieces read whole: every measure and note of the file, each note inside its measure. */
    @Test
    fun samplePiecesReadWhole() {
        // Measures and notes (not rests or grace notes) of each file, from tools/prepare_sample_scores.py
        val expected = mapOf(
            "fur-elise" to (127 to 1037),
            "minuet-in-g" to (64 to 428),
            "gymnopedie-1" to (78 to 461),
            "moonlight-sonata-1" to (69 to 1183),
        )
        for ((file, counts) in expected) {
            val (parsed, musicXml) = MusicXMLParser.parse(TestFiles.sample(file))
            assertEquals(file, counts.first, parsed.measureCount)
            assertEquals(file, counts.second, parsed.measures.sumOf { m -> m.notes.count { !it.isRest } })
            assertTrue(file, musicXml.startsWith("<?xml"))
            for (measure in parsed.measures) {
                val beats = measure.beats(parsed.timeSignatureTop)
                for (note in measure.notes) {
                    assertTrue("$file measure ${measure.number}", note.beat >= 1)
                    assertTrue("$file measure ${measure.number}", note.beat < beats + 1)
                }
            }
        }

        // Für Elise opens on its E5–D♯5 pickup, one eighth long, and plays in eighths at ♩ = 100
        val furElise = MusicXMLParser.parse(TestFiles.sample("fur-elise")).score
        assertEquals(8, furElise.timeSignatureBottom)
        assertEquals(200, furElise.tempo)
        assertEquals(1.0, furElise.measures[0].length)
        assertEquals(listOf(76, 75), furElise.measures[0].notes.filter { !it.isRest }.map { it.midiNote })
    }

    // region Compressed MusicXML and scores of several parts

    /** A piano duet in an .mxl: the second player's notes join the first player's measures, counted in its own
     *  divisions (4 a quarter against 2) and with its tie held over the barline. Staff 1 of each part is the right hand. */
    @Test
    fun duetInAnMxlPlaysBothParts() {
        val data = TestFiles.fixture("duet")
        val (parsed, musicXml) = MusicXMLParser.parse(data)
        assertEquals("Duet", parsed.title)
        assertEquals(120, parsed.tempo)
        assertEquals(2, parsed.measureCount)
        assertTrue(parsed.measures.all { it.length == null })
        // The viewer draws the MusicXML inside the archive
        assertEquals(String(MusicXMLParser.scoreFile(data)), musicXml)
        assertTrue(musicXml.startsWith("<?xml"))

        // Primo's C6 and D6, then Secondo's G3 after its quarter rest
        val first = parsed.measures[0]
        val treble = first.notes.filter { it.staff == Staff.TREBLE && !it.isRest }
        assertEquals(listOf(84, 86, 55), treble.map { it.midiNote })
        assertEquals(listOf(1.0, 3.0, 2.0), treble.map { it.beat })
        // The dotted half G3 is held for the quarter tied to it in the next measure
        assertEquals(listOf(2.0, 2.0, 4.0), treble.map { it.length })
        // Primo's C5 on its staff 2 (in G clef) and Secondo's C2
        val bass = first.notes.filter { it.staff == Staff.BASS && !it.isRest }
        assertEquals(listOf(72, 36), bass.map { it.midiNote })
        assertEquals(listOf(1.0, 1.0), bass.map { it.beat })

        val second = parsed.measures[1]
        val upper = second.notes.filter { it.staff == Staff.TREBLE && !it.isRest }
        assertEquals(listOf(88, 55, 57), upper.map { it.midiNote })
        assertEquals(listOf(1.0, 1.0, 2.0), upper.map { it.beat })
        assertEquals(listOf(false, true, false), upper.map { it.isTieContinuation == true })
        assertEquals(listOf(1.0, 3.0), second.notes.filter { it.staff == Staff.BASS && !it.isRest }.map { it.beat })
    }

    /** An .mxl with its files stored and no META-INF/container.xml: its one .musicxml file is the score. */
    @Test
    fun storedMxlWithoutContainerOpens() {
        val parsed = MusicXMLParser.parse(TestFiles.fixture("stored")).score
        assertEquals("Stored", parsed.title)
        assertEquals(3, parsed.timeSignatureTop)
        val notes = parsed.measures.first().notes
        assertEquals(listOf(60, 64, 67), notes.map { it.midiNote })
        assertEquals(listOf(1.0, 2.0, 3.0), notes.map { it.beat })
        assertTrue(notes.all { it.staff == Staff.TREBLE })
    }

    /** Parts on one staff in a score of several parts: the flute (G clef) plays on the treble and the cello (F clef)
     *  on the bass for the whole piece, whatever its notes' <staff> or its later G clef say. The cello counts 8 a quarter. */
    @Test
    fun oneStaffPartsPlayOnTheHandOfTheirClef() {
        val xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="3.1">
          <part-list>
            <score-part id="P1"><part-name>Flauta</part-name></score-part>
            <score-part id="P2"><part-name>Violoncelo</part-name></score-part>
          </part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>1</divisions><key><fifths>0</fifths></key>
                <time><beats>3</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
              <note><pitch><step>G</step><octave>5</octave></pitch><duration>3</duration><voice>1</voice><type>half</type><dot/></note>
            </measure>
            <measure number="2">
              <note><pitch><step>A</step><octave>5</octave></pitch><duration>3</duration><voice>1</voice><type>half</type><dot/></note>
            </measure>
          </part>
          <part id="P2">
            <measure number="1">
              <attributes><divisions>8</divisions><key><fifths>0</fifths></key>
                <time><beats>3</beats><beat-type>4</beat-type></time><clef><sign>F</sign><line>4</line></clef></attributes>
              <note><pitch><step>C</step><octave>3</octave></pitch><duration>8</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
              <note><pitch><step>E</step><octave>3</octave></pitch><duration>16</duration><voice>1</voice><type>half</type></note>
            </measure>
            <measure number="2">
              <attributes><clef><sign>G</sign><line>2</line></clef></attributes>
              <note><pitch><step>G</step><octave>4</octave></pitch><duration>24</duration><voice>1</voice><type>half</type><dot/></note>
            </measure>
          </part>
        </score-partwise>
        """.trimIndent()
        val parsed = parse(xml).score
        assertEquals(2, parsed.measureCount)
        val first = parsed.measures[0]
        assertEquals(listOf(79), first.trebleNotes.map { it.midiNote })
        assertEquals(listOf(48, 52), first.bassNotes.map { it.midiNote })
        assertEquals(listOf(1.0, 2.0), first.bassNotes.map { it.beat })
        assertEquals(listOf(1.0, 2.0), first.bassNotes.map { it.length })
        val second = parsed.measures[1]
        assertNull(second.length)
        assertEquals(listOf(81), second.trebleNotes.map { it.midiNote })
        assertEquals(listOf(67), second.bassNotes.map { it.midiNote })
    }

    // endregion

    // region Android-only checks

    /** A file naming the MusicXML DTD reads offline: the DTD is never fetched. */
    @Test
    fun doctypeIsNotFetched() {
        val xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://invalid.invalid/partwise.dtd">
        <score-partwise version="3.1">
          <work><work-title>Offline</work-title></work>
          <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
          <part id="P1"><measure number="1">
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
          </measure></part>
        </score-partwise>
        """.trimIndent()
        assertEquals("Offline", parse(xml).score.title)
    }

    @Test
    fun damagedOrEmptyFilesThrowClearReasons() {
        val damaged = assertThrows(MusicXMLException::class.java) { parse("<score-partwise><part>") }
        assertEquals(MusicXMLException.Reason.DATA_CORRUPTED, damaged.reason)
        val empty = assertThrows(MusicXMLException::class.java) { parse("<score-partwise version=\"3.1\"></score-partwise>") }
        assertEquals(MusicXMLException.Reason.MISSING_PART, empty.reason)
    }

    /** What the exporter writes reads back with the same notes, beats and lengths. */
    @Test
    fun exportedScoreReadsBack() {
        val notes = listOf(
            Note(pitch = Pitch(NoteName.C, 5), duration = NoteDuration.QUARTER, beat = 1.0, fingerNumber = 1),
            Note(pitch = Pitch(NoteName.E, 5), duration = NoteDuration.QUARTER, beat = 1.0),
            Note(pitch = Pitch(NoteName.F, 5, Accidental.SHARP), duration = NoteDuration.DOTTED_HALF, beat = 2.0),
            Note(pitch = Pitch(NoteName.C, 3), duration = NoteDuration.HALF, staff = Staff.BASS, beat = 3.0),
        )
        val score = Score(
            title = "Tom & Jerry's", composer = "Me", tempo = 90,
            measures = listOf(Measure(number = 1, notes = notes), Measure(number = 2, barlineType = BarlineType.FINAL)),
        )
        val back = MusicXMLParser.parse(MusicXMLExporter.export(score).toByteArray()).score
        assertEquals("Tom & Jerry's", back.title)
        assertEquals(90, back.tempo)
        assertEquals(2, back.measureCount)
        val first = back.measures[0]
        assertEquals(listOf(72, 76, 78), first.trebleNotes.filter { !it.isRest }.map { it.midiNote })
        assertEquals(listOf(1.0, 1.0, 2.0), first.trebleNotes.filter { !it.isRest }.map { it.beat })
        assertEquals(listOf(1.0, 1.0, 3.0), first.trebleNotes.filter { !it.isRest }.map { it.length })
        assertEquals(1, first.trebleNotes.first().fingerNumber)
        assertEquals(listOf(48), first.bassNotes.filter { !it.isRest }.map { it.midiNote })
        assertEquals(listOf(3.0), first.bassNotes.filter { !it.isRest }.map { it.beat })
        assertTrue(back.measures[1].notes.all { it.isRest })
    }

    // endregion
}
