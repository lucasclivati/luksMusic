package com.lukstrike.luksmusic.core.musicxml

import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Staff
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Test

class CatalogScoreDataTest {

    private fun obj(json: String) = Json.parseToJsonElement(json) as JsonObject

    /** Older data names the value; newer data gives the length in beats, matched to the closest value. */
    @Test
    fun noteValues() {
        assertEquals(NoteDuration.EIGHTH to true, CatalogScoreData.noteValue(obj("""{"dur":"8th","triplet":true}""")))
        assertEquals(NoteDuration.DOTTED_QUARTER to false, CatalogScoreData.noteValue(obj("""{"len":1.5}""")))
        assertEquals(NoteDuration.EIGHTH to true, CatalogScoreData.noteValue(obj("""{"len":0.333}""")))
        // One beat by default; a dotted-quarter triplet is exactly as long and comes first in the values, as on iOS
        assertEquals(NoteDuration.DOTTED_QUARTER to true, CatalogScoreData.noteValue(obj("""{}""")))
    }

    @Test
    fun scoreDataBecomesAPlayableScore() {
        val data = Json.parseToJsonElement(
            """[{"number":1,"treble":[{"chord":[67,79],"beat":1.0,"dur":"8th","triplet":true,"lyric":"When"}],
                 "bass":[{"chord":[43],"beat":1,"len":4}]}]"""
        ) as JsonArray
        val score = CatalogScoreData.playableScore(data, "Dark Dream", "Curley Gao", null, 70, 4)
        assertEquals(70, score.tempo)
        assertEquals(4, score.timeSignatureTop)
        val notes = score.measures.single().notes
        assertEquals(listOf(67, 79, 43), notes.map { it.midiNote })
        assertEquals(listOf("When", null, null), notes.map { it.lyric })
        assertEquals(Staff.BASS, notes[2].staff)
        assertEquals(NoteDuration.WHOLE, notes[2].duration)
    }
}
