// MusicXMLParser.kt — port of luksMusic/Models/MusicXML/MusicXMLParser.swift: converts standard MusicXML files,
// plain or compressed (.mxl), into the app's Score and Measure models. The player, practice and lessons all read
// what this produces, so it must stay in step with the iOS parser: same beats, lengths, ties and tuplets.
package com.lukstrike.luksmusic.core.musicxml

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.NoteName
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.ScoreSource
import com.lukstrike.luksmusic.core.model.Staff
import org.xml.sax.Attributes
import org.xml.sax.InputSource
import org.xml.sax.SAXException
import org.xml.sax.helpers.DefaultHandler
import java.io.ByteArrayInputStream
import java.io.StringReader
import java.nio.charset.Charset
import javax.xml.parsers.SAXParserFactory
import kotlin.math.abs
import kotlin.math.floor

/** Errors that can occur during MusicXML parsing. */
class MusicXMLException(val reason: Reason, cause: Throwable? = null) : Exception(reason.name, cause) {
    enum class Reason {
        /** "O arquivo MusicXML está danificado ou não é válido." */
        DATA_CORRUPTED,
        /** "A partitura MusicXML não tem nenhuma parte." */
        MISSING_PART,
        /** "O arquivo .mxl não contém uma partitura MusicXML." */
        MISSING_SCORE_FILE,
    }
}

/** A score read from MusicXML and the MusicXML text it was read from (the file inside an .mxl), which the score
 *  viewer draws as is: save both with `ScoreRepository.save(score, musicXml)`. */
data class ParsedScore(val score: Score, val musicXml: String)

/**
 * Parses MusicXML 3.0/3.1 partwise XML files into the app's [Score] and [Measure] models.
 *
 * Positions and lengths count the time signature's beat (eighths in 3/8, halves in 2/2) like the rest of the app,
 * and come from each note's `<duration>`, so the hands written one after the other (`<backup>`, `<forward>`),
 * tuplets and ties land where the file puts them. Repeats are read as written. The result keeps the MusicXML text
 * (the file inside an .mxl), which the score viewer draws as is.
 *
 * Every part is played. A part's measures join the first part's in order, and each part counts its own divisions
 * and ties. Staff 1 of a part is the treble staff (the right hand) and any lower staff the bass (the left hand), so a
 * piano duet's two players share the hands. A part on one staff in a score of several parts (a flute, a cello) is
 * one player's line, so it stays on one hand for the whole piece: the bass when its first clef is F, else the treble.
 *
 * Only the first time signature and key signature count for the whole score, as on iOS.
 */
class MusicXMLParser private constructor() : DefaultHandler() {

    /** A measure being assembled; parts after the first add their notes to it. */
    private class MeasureBuilder(val number: Int, val notes: MutableList<Note>, var length: Double?, val keySignature: Int?) {
        fun beats(timeSignatureTop: Int): Double = length ?: timeSignatureTop.coerceAtLeast(1).toDouble()
    }

    // State
    private var scoreTitle = DEFAULT_TITLE
    private var composer = "Unknown"
    private var hasComposer = false
    private var creatorType: String? = null
    private val currentText = StringBuilder()

    // Score properties
    private var quarterTempo: Double? = null
    private var timeSignatureTop = 4
    private var timeSignatureBottom = 4
    private var hasTimeSignature = false
    private var keySignatureValue = 0
    private var hasKeySignature = false
    private var divisions = 1 // MusicXML divisions per quarter note, set by each part

    // Part and measure state
    private var scorePartCount = 0
    private val measures = mutableListOf<MeasureBuilder>()
    /** Measures read in the current part; its next one joins the measure at this index */
    private var partMeasureCount = 0
    /** Where in `measures` the measure being read goes, and how many notes earlier parts left there */
    private var measureIndex = 0
    private var measureBase = 0
    private var partStaves = 1
    private var partClefSign: String? = null
    private var currentMeasureNumber = 0
    private var currentMeasureNotes = mutableListOf<Note>()
    // Where the next note starts, where the last one started and the furthest point reached, in divisions
    private var position = 0
    private var lastNoteStart = 0
    private var measureEnd = 0
    private var inBackup = false
    private var inForward = false

    // Note state
    private var inNote = false
    private var isRest = false
    private var isChord = false
    private var isGrace = false
    private var isCue = false
    private var step = "C"
    private var octave = 4
    private var alter = 0
    private var durationDivisions = 0
    private var noteType = ""
    private var dots = 0
    private var tieStart = false
    private var tieStop = false
    private var actualNotes = 1
    private var normalNotes = 1
    private var fingerNumber: Int? = null
    private var currentStaff = Staff.TREBLE
    private var currentVoice = 1

    /** Notes whose tie is still open, by staff and pitch, so the notes tied to them add to how long they are held:
     *  (measure index, note index once the measure is in `measures`). */
    private val openTies = HashMap<String, Pair<Int, Int>>()

    // region SAX callbacks

    override fun startElement(uri: String?, localName: String?, qName: String, attributes: Attributes) {
        currentText.setLength(0)
        when (qName) {
            "creator" -> creatorType = attributes.getValue("type")
            "score-part" -> scorePartCount++
            "part" -> {
                // Divisions, staves, clefs and ties belong to the part
                partMeasureCount = 0
                divisions = 1
                partStaves = 1
                partClefSign = null
                openTies.clear()
            }
            "measure" -> {
                measureIndex = partMeasureCount
                measureBase = if (measureIndex < measures.size) measures[measureIndex].notes.size else 0
                currentMeasureNumber = attributes.getValue("number")?.let(::swiftInt) ?: (measures.size + 1)
                currentMeasureNotes = mutableListOf()
                position = 0
                lastNoteStart = 0
                measureEnd = 0
            }
            "note" -> {
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
                fingerNumber = null
                currentStaff = singleStaffHand ?: Staff.TREBLE
                currentVoice = 1
            }
            "rest" -> isRest = true
            "chord" -> isChord = true
            "grace" -> isGrace = true
            "cue" -> isCue = true
            "dot" -> dots++
            "tie" -> {
                // <tie> is the sound; <tied> repeats it as a notation
                val type = attributes.getValue("type")
                if (type == "start") tieStart = true
                if (type == "stop") tieStop = true
            }
            "backup" -> inBackup = true
            "forward" -> inForward = true
            "sound" -> {
                val value = attributes.getValue("tempo")?.trim()?.toDoubleOrNull()
                if (quarterTempo == null && value != null && value > 0) quarterTempo = value
            }
        }
    }

    override fun characters(ch: CharArray, start: Int, length: Int) {
        currentText.appendRange(ch, start, start + length)
    }

    override fun endElement(uri: String?, localName: String?, qName: String) {
        val trimmed = currentText.toString().trim()

        when (qName) {
            "work-title", "movement-title" ->
                if (trimmed.isNotEmpty() && scoreTitle == DEFAULT_TITLE) scoreTitle = trimmed
            "creator" ->
                if (trimmed.isNotEmpty() && !hasComposer && (creatorType == null || creatorType == "composer")) {
                    composer = trimmed
                    hasComposer = true
                }
            "divisions" -> swiftInt(trimmed)?.takeIf { it > 0 }?.let { divisions = it }
            "beats" -> if (!hasTimeSignature) swiftInt(trimmed)?.let { timeSignatureTop = it }
            "beat-type" -> if (!hasTimeSignature) swiftInt(trimmed)?.let {
                timeSignatureBottom = it
                hasTimeSignature = true
            }
            "fifths" -> if (!hasKeySignature) swiftInt(trimmed)?.let {
                keySignatureValue = it
                hasKeySignature = true
            }
            "staves" -> partStaves = swiftInt(trimmed) ?: 1
            "sign" -> if (partClefSign == null) partClefSign = trimmed

            // Note attributes
            "step" -> step = trimmed
            "octave" -> octave = swiftInt(trimmed) ?: 4
            "alter" -> alter = swiftInt(trimmed) ?: (trimmed.toDoubleOrNull()?.let(::roundHalfAwayFromZero) ?: 0)
            "duration" -> {
                val value = swiftInt(trimmed) ?: 0
                when {
                    inBackup -> position = maxOf(0, position - value)
                    inForward -> {
                        position += value
                        measureEnd = maxOf(measureEnd, position)
                    }
                    inNote -> durationDivisions = value
                }
            }
            "backup" -> inBackup = false
            "forward" -> inForward = false
            "type" -> if (inNote) noteType = trimmed
            "actual-notes" -> actualNotes = swiftInt(trimmed) ?: 1
            "normal-notes" -> normalNotes = swiftInt(trimmed) ?: 1
            "staff" -> if (inNote && singleStaffHand == null) currentStaff = if (trimmed == "1") Staff.TREBLE else Staff.BASS
            "voice" -> if (inNote) currentVoice = swiftInt(trimmed) ?: 1
            "fingering" -> fingerNumber = swiftInt(trimmed)

            "note" -> {
                inNote = false
                buildAndAddNote()
            }

            "measure" -> {
                val end = beats(measureEnd)
                // A pickup or the half measure before a repeat lasts what it holds
                val length: Double? = if (measureEnd > 0 && abs(end - timeSignatureTop) > 0.001) end else null
                if (measureIndex < measures.size) {
                    // A later part joins the first part's measure at the same place, which lasts as long as its longest part
                    val measure = measures[measureIndex]
                    measure.notes += currentMeasureNotes
                    if (end > measure.beats(timeSignatureTop) + 0.001) measure.length = length
                } else {
                    measures += MeasureBuilder(
                        number = currentMeasureNumber,
                        notes = currentMeasureNotes,
                        length = length,
                        // iOS stores KeySignature(rawValue:), which exists for -7...7 only
                        keySignature = keySignatureValue.takeIf { it in -7..7 },
                    )
                }
                partMeasureCount++
            }
        }
    }

    // endregion

    // region Helpers

    /** The hand every note of the current part plays when it is a part on one staff in a score of several parts,
     *  chosen by its first clef (its notes' `<staff>` is then ignored). A score of one part reads `<staff>`. */
    private val singleStaffHand: Staff?
        get() {
            if (scorePartCount <= 1 || partStaves >= 2) return null
            return if (partClefSign == "F") Staff.BASS else Staff.TREBLE
        }

    /** Divisions (quarter / `divisions`) in the time signature's beat. */
    private fun beats(divisionCount: Int): Double =
        divisionCount.toDouble() / maxOf(1, divisions) * timeSignatureBottom / 4.0

    private fun buildAndAddNote() {
        // Grace and cue notes take no time and are not played
        if (isGrace || isCue) return

        val start = if (isChord) lastNoteStart else position
        if (!isChord) {
            lastNoteStart = position
            position += durationDivisions
            measureEnd = maxOf(measureEnd, position)
        }

        val accidental = when (alter) {
            1 -> Accidental.SHARP
            -1 -> Accidental.FLAT
            2 -> Accidental.DOUBLE_SHARP
            -2 -> Accidental.DOUBLE_FLAT
            else -> Accidental.NATURAL
        }
        val pitch = Pitch(NoteName.entries.firstOrNull { it.name == step } ?: NoteName.C, octave, accidental)
        val length = beats(durationDivisions)

        // The held end of a tie adds its length to the note it continues, which stays the one struck
        val tieKey = "${currentStaff.name}-${pitch.midiNoteNumber}"
        var continuesTie = false
        val open = openTies[tieKey]
        if (tieStop && !isRest && open != null) {
            extendNote(open, length)
            continuesTie = true
            if (!tieStart) openTies.remove(tieKey)
        }

        currentMeasureNotes += Note(
            pitch = pitch,
            duration = noteDuration(),
            velocity = if (isRest) 0 else 80,
            isRest = isRest,
            isTied = tieStart && !isRest,
            staff = currentStaff,
            voice = currentVoice,
            fingerNumber = fingerNumber,
            isTriplet = actualNotes == 3 && normalNotes == 2,
            beat = 1.0 + beats(start),
            length = if (isRest) null else length,
            isTieContinuation = if (continuesTie) true else null,
        )

        if (tieStart && !isRest && !continuesTie) {
            openTies[tieKey] = measureIndex to (measureBase + currentMeasureNotes.size - 1)
        }
    }

    /** Adds [beats] to how long the note at [location] (its index once the measure is in `measures`) is held, in
     *  this measure or an earlier one. */
    private fun extendNote(location: Pair<Int, Int>, beats: Double) {
        val (measure, index) = location
        if (measure == measureIndex) {
            val note = index - measureBase
            if (note < 0 || note >= currentMeasureNotes.size) return
            val held = currentMeasureNotes[note]
            currentMeasureNotes[note] = held.copy(length = (held.length ?: 0.0) + beats)
        } else if (measure < measures.size && index < measures[measure].notes.size) {
            val notes = measures[measure].notes
            notes[index] = notes[index].copy(length = (notes[index].length ?: 0.0) + beats)
        }
    }

    /** The written value from `<type>` and its dots, or the closest one to `<duration>` when there is no type. */
    private fun noteDuration(): NoteDuration = when (noteType) {
        "whole", "breve" -> NoteDuration.WHOLE
        "half" -> if (dots > 0) NoteDuration.DOTTED_HALF else NoteDuration.HALF
        "quarter" -> if (dots > 0) NoteDuration.DOTTED_QUARTER else NoteDuration.QUARTER
        "eighth" -> if (dots > 0) NoteDuration.DOTTED_EIGHTH else NoteDuration.EIGHTH
        "16th" -> if (dots > 0) NoteDuration.DOTTED_SIXTEENTH else NoteDuration.SIXTEENTH
        "32nd", "64th", "128th" -> NoteDuration.THIRTY_SECOND
        else -> {
            val quarters = durationDivisions.toDouble() / maxOf(1, divisions) * actualNotes / maxOf(1, normalNotes)
            // minBy keeps the first of equal distances, like Swift's min(by:)
            NoteDuration.entries.minBy { abs(it.beats - quarters) }
        }
    }

    private fun estimateDifficulty(measures: List<MeasureBuilder>): Difficulty {
        val noteCount = measures.sumOf { it.notes.size }
        val hasSixteenths = measures.any { m ->
            m.notes.any { it.duration == NoteDuration.SIXTEENTH || it.duration == NoteDuration.THIRTY_SECOND }
        }
        val hasComplexKey = abs(keySignatureValue) >= 3
        return when {
            noteCount > 300 || (hasSixteenths && hasComplexKey) -> Difficulty.ADVANCED
            noteCount > 150 || hasSixteenths || hasComplexKey -> Difficulty.INTERMEDIATE
            else -> Difficulty.BEGINNER
        }
    }

    /** Reads plain MusicXML. */
    private fun parseXml(data: ByteArray): Score {
        try {
            parse(data, this)
        } catch (e: Exception) {
            throw MusicXMLException(MusicXMLException.Reason.DATA_CORRUPTED, e)
        }
        if (measures.isEmpty()) throw MusicXMLException(MusicXMLException.Reason.MISSING_PART)

        // <sound tempo> counts quarters a minute; the player counts the time signature's beat
        val tempo = maxOf(20, roundHalfAwayFromZero((quarterTempo ?: 100.0) * timeSignatureBottom / 4.0))
        val totalBeats = measures.sumOf { it.beats(timeSignatureTop) }
        val now = System.currentTimeMillis()
        return Score(
            title = scoreTitle.trim(),
            composer = composer.trim(),
            difficulty = estimateDifficulty(measures),
            source = ScoreSource.IMPORTED,
            dateCreated = now,
            lastModified = now,
            tempo = tempo,
            keySignatureValue = keySignatureValue,
            timeSignatureTop = timeSignatureTop,
            timeSignatureBottom = timeSignatureBottom,
            estimatedDuration = totalBeats * 60.0 / tempo,
            measures = measures.map {
                Measure(number = it.number, notes = it.notes.toList(), keySignature = it.keySignature, length = it.length)
            },
        )
    }

    // endregion

    companion object {
        private const val DEFAULT_TITLE = "Imported Score"

        /** Parses MusicXML data, plain or compressed (.mxl). Throws [MusicXMLException] or [ZipArchiveException]. */
        fun parse(data: ByteArray): ParsedScore {
            val xml = if (ZipArchive.startsWithSignature(data)) scoreFile(data) else data
            val score = MusicXMLParser().parseXml(xml)
            return ParsedScore(score, decodeText(xml))
        }

        /**
         * The MusicXML file inside compressed MusicXML (.mxl), a ZIP archive: the one META-INF/container.xml names,
         * else the first .musicxml or .xml file outside META-INF.
         */
        fun scoreFile(mxl: ByteArray): ByteArray {
            val archive = ZipArchive(mxl)
            val container = archive.entry("META-INF/container.xml")
            if (container != null) {
                val path = rootFilePath(archive.contents(container))
                val rootFile = path?.let(archive::entry)
                if (rootFile != null) return archive.contents(rootFile)
            }
            val file = archive.entries.firstOrNull { entry ->
                val path = entry.path.lowercase()
                !path.startsWith("meta-inf/") && (path.endsWith(".musicxml") || path.endsWith(".xml"))
            } ?: throw MusicXMLException(MusicXMLException.Reason.MISSING_SCORE_FILE)
            return archive.contents(file)
        }

        /**
         * MusicXML bytes as text, for the viewer and for storage: a byte-order mark or the XML declaration's
         * encoding decides the charset, else UTF-8 (what nearly every MusicXML file is).
         */
        fun decodeText(xml: ByteArray): String {
            fun startsWith(vararg prefix: Int) = xml.size >= prefix.size && prefix.indices.all { xml[it] == prefix[it].toByte() }
            return when {
                startsWith(0xEF, 0xBB, 0xBF) -> String(xml, 3, xml.size - 3, Charsets.UTF_8)
                startsWith(0xFE, 0xFF) -> String(xml, 2, xml.size - 2, Charsets.UTF_16BE)
                startsWith(0xFF, 0xFE) -> String(xml, 2, xml.size - 2, Charsets.UTF_16LE)
                else -> {
                    val head = String(xml, 0, minOf(xml.size, 200), Charsets.ISO_8859_1)
                    val declared = Regex("""^<\?xml[^>]*encoding\s*=\s*["']([A-Za-z0-9._-]+)["']""").find(head)?.groupValues?.get(1)
                    val charset = declared?.let { runCatching { Charset.forName(it) }.getOrNull() } ?: Charsets.UTF_8
                    String(xml, if (charset == Charsets.UTF_16) Charsets.UTF_8 else charset)
                }
            }
        }

        /** Reads the path of an .mxl's score file from its META-INF/container.xml: the first `<rootfile>`. */
        private fun rootFilePath(container: ByteArray): String? {
            var path: String? = null
            val stop = SAXException("found")
            val handler = object : DefaultHandler() {
                override fun startElement(uri: String?, localName: String?, qName: String, attributes: Attributes) {
                    if (qName != "rootfile" || path != null) return
                    path = attributes.getValue("full-path") ?: return
                    throw stop
                }
            }
            try {
                parse(container, handler)
            } catch (_: Exception) {
                // Aborted on the first <rootfile>, or a damaged container: whatever was found counts
            }
            return path
        }

        /**
         * Reads [xml] with a SAX parser that never fetches the DTD MusicXML files name
         * (http://www.musicxml.org/dtds/...): the Foundation parser on iOS does not either, and a phone offline must
         * still read the file. The entity resolver is set on the reader itself, since `SAXParser.parse(_, handler)`
         * would make the handler the resolver.
         */
        private fun parse(xml: ByteArray, handler: DefaultHandler) {
            val factory = SAXParserFactory.newInstance().apply {
                isNamespaceAware = false
                isValidating = false
                // Desktop JVM (unit tests); Android's parser does not know these features and never loads DTDs anyway
                runCatching { setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false) }
                runCatching { setFeature("http://xml.org/sax/features/external-general-entities", false) }
                runCatching { setFeature("http://xml.org/sax/features/external-parameter-entities", false) }
            }
            val reader = factory.newSAXParser().xmlReader
            reader.contentHandler = handler
            reader.errorHandler = handler
            reader.setEntityResolver { _, _ -> InputSource(StringReader("")) }
            reader.parse(InputSource(ByteArrayInputStream(xml)))
        }

        /** Swift's `Int(String)`: an optional sign and decimal digits only, no spaces. */
        private fun swiftInt(text: String): Int? = text.toIntOrNull()

        /** Swift's `Double.rounded()`: halves away from zero. */
        private fun roundHalfAwayFromZero(value: Double): Int =
            (if (value < 0) -floor(-value + 0.5) else floor(value + 0.5)).toInt()
    }
}
