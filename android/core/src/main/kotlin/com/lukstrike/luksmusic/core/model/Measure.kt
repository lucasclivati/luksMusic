// Measure.kt — port of luksMusic/Models/Measure.swift.
package com.lukstrike.luksmusic.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID
import kotlin.math.abs

@Serializable
enum class BarlineType {
    @SerialName("single") SINGLE, @SerialName("double") DOUBLE, @SerialName("final") FINAL,
    @SerialName("repeatStart") REPEAT_START, @SerialName("repeatEnd") REPEAT_END, @SerialName("repeatBoth") REPEAT_BOTH,
}

@Serializable
data class Measure(
    val id: String = UUID.randomUUID().toString(),
    val number: Int,
    val notes: List<Note> = emptyList(),
    val timeSignatureNumerator: Int? = null,
    val timeSignatureDenominator: Int? = null,
    /** Sharps (>0) or flats (<0) when the key changes here. */
    val keySignature: Int? = null,
    val tempo: Int? = null,
    val barlineType: BarlineType = BarlineType.SINGLE,
    val rehearsalMark: String? = null,
    /** Actual length in the signature's beat when not a full measure (pickup); null = full. */
    val length: Double? = null,
) {
    fun beats(timeSignatureTop: Int): Double = length ?: timeSignatureTop.coerceAtLeast(1).toDouble()

    val trebleNotes: List<Note> get() = notes.filter { it.staff == Staff.TREBLE }
    val bassNotes: List<Note> get() = notes.filter { it.staff == Staff.BASS }
    val sortedNotes: List<Note> get() = notes.sortedBy { it.beat }
    val hasSoundingNotes: Boolean get() = notes.any { !it.isRest }

    fun notes(staff: Staff, voice: Int): List<Note> =
        notes.filter { it.staff == staff && it.voice == voice }.sortedBy { it.beat }

    /** Onset of the latest note or rest at or before [beat]. */
    fun cursorBeat(beat: Double): Double = notes.map { it.beat }.filter { it <= beat + 0.001 }.maxOrNull() ?: 1.0

    fun nearestOnset(beat: Double): Double = notes.map { it.beat }.minByOrNull { abs(it - beat) } ?: 1.0

    /** Notes (not rests) held down at [beat], including ones still ringing from earlier. */
    fun soundingNotes(beat: Double, beatUnit: Int): List<Note> = notes.filter { n ->
        !n.isRest && n.beat <= beat + 0.001 && beat < n.beat + n.heldBeats(beatUnit) - 0.001
    }
}
