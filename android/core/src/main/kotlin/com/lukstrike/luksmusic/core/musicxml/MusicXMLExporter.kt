// MusicXMLExporter.kt — port of luksMusic/Models/MusicXML/MusicXMLExporter.swift: writes standard MusicXML 3.1
// from a Score, for export to notation apps and for the score viewer when the notes were edited in the app.
package com.lukstrike.luksmusic.core.musicxml

import com.lukstrike.luksmusic.core.model.BarlineType
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Score
import java.time.Instant
import java.time.temporal.ChronoUnit

object MusicXMLExporter {

    /** Divisions per quarter note: divisible by 3 (triplets) and 8 (32nd notes). */
    private const val DIVISIONS = 24

    /** Notes that start together with the same length and tuplet, written as one chord. */
    private class Event(val onset: Int, val length: Int, val isTriplet: Boolean, val notes: MutableList<Note>)

    private class Voice(val xml: String, val end: Int)

    /** The score as a MusicXML document. */
    fun export(score: Score, now: Instant = Instant.now()): String {
        val xml = StringBuilder(
            """
            |<?xml version="1.0" encoding="UTF-8"?>
            |<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
            |<score-partwise version="3.1">
            |  <work>
            |    <work-title>${escapeXml(score.title)}</work-title>
            |  </work>
            |  <identification>
            |    <creator type="composer">${escapeXml(score.composer)}</creator>
            |    <encoding>
            |      <software>luksMusic Android</software>
            |      <encoding-date>${now.truncatedTo(ChronoUnit.SECONDS)}</encoding-date>
            |    </encoding>
            |  </identification>
            |  <part-list>
            |    <score-part id="P1">
            |      <part-name>Piano</part-name>
            |      <score-instrument id="P1-I1">
            |        <instrument-name>Acoustic Grand Piano</instrument-name>
            |      </score-instrument>
            |      <midi-instrument id="P1-I1">
            |        <midi-channel>1</midi-channel>
            |        <midi-program>1</midi-program>
            |      </midi-instrument>
            |    </score-part>
            |  </part-list>
            |  <part id="P1">
            """.trimMargin()
        )

        val measures = score.measures
        val totalMeasures = maxOf(1, measures.size)
        val measureLength = maxOf(1, score.timeSignatureTop * DIVISIONS * 4 / maxOf(1, score.timeSignatureBottom))
        // Note positions count beats of the time signature's unit (eighths in 3/8); durations count quarters
        val beatLength = DIVISIONS * 4.0 / maxOf(1, score.timeSignatureBottom)
        // The tempo counts the same beat unit; <sound tempo> is always in quarter notes per minute
        val beatUnit = mapOf(2 to "half", 8 to "eighth", 16 to "16th")[score.timeSignatureBottom] ?: "quarter"
        val quarterTempo = score.tempo * 4.0 / maxOf(1, score.timeSignatureBottom)

        measures.forEachIndexed { index, measure ->
            val measureNum = if (measure.number > 0) measure.number else index + 1
            xml.append("\n    <measure number=\"$measureNum\">")

            // First measure includes attributes
            if (index == 0) {
                xml.append(
                    """
                    |
                    |      <attributes>
                    |        <divisions>$DIVISIONS</divisions>
                    |        <key>
                    |          <fifths>${score.keySignatureValue}</fifths>
                    |        </key>
                    |        <time>
                    |          <beats>${score.timeSignatureTop}</beats>
                    |          <beat-type>${score.timeSignatureBottom}</beat-type>
                    |        </time>
                    |        <staves>2</staves>
                    |        <clef number="1">
                    |          <sign>G</sign>
                    |          <line>2</line>
                    |        </clef>
                    |        <clef number="2">
                    |          <sign>F</sign>
                    |          <line>4</line>
                    |        </clef>
                    |      </attributes>
                    |      <direction placement="above">
                    |        <direction-type>
                    |          <metronome>
                    |            <beat-unit>$beatUnit</beat-unit>
                    |            <per-minute>${score.tempo}</per-minute>
                    |          </metronome>
                    |        </direction-type>
                    |        <staff>1</staff>
                    |        <sound tempo="$quarterTempo"/>
                    |      </direction>
                    """.trimMargin()
                )
            }

            // Each staff is written as one or more voices; <backup> returns to the start of the measure
            // before the next voice, since MusicXML reads the notes of a measure in time order.
            val voices = staffVoices(measure.trebleNotes, staff = 1, firstVoice = 1, measureLength, beatLength) +
                staffVoices(measure.bassNotes, staff = 2, firstVoice = 5, measureLength, beatLength)
            voices.forEachIndexed { voiceIndex, voice ->
                xml.append(voice.xml)
                if (voiceIndex < voices.size - 1 && voice.end > 0) {
                    xml.append("\n      <backup>\n        <duration>${voice.end}</duration>\n      </backup>")
                }
            }

            // Barlines
            if (measure.barlineType == BarlineType.FINAL || index == totalMeasures - 1) {
                xml.append("\n      <barline location=\"right\">\n        <bar-style>light-heavy</bar-style>\n      </barline>")
            }

            xml.append("\n    </measure>")
        }

        xml.append("\n  </part>\n</score-partwise>")
        return xml.toString()
    }

    // region Voices

    /** Splits a staff's notes into voices so overlapping notes never share one, and writes each voice. */
    private fun staffVoices(notes: List<Note>, staff: Int, firstVoice: Int, measureLength: Int, beatLength: Double): List<Voice> {
        val events = mutableListOf<Event>()
        for (note in notes.sortedBy { it.beat }) {
            val onset = maxOf(0, swiftRound((note.beat - 1.0) * beatLength))
            val written = maxOf(1, swiftRound(note.duration.beats * (if (note.isTriplet) 2.0 / 3.0 else 1.0) * DIVISIONS))
            // Never let a note run past the barline, which would shift every following measure
            val length = minOf(written, maxOf(1, measureLength - onset))
            val same = events.firstOrNull { it.onset == onset && it.length == length && it.isTriplet == note.isTriplet }
            if (same != null) same.notes += note else events += Event(onset, length, note.isTriplet, mutableListOf(note))
        }
        events.sortBy { it.onset }

        val lanes = mutableListOf<MutableList<Event>>()
        val laneEnds = mutableListOf<Int>()
        for (event in events) {
            val lane = laneEnds.indexOfFirst { it <= event.onset }
            if (lane >= 0) {
                lanes[lane] += event
                laneEnds[lane] = event.onset + event.length
            } else {
                lanes += mutableListOf(event)
                laneEnds += event.onset + event.length
            }
        }

        // An empty staff still shows a whole-measure rest
        if (lanes.isEmpty()) {
            val rest = "\n      <note>\n        <rest measure=\"yes\"/>\n        <duration>$measureLength</duration>\n        <voice>$firstVoice</voice>\n        <staff>$staff</staff>\n      </note>"
            return listOf(Voice(rest, measureLength))
        }

        return lanes.mapIndexed { laneIndex, lane ->
            val voice = firstVoice + laneIndex
            val xml = StringBuilder()
            var position = 0
            var tupletProgress = 0
            for (event in lane) {
                if (event.onset > position) {
                    // Gaps in the main voice read as rests; extra voices just skip ahead
                    xml.append(
                        if (laneIndex == 0) restsXml(event.onset - position, voice, staff)
                        else forwardXml(event.onset - position, voice, staff)
                    )
                }

                var tuplet: String? = null
                if (event.isTriplet) {
                    if (tupletProgress == 0) tuplet = "start"
                    tupletProgress += event.length
                    if (tupletProgress >= event.length * 3) {
                        tuplet = if (tuplet == "start") null else "stop"
                        tupletProgress = 0
                    }
                } else {
                    tupletProgress = 0
                }

                xml.append(eventXml(event, voice, staff, tuplet))
                position = event.onset + event.length
            }
            if (laneIndex == 0 && position < measureLength) {
                xml.append(restsXml(measureLength - position, voice, staff))
                position = measureLength
            }
            Voice(xml.toString(), position)
        }
    }

    private fun eventXml(event: Event, voice: Int, staff: Int, tuplet: String?): String {
        val xml = StringBuilder()
        val lyric = event.notes.firstNotNullOfOrNull { it.lyric }
        event.notes.forEachIndexed { i, note ->
            xml.append("\n      <note>")
            if (i > 0) xml.append("\n        <chord/>")
            if (note.isRest) {
                xml.append("\n        <rest/>")
            } else {
                xml.append("\n        <pitch>\n          <step>${note.pitch.noteName.name}</step>")
                val alter = note.pitch.accidental.semitoneOffset
                if (alter != 0) xml.append("\n          <alter>$alter</alter>")
                xml.append("\n          <octave>${note.pitch.octave}</octave>\n        </pitch>")
            }
            xml.append("\n        <duration>${event.length}</duration>")
            xml.append("\n        <voice>$voice</voice>")
            xml.append("\n        <type>${xmlType(note.duration)}</type>")
            if (isDotted(note.duration)) xml.append("\n        <dot/>")
            if (event.isTriplet) {
                xml.append("\n        <time-modification>\n          <actual-notes>3</actual-notes>\n          <normal-notes>2</normal-notes>\n        </time-modification>")
            }
            xml.append("\n        <staff>$staff</staff>")

            val notations = StringBuilder()
            if (i == 0 && tuplet != null) notations.append("\n          <tuplet type=\"$tuplet\" bracket=\"no\"/>")
            note.fingerNumber?.let { notations.append("\n          <technical>\n            <fingering>$it</fingering>\n          </technical>") }
            if (notations.isNotEmpty()) xml.append("\n        <notations>$notations\n        </notations>")
            if (i == 0 && lyric != null) {
                xml.append("\n        <lyric number=\"1\">\n          <syllabic>single</syllabic>\n          <text>${escapeXml(lyric.trim(' ', '\t'))}</text>\n        </lyric>")
            }
            xml.append("\n      </note>")
        }
        return xml.toString()
    }

    /** Rests filling [length] divisions with standard values; any remainder becomes an invisible skip. */
    private fun restsXml(length: Int, voice: Int, staff: Int): String {
        val values = listOf(
            Triple(96, "whole", false), Triple(72, "half", true), Triple(48, "half", false), Triple(36, "quarter", true),
            Triple(24, "quarter", false), Triple(18, "eighth", true), Triple(12, "eighth", false), Triple(9, "16th", true),
            Triple(6, "16th", false), Triple(3, "32nd", false),
        )
        var remaining = length
        val xml = StringBuilder()
        for ((valueLength, type, dotted) in values) {
            while (remaining >= valueLength) {
                xml.append("\n      <note>\n        <rest/>\n        <duration>$valueLength</duration>\n        <voice>$voice</voice>\n        <type>$type</type>")
                if (dotted) xml.append("\n        <dot/>")
                xml.append("\n        <staff>$staff</staff>\n      </note>")
                remaining -= valueLength
            }
        }
        if (remaining > 0) xml.append(forwardXml(remaining, voice, staff))
        return xml.toString()
    }

    private fun forwardXml(length: Int, voice: Int, staff: Int): String =
        "\n      <forward>\n        <duration>$length</duration>\n        <voice>$voice</voice>\n        <staff>$staff</staff>\n      </forward>"

    // endregion

    private fun xmlType(duration: NoteDuration): String = when (duration) {
        NoteDuration.WHOLE -> "whole"
        NoteDuration.DOTTED_HALF, NoteDuration.HALF -> "half"
        NoteDuration.DOTTED_QUARTER, NoteDuration.QUARTER -> "quarter"
        NoteDuration.DOTTED_EIGHTH, NoteDuration.EIGHTH -> "eighth"
        NoteDuration.DOTTED_SIXTEENTH, NoteDuration.SIXTEENTH -> "16th"
        NoteDuration.THIRTY_SECOND -> "32nd"
    }

    private fun isDotted(duration: NoteDuration): Boolean = when (duration) {
        NoteDuration.DOTTED_HALF, NoteDuration.DOTTED_QUARTER, NoteDuration.DOTTED_EIGHTH, NoteDuration.DOTTED_SIXTEENTH -> true
        else -> false
    }

    /** Swift's `Double.rounded()` (halves away from zero) as an Int. */
    private fun swiftRound(value: Double): Int =
        (if (value < 0) -(-value + 0.5).toLong() else (value + 0.5).toLong()).toInt()

    private fun escapeXml(string: String): String = string
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("\"", "&quot;")
        .replace("'", "&apos;")
}
