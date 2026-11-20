// ScorePlayback.kt — what the score player reads from a score while it plays (the pure half of iOS
// ScoreViewModel): the timeline in seconds, the notes each tick strikes and how long they ring, the keys under the
// cursor by hand with their names, and the key a transposition lands in. The timer and the sound live in the app.
package com.lukstrike.luksmusic.core.playback

import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.Staff
import kotlin.math.abs
import kotlin.math.max

/** The keys under the playback cursor: right hand (treble staff) and left hand (bass staff), already transposed. */
data class CursorNotes(
    /** Onset the cursor rests on in the current measure (drives the engraved score's cursor). */
    val cursorBeat: Double = 1.0,
    val trebleMidi: Set<Int> = emptySet(),
    val bassMidi: Set<Int> = emptySet(),
    /** "Sol4, Sol5", or "G4, G5" in English; empty for a rest. */
    val trebleNames: String = "",
    val bassNames: String = "",
) {
    val allMidi: Set<Int> get() = trebleMidi + bassMidi
}

/** One note to strike: the MIDI key (transposed), its velocity after the hand's volume, and how long it rings. */
data class StruckNote(val noteId: String, val midi: Int, val velocity: Int, val durationSeconds: Double)

/** The hands mixer: each hand's volume (0..1) and whether it is silenced. */
data class HandsMixer(
    val trebleVolume: Double = 0.95,
    val bassVolume: Double = 0.9,
    val trebleMuted: Boolean = false,
    val bassMuted: Boolean = false,
) {
    fun isMuted(staff: Staff): Boolean = if (staff == Staff.TREBLE) trebleMuted else bassMuted
    fun volume(staff: Staff): Double = if (staff == Staff.TREBLE) trebleVolume else bassVolume
}

class ScorePlayback(val score: Score) {

    val measures: List<Measure> = score.measures
    val measureCount: Int get() = measures.size

    /** Beats in one measure, in the time signature's unit (the unit the player's clock counts). */
    val beatsPerMeasure: Double get() = max(1, score.timeSignatureTop).toDouble()

    /** Beats from the start of the piece to each measure (a pickup counts only its own beats), plus the total. */
    private val beatsBefore: DoubleArray = DoubleArray(measures.size + 1).also { sums ->
        measures.forEachIndexed { i, m -> sums[i + 1] = sums[i] + m.beats(score.timeSignatureTop) }
    }

    private val secondsPerBeat: Double get() = 60.0 / max(1, score.tempo)

    /** Length of measure [index] in beats (the time signature's when out of range). */
    fun measureLength(index: Int): Double =
        measures.getOrNull(index)?.beats(score.timeSignatureTop) ?: beatsPerMeasure

    /** Position of the cursor in the piece, in seconds at the written tempo. */
    fun elapsedSeconds(measure: Int, beat: Double): Double =
        (beatsBefore[measure.coerceIn(0, measures.size)] + beat - 1) * secondsPerBeat

    /** Length of the piece in seconds at the written tempo. */
    val totalSeconds: Double get() = beatsBefore[measures.size] * secondsPerBeat

    /** The onsets of a measure's notes and rests, in order. */
    fun onsets(measure: Int): List<Double> =
        measures.getOrNull(measure)?.notes?.map { it.beat }?.distinct()?.sorted().orEmpty()

    // MARK: Striking notes

    /**
     * Notes of measure [measure] whose onset falls in (startBeat, endBeat], for one clock tick. After a barline the
     * player asks from 0.95 so the first beat's notes sound.
     */
    fun notesBetween(measure: Int, startBeat: Double, endBeat: Double, mixer: HandsMixer, transposition: Int, bpm: Double) =
        struck(measure, mixer, transposition, bpm) { it.beat > startBeat && it.beat <= endBeat }

    /** Notes of measure [measure] starting at [beat] (within 0.08 of a beat): on play and on seek. */
    fun notesAround(measure: Int, beat: Double, mixer: HandsMixer, transposition: Int, bpm: Double) =
        struck(measure, mixer, transposition, bpm) { abs(it.beat - beat) <= 0.08 }

    private inline fun struck(
        measure: Int, mixer: HandsMixer, transposition: Int, bpm: Double, include: (Note) -> Boolean,
    ): List<StruckNote> {
        val notes = measures.getOrNull(measure)?.notes ?: return emptyList()
        return notes.filter { isStruck(it, mixer) && include(it) }.map { note ->
            StruckNote(
                noteId = note.id,
                midi = (note.midiNote + transposition).coerceIn(0, 127),
                velocity = (note.velocity * mixer.volume(note.staff)).toInt().coerceIn(0, 127),
                // Never shorter than 0.12 s, so the fastest notes still speak
                durationSeconds = max(0.12, note.heldBeats(score.timeSignatureBottom) * 60.0 / bpm),
            )
        }
    }

    /** Notes the player strikes: not rests, not the held end of a tie, and not on a muted hand. */
    private fun isStruck(note: Note, mixer: HandsMixer): Boolean =
        !note.isRest && note.isTieContinuation != true && !mixer.isMuted(note.staff)

    // MARK: Keys under the cursor

    /** The keys held at the cursor's onset in measure [measure] (ringing notes included), by hand, with names. */
    fun cursorNotes(measure: Int, beat: Double, transposition: Int, usesLetters: Boolean): CursorNotes {
        val m = measures.getOrNull(measure) ?: return CursorNotes()
        val onset = m.cursorBeat(beat)
        val notes = m.soundingNotes(onset, score.timeSignatureBottom)
        val treble = notes.filter { it.staff == Staff.TREBLE }
        val bass = notes.filter { it.staff == Staff.BASS }
        return CursorNotes(
            cursorBeat = onset,
            trebleMidi = treble.map { it.midiNote + transposition }.toSet(),
            bassMidi = bass.map { it.midiNote + transposition }.toSet(),
            trebleNames = noteNames(treble, transposition, usesLetters),
            bassNames = noteNames(bass, transposition, usesLetters),
        )
    }

    companion object {
        private val solfegeBySemitone = listOf("Dó", "Dó♯", "Ré", "Mi♭", "Mi", "Fá", "Fá♯", "Sol", "Lá♭", "Lá", "Si♭", "Si")
        private val lettersBySemitone = listOf("C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B")

        // Indexed by the major tonic's pitch class (0 = C)
        private val fifthsByTonic = listOf(0, -5, 2, -3, 4, -1, -6, 1, -4, 3, -2, 5)
        private val keyTextByTonic = listOf(
            "C, a", "D♭, b♭", "D, b", "E♭, c", "E, c♯", "F, d", "F♯, d♯", "G, e", "A♭, f", "A, f♯", "B♭, g", "B, g♯",
        )

        /**
         * The notes with their octave, lowest first: in solfège ("Dó3, Sol3"), or with letters ("C3, G3") in English;
         * spelled from the score unless transposed.
         */
        fun noteNames(notes: List<Note>, transposition: Int, usesLetters: Boolean): String {
            val named = notes.map { note ->
                val midi = note.midiNote + transposition
                val name = if (transposition == 0) {
                    val accidental = if (note.pitch.accidental == Accidental.NATURAL) "" else note.pitch.accidental.symbol
                    NoteNaming.name(note.pitch.noteName, usesLetters) + accidental + note.pitch.octave
                } else {
                    val names = if (usesLetters) lettersBySemitone else solfegeBySemitone
                    names[Math.floorMod(midi, 12)] + (midi / 12 - 1)
                }
                midi to name
            }
            return named.sortedBy { it.first }.distinctBy { it.first }.joinToString(", ") { it.second }
        }

        private fun transposedTonic(keySignature: Int, transposition: Int): Int {
            val tonic = Math.floorMod(keySignature * 7, 12)
            return Math.floorMod(tonic + transposition, 12)
        }

        /** Sharps (>0) or flats (<0) of the key the score lands in when transposed. */
        fun keySignature(keySignature: Int, transposition: Int): Int =
            fifthsByTonic[transposedTonic(keySignature, transposition)]

        /** The major and relative minor key the score lands in when transposed ("D, b"). */
        fun keyText(keySignature: Int, transposition: Int): String =
            keyTextByTonic[transposedTonic(keySignature, transposition)]
    }
}
