// CatalogScoreData.kt — the web player's note data (window.SCORE_DATA of luksmusic.web.app) as the app's measures,
// for a catalog score that lists no MusicXML (port of the "SCORE_DATA → Model" part of
// luksMusic/Services/Storage/OnlineLibraryService.swift). Notes are spelled with the reading drill's helpers, as on iOS.
package com.lukstrike.luksmusic.core.musicxml

import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.ScoreSource
import com.lukstrike.luksmusic.core.model.Staff
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlin.math.abs

object CatalogScoreData {

    /**
     * A score from note data, which only has MIDI numbers: the notes are spelled for the piece's likely key, so the
     * engraving and the reading drill show the accidentals a printed edition would. The catalog gives the tempo and
     * the beats of a measure, counted in quarters.
     */
    fun playableScore(
        scoreData: JsonArray,
        title: String,
        composer: String,
        difficulty: Difficulty?,
        bpm: Int,
        beatsPerMeasure: Int,
    ): Score {
        val measures = scoreData.mapNotNull { (it as? JsonObject)?.let(::measure) }
        val (spelled, keySignature) = ReadingDrill.respelled(measures)
        val tempo = maxOf(20, bpm)
        val beats = maxOf(1, beatsPerMeasure)
        val totalBeats = measures.sumOf { it.beats(beats) }
        val now = System.currentTimeMillis()
        return Score(
            title = title,
            composer = composer,
            difficulty = difficulty ?: Difficulty.ADVANCED,
            source = ScoreSource.IMPORTED,
            dateCreated = now,
            lastModified = now,
            tempo = tempo,
            keySignatureValue = keySignature,
            timeSignatureTop = beats,
            timeSignatureBottom = 4,
            estimatedDuration = totalBeats * 60.0 / tempo,
            measures = spelled,
        )
    }

    /** One measure of SCORE_DATA: `{number, treble: [...], bass: [...]}`, each event a chord of MIDI notes at a beat. */
    fun measure(entry: JsonObject): Measure {
        val notes = mutableListOf<Note>()
        for ((key, staff) in listOf("treble" to Staff.TREBLE, "bass" to Staff.BASS)) {
            val events = entry[key] as? JsonArray ?: continue
            for (event in events) {
                if (event !is JsonObject) continue
                val beat = event.number("beat") ?: continue
                val (duration, isTriplet) = noteValue(event)
                val lyric = event.string("lyric")
                val chord = (event["chord"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.intOrNull }
                chord.forEachIndexed { i, midi ->
                    notes += Note(
                        pitch = ReadingDrill.spelledPitch(midi, keySignature = 0),
                        duration = duration,
                        staff = staff,
                        lyric = if (i == 0) lyric else null,
                        isTriplet = isTriplet,
                        beat = beat,
                    )
                }
            }
        }
        return Measure(number = (entry["number"] as? JsonPrimitive)?.intOrNull ?: 0, notes = notes)
    }

    /** Older data names the value (`dur`, `triplet`); newer data gives its length in beats (`len`). */
    fun noteValue(event: JsonObject): Pair<NoteDuration, Boolean> {
        val triplet = (event["triplet"] as? JsonPrimitive)?.booleanOrNull ?: false
        when (event.string("dur")) {
            "whole" -> return NoteDuration.WHOLE to triplet
            "dottedHalf" -> return NoteDuration.DOTTED_HALF to triplet
            "half" -> return NoteDuration.HALF to triplet
            "dottedQuarter" -> return NoteDuration.DOTTED_QUARTER to triplet
            "quarter" -> return NoteDuration.QUARTER to triplet
            "dottedEighth" -> return NoteDuration.DOTTED_EIGHTH to triplet
            "8th" -> return NoteDuration.EIGHTH to triplet
            "16th" -> return NoteDuration.SIXTEENTH to triplet
            "32nd" -> return NoteDuration.THIRTY_SECOND to triplet
        }
        val length = event.number("len") ?: 1.0
        var best = NoteDuration.QUARTER to false
        var bestError = Double.POSITIVE_INFINITY
        for (duration in NoteDuration.entries) {
            for (isTriplet in listOf(false, true)) {
                val error = abs(duration.beats * (if (isTriplet) 2.0 / 3.0 else 1.0) - length)
                if (error < bestError - 1e-9) {
                    bestError = error
                    best = duration to isTriplet
                }
            }
        }
        return best
    }

    private fun JsonObject.number(key: String): Double? = (this[key] as? JsonPrimitive)?.takeIf { !it.isString }?.doubleOrNull
    private fun JsonObject.string(key: String): String? = (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
}
