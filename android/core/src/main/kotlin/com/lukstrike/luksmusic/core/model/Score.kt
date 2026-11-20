// Score.kt — port of luksMusic/Models/Score.swift. The MusicXML text is stored beside the score by the app's
// ScoreRepository, not inside this object, so lists of scores stay light.
package com.lukstrike.luksmusic.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class Difficulty {
    @SerialName("Beginner") BEGINNER, @SerialName("Intermediate") INTERMEDIATE,
    @SerialName("Advanced") ADVANCED, @SerialName("Expert") EXPERT,
}

@Serializable
enum class ScoreSource {
    @SerialName("Manual") MANUAL, @SerialName("Imported") IMPORTED, @SerialName("Scanned") SCANNED,
}

@Serializable
data class Score(
    val id: String = UUID.randomUUID().toString(),
    val title: String = "Untitled Piano Piece",
    val composer: String = "Anonymous",
    val difficulty: Difficulty = Difficulty.BEGINNER,
    val source: ScoreSource = ScoreSource.MANUAL,
    val isFavorite: Boolean = false,
    val isPublic: Boolean = false,
    /** Epoch milliseconds. */
    val dateCreated: Long = System.currentTimeMillis(),
    val lastModified: Long = System.currentTimeMillis(),
    val lastPracticed: Long? = null,
    /** Seconds. */
    val estimatedDuration: Double = 0.0,
    val tempo: Int = 120,
    /** Sharps (>0) or flats (<0). */
    val keySignatureValue: Int = 0,
    val timeSignatureTop: Int = 4,
    val timeSignatureBottom: Int = 4,
    val measures: List<Measure> = emptyList(),
    /** Whether the original MusicXML is stored beside the score (dropped when the notes are edited). */
    val hasMusicXml: Boolean = false,
    /** luksmusic.web.app catalog id this was downloaded from. */
    val catalogId: String? = null,
    /** Bundled sample this score was seeded from (asset file name). */
    val sampleId: String? = null,
) {
    /**
     * A piece bundled with the app (seeded from luksMusic/SampleScores). Every install has it, so it is never synced
     * to the cloud, and it is not editable: the notes stay exactly as the bundled edition.
     */
    val isSample: Boolean get() = sampleId != null

    val totalNoteCount: Int get() = measures.sumOf { m -> m.notes.count { !it.isRest } }
    val measureCount: Int get() = measures.size

    val keySignatureName: String
        get() = when (keySignatureValue) {
            0 -> "C Major / A Minor"; 1 -> "G Major / E Minor (1♯)"; 2 -> "D Major / B Minor (2♯)"
            3 -> "A Major / F♯ Minor (3♯)"; 4 -> "E Major / C♯ Minor (4♯)"; 5 -> "B Major / G♯ Minor (5♯)"
            6 -> "F♯ Major / D♯ Minor (6♯)"; 7 -> "C♯ Major / A♯ Minor (7♯)"; -1 -> "F Major / D Minor (1♭)"
            -2 -> "B♭ Major / G Minor (2♭)"; -3 -> "E♭ Major / C Minor (3♭)"; -4 -> "A♭ Major / F Minor (4♭)"
            -5 -> "D♭ Major / B♭ Minor (5♭)"; -6 -> "G♭ Major / E♭ Minor (6♭)"; -7 -> "C♭ Major / A♭ Minor (7♭)"
            else -> "C Major"
        }
}
