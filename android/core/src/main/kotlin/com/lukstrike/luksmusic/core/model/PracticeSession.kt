// PracticeSession.kt — port of luksMusic/Models/PracticeSession.swift.
package com.lukstrike.luksmusic.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class PracticeMode {
    @SerialName("freePlay") FREE_PLAY,
    @SerialName("guided") GUIDED,
    @SerialName("handsSeparate_right") HANDS_SEPARATE_RIGHT,
    @SerialName("handsSeparate_left") HANDS_SEPARATE_LEFT,
    @SerialName("slowPractice") SLOW_PRACTICE,
}

@Serializable
data class PracticeSession(
    val id: String = UUID.randomUUID().toString(),
    val scoreId: String,
    val scoreTitle: String,
    /** Epoch milliseconds. */
    val startTime: Long = System.currentTimeMillis(),
    val endTime: Long? = null,
    val totalNotesPlayed: Int = 0,
    val correctNotes: Int = 0,
    val incorrectNotes: Int = 0,
    val missedNotes: Int = 0,
    val tempoUsed: Int = 120,
    val sectionsCompleted: Int = 0,
    val longestStreak: Int = 0,
    val practiceMode: PracticeMode = PracticeMode.FREE_PLAY,
    val difficultyRating: Int? = null,
    val notes: String? = null,
) {
    /** Percent 0..100 of the notes played (0 when none). */
    val accuracy: Double
        get() = if (totalNotesPlayed <= 0) 0.0 else correctNotes * 100.0 / totalNotesPlayed

    /** Seconds; 0 until the session ends. */
    val durationSeconds: Double
        get() = endTime?.let { (it - startTime) / 1000.0 } ?: 0.0

    /** "M:SS" or "H:MM:SS". */
    val formattedDuration: String
        get() {
            val total = durationSeconds.toInt()
            val h = total / 3600; val m = (total % 3600) / 60; val s = total % 60
            return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
        }

    val isActive: Boolean get() = endTime == null
}
