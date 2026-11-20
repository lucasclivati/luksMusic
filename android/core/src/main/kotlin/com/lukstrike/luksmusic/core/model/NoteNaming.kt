// NoteNaming.kt — notes are named with letters (C, D, E) in English and in solfège (Dó, Ré, Mi) in Portuguese
// (iOS AppLanguage.usesLetterNames). The app decides `usesLetters` from its language: see ui/AppLanguage.kt.
package com.lukstrike.luksmusic.core.model

object NoteNaming {
    private val solfege = mapOf(
        NoteName.C to "Dó", NoteName.D to "Ré", NoteName.E to "Mi", NoteName.F to "Fá",
        NoteName.G to "Sol", NoteName.A to "Lá", NoteName.B to "Si",
    )
    private val solfegeChromatic = listOf("Dó", "Dó♯", "Ré", "Ré♯", "Mi", "Fá", "Fá♯", "Sol", "Sol♯", "Lá", "Lá♯", "Si")
    private val letterChromatic = listOf("C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B")

    /** "Dó" / "C" for a natural note name. */
    fun name(noteName: NoteName, usesLetters: Boolean): String =
        if (usesLetters) noteName.name else solfege.getValue(noteName)

    /** "Fá♯" / "F♯" for a pitch, without the octave. */
    fun name(pitch: Pitch, usesLetters: Boolean): String =
        name(pitch.noteName, usesLetters) + (if (pitch.accidental == Accidental.NATURAL) "" else pitch.accidental.symbol)

    /** "Dó♯" / "C♯" for a MIDI note, spelled with sharps, without the octave. */
    fun chromaticName(midi: Int, usesLetters: Boolean): String =
        (if (usesLetters) letterChromatic else solfegeChromatic)[Math.floorMod(midi, 12)]

    /** "Dó♯4" / "C♯4". */
    fun nameWithOctave(midi: Int, usesLetters: Boolean): String = chromaticName(midi, usesLetters) + (midi / 12 - 1)
}
