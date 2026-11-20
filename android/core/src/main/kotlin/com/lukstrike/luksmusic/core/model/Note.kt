// Note.kt — port of luksMusic/Models/Note.swift. Keep the two in step: same names, same numbers.
package com.lukstrike.luksmusic.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID
import kotlin.math.abs
import kotlin.math.pow

/** The seven natural note names. */
@Serializable
enum class NoteName(val baseSemitone: Int, val diatonicIndex: Int) {
    C(0, 0), D(2, 1), E(4, 2), F(5, 3), G(7, 4), A(9, 5), B(11, 6);

    companion object {
        fun fromDiatonic(index: Int): NoteName = entries[Math.floorMod(index, 7)]
    }
}

@Serializable
enum class Accidental(val semitoneOffset: Int, val symbol: String) {
    @SerialName("natural") NATURAL(0, "♮"),
    @SerialName("sharp") SHARP(1, "♯"),
    @SerialName("flat") FLAT(-1, "♭"),
    @SerialName("doubleSharp") DOUBLE_SHARP(2, "𝄪"),
    @SerialName("doubleFlat") DOUBLE_FLAT(-2, "𝄫"),
}

/** Absolute pitch in scientific notation (middle C = C4 = MIDI 60). */
@Serializable
data class Pitch(
    val noteName: NoteName,
    val octave: Int,
    val accidental: Accidental = Accidental.NATURAL,
) {
    val midiNoteNumber: Int
        get() = ((octave + 1) * 12 + noteName.baseSemitone + accidental.semitoneOffset).coerceIn(0, 127)

    val displayName: String
        get() = noteName.name + (if (accidental == Accidental.NATURAL) "" else accidental.symbol) + octave

    /** Equal temperament, A4 = 440 Hz. */
    val frequency: Double get() = 440.0 * 2.0.pow((midiNoteNumber - 69) / 12.0)

    /** Diatonic steps from C0. */
    val diatonicAbsolute: Int get() = octave * 7 + noteName.diatonicIndex

    companion object {
        private val sharpSpelling = listOf(
            NoteName.C to Accidental.NATURAL, NoteName.C to Accidental.SHARP, NoteName.D to Accidental.NATURAL,
            NoteName.D to Accidental.SHARP, NoteName.E to Accidental.NATURAL, NoteName.F to Accidental.NATURAL,
            NoteName.F to Accidental.SHARP, NoteName.G to Accidental.NATURAL, NoteName.G to Accidental.SHARP,
            NoteName.A to Accidental.NATURAL, NoteName.A to Accidental.SHARP, NoteName.B to Accidental.NATURAL,
        )
        private val flatSpelling = listOf(
            NoteName.C to Accidental.NATURAL, NoteName.D to Accidental.FLAT, NoteName.D to Accidental.NATURAL,
            NoteName.E to Accidental.FLAT, NoteName.E to Accidental.NATURAL, NoteName.F to Accidental.NATURAL,
            NoteName.G to Accidental.FLAT, NoteName.G to Accidental.NATURAL, NoteName.A to Accidental.FLAT,
            NoteName.A to Accidental.NATURAL, NoteName.B to Accidental.FLAT, NoteName.B to Accidental.NATURAL,
        )

        /** Spells a MIDI note with sharps (or flats). */
        fun fromMidi(midi: Int, preferFlats: Boolean = false): Pitch {
            val (name, acc) = (if (preferFlats) flatSpelling else sharpSpelling)[Math.floorMod(midi, 12)]
            return Pitch(name, midi / 12 - 1, acc)
        }
    }
}

@Serializable
enum class NoteDuration(val relativeDuration: Double) {
    @SerialName("whole") WHOLE(1.0),
    @SerialName("dottedHalf") DOTTED_HALF(0.75),
    @SerialName("half") HALF(0.5),
    @SerialName("dottedQuarter") DOTTED_QUARTER(0.375),
    @SerialName("quarter") QUARTER(0.25),
    @SerialName("dottedEighth") DOTTED_EIGHTH(0.1875),
    @SerialName("eighth") EIGHTH(0.125),
    @SerialName("dottedSixteenth") DOTTED_SIXTEENTH(0.09375),
    @SerialName("sixteenth") SIXTEENTH(0.0625),
    @SerialName("thirtySecond") THIRTY_SECOND(0.03125);

    /** Quarter-note beats (4/4). */
    val beats: Double get() = relativeDuration * 4.0
}

/** Which staff of the grand staff (right hand = treble). */
@Serializable
enum class Staff {
    @SerialName("treble") TREBLE,
    @SerialName("bass") BASS,
}

@Serializable
enum class Articulation {
    @SerialName("staccato") STACCATO, @SerialName("legato") LEGATO, @SerialName("accent") ACCENT,
    @SerialName("tenuto") TENUTO, @SerialName("fermata") FERMATA, @SerialName("marcato") MARCATO,
    @SerialName("staccatissimo") STACCATISSIMO, @SerialName("portato") PORTATO,
    @SerialName("tremoloSingle") TREMOLO_SINGLE, @SerialName("tremoloDouble") TREMOLO_DOUBLE,
    @SerialName("trill") TRILL,
}

@Serializable
enum class Dynamic(val midiVelocity: Int) {
    @SerialName("ppp") PPP(16), @SerialName("pp") PP(33), @SerialName("p") P(49), @SerialName("mp") MP(64),
    @SerialName("mf") MF(80), @SerialName("f") F(96), @SerialName("ff") FF(112), @SerialName("fff") FFF(127),
    @SerialName("sfz") SFZ(120), @SerialName("sfp") SFP(100), @SerialName("fp") FP(96), @SerialName("rfz") RFZ(112),
    @SerialName("crescendo") CRESCENDO(80), @SerialName("decrescendo") DECRESCENDO(64),
}

/** A note or rest. [beat] is 1-based within the measure, in the time signature's beat. */
@Serializable
data class Note(
    val id: String = UUID.randomUUID().toString(),
    val pitch: Pitch,
    val duration: NoteDuration = NoteDuration.QUARTER,
    val velocity: Int = 80,
    val isRest: Boolean = false,
    val isTied: Boolean = false,
    val staff: Staff = Staff.TREBLE,
    val voice: Int = 1,
    val articulation: Articulation? = null,
    val dynamic: Dynamic? = null,
    val fingerNumber: Int? = null,
    val lyric: String? = null,
    val isTriplet: Boolean = false,
    val beat: Double = 1.0,
    /** Held length in the signature's beat, exact for tuplets and ties; null derives it from [duration]. */
    val length: Double? = null,
    /** Continues a tie: the key stays down, it is not struck again. */
    val isTieContinuation: Boolean? = null,
) {
    val midiNote: Int get() = if (isRest) 0 else pitch.midiNoteNumber

    /** Diatonic steps from the staff's middle line (B4 treble, D3 bass). */
    val staffPosition: Int
        get() = if (isRest) 0 else pitch.diatonicAbsolute - if (staff == Staff.TREBLE) 34 else 22

    val stemUp: Boolean get() = staffPosition < 0
    val ledgerLinesAbove: Int get() = if (staffPosition >= 6) (staffPosition - 4) / 2 else 0
    val ledgerLinesBelow: Int get() = if (staffPosition <= -6) (abs(staffPosition) - 4) / 2 else 0

    fun durationInSeconds(tempo: Int): Double = duration.beats / (tempo / 60.0)

    /** How long the key is held in the signature's beat (`beatUnit` = its denominator). */
    fun heldBeats(beatUnit: Int): Double =
        length ?: (duration.beats * (if (isTriplet) 2.0 / 3.0 else 1.0) * beatUnit / 4.0)

    companion object {
        fun rest(duration: NoteDuration = NoteDuration.QUARTER, staff: Staff = Staff.TREBLE, voice: Int = 1, beat: Double = 1.0) =
            Note(pitch = Pitch(NoteName.C, 4), duration = duration, velocity = 0, isRest = true, staff = staff, voice = voice, beat = beat)
    }
}
