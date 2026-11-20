// Clef.kt — port of luksMusic/Models/Clef.swift: the clefs (sol, fá, dó) and which one each hand's staff shows,
// shared by the score player and the reading drill.
package com.lukstrike.luksmusic.core.model

import kotlin.math.abs

enum class Clef {
    TREBLE, BASS,
    /** The C clef on the middle line. */
    ALTO;

    /** Diatonic steps from C0 to the note on the middle line: B4, D3, middle C. */
    val middleLine: Int
        get() = when (this) { TREBLE -> 34; BASS -> 22; ALTO -> 28 }

    /** Diatonic steps from the middle line to where [pitch] is written (+1 = one step up). */
    fun position(pitch: Pitch): Int = pitch.diatonicAbsolute - middleLine

    /** Ledger lines [pitch] needs above or below the five lines. */
    fun ledgerLines(pitch: Pitch): Int {
        val distance = abs(position(pitch))
        return if (distance >= 6) (distance - 4) / 2 else 0
    }

    /** Where the key signature's sharps or flats go, in steps above the bottom line, in writing order. */
    fun keySignatureSteps(sharps: Boolean): List<Int> = when (this) {
        TREBLE -> if (sharps) listOf(8, 5, 9, 6, 3, 7, 4) else listOf(4, 7, 3, 6, 2, 5, 1)
        BASS -> if (sharps) listOf(6, 3, 7, 4, 1, 5, 2) else listOf(2, 5, 1, 4, 0, 3, -1)
        ALTO -> if (sharps) listOf(7, 4, 8, 5, 2, 6, 3) else listOf(3, 6, 2, 5, 1, 4, 0)
    }

    companion object {
        /** The clef a piano staff usually has: treble for the right hand, bass for the left. */
        fun of(staff: Staff): Clef = if (staff == Staff.TREBLE) TREBLE else BASS

        /** The clef that writes [pitches] with the fewest ledger lines. Ties keep [usual], then the other piano clef. */
        fun fewestLedgerLines(pitches: List<Pitch>, usual: Clef, usesAlto: Boolean): Clef {
            val candidates = mutableListOf(usual, if (usual == BASS) TREBLE else BASS)
            if (usesAlto) candidates += ALTO
            return candidates.minByOrNull { clef -> pitches.sumOf { clef.ledgerLines(it) } } ?: usual
        }
    }
}

/** Which clef a hand's staff shows. Raw names match the iOS saved values. */
enum class ClefChoice(val raw: String) {
    /** The score's own clefs (in the reading drill, sol for the right hand and fá for the left). */
    SCORE("score"),
    /** The clef with the fewest ledger lines, changing as the music climbs or falls. */
    AUTOMATIC("automatic"),
    TREBLE("treble"), BASS("bass"), ALTO("alto");

    /** The clef shown throughout, for a choice that does not depend on the notes. */
    val fixedClef: Clef?
        get() = when (this) { TREBLE -> Clef.TREBLE; BASS -> Clef.BASS; ALTO -> Clef.ALTO; SCORE, AUTOMATIC -> null }

    companion object {
        fun fromRaw(raw: String?): ClefChoice = entries.firstOrNull { it.raw == raw } ?: SCORE

        // Remembered choices (settings keys), shared by the score player and the reading drill
        const val RIGHT_HAND_KEY = "clefChoice.right"
        const val LEFT_HAND_KEY = "clefChoice.left"
        /** Whether the automatic choice may use the alto clef besides sol and fá. */
        const val AUTOMATIC_USES_ALTO_KEY = "clefChoice.automaticUsesAlto"

        fun key(staff: Staff): String = if (staff == Staff.TREBLE) RIGHT_HAND_KEY else LEFT_HAND_KEY
    }
}
