// StaffStrip.kt — Modo Estudo's other view: the whole piece on one long grand staff that scrolls past a fixed
// playhead, like a tape. The notes come from core's ReadingDrill (both hands, every note, with the accidentals a
// printed score shows); the playhead is the same clock as the falling notes.
package com.lukstrike.luksmusic.desktop.study

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingHand
import com.lukstrike.luksmusic.core.lessons.ReadingNotes
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Clef
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.Staff
import com.lukstrike.luksmusic.desktop.ui.MusicGlyphs
import com.lukstrike.luksmusic.desktop.ui.MusicGlyphs.accidental
import com.lukstrike.luksmusic.desktop.ui.MusicGlyphs.bassClef
import com.lukstrike.luksmusic.desktop.ui.MusicGlyphs.trebleClef
import com.lukstrike.luksmusic.desktop.ui.Palette
import com.lukstrike.luksmusic.desktop.ui.StaffColors
import com.lukstrike.luksmusic.desktop.ui.drawHead
import com.lukstrike.luksmusic.desktop.ui.drawLedgerLines
import kotlin.math.abs

/** One chord of one staff on the strip. [beat] counts from 1 at the first measure, like the playhead. */
data class StripChord(
    val beat: Double,
    val staff: Staff,
    val midi: List<Int>,
    /** Steps from the staff's middle line, lowest first. */
    val positions: List<Int>,
    val accidentals: List<Accidental?>,
    val duration: NoteDuration,
    val heldBeats: Double,
) {
    val stemUp: Boolean get() = positions.first() + positions.last() < 0
}

/** The strip's music, laid out once per score (pure, tested). */
class StripMusic(score: Score) {
    val keySignature = score.keySignatureValue
    val beatsPerMeasure = maxOf(1, score.timeSignatureTop)

    /** Where each measure starts, in playhead beats, plus the end of the piece. */
    val barlines: List<Double> = score.measures.runningFold(1.0) { start, m -> start + m.beats(score.timeSignatureTop) }

    /** Each measure's printed number, by index (a pickup has 0). */
    val measureNumbers: List<Int> = score.measures.mapIndexed { index, m ->
        if (m.number > 0) m.number else if (index == 0 && m.length != null) 0 else index + 1
    }

    val chords: List<StripChord> = run {
        val steps = ReadingDrill.steps(score.measures, ReadingHand.BOTH, maxOf(1, score.timeSignatureTop), maxOf(1, score.timeSignatureBottom), ReadingNotes.ALL)
        val marks = ReadingDrill.printedAccidentals(steps, score.keySignatureValue)
        steps.zip(marks).flatMap { (step, stepMarks) ->
            Staff.entries.mapNotNull { staff ->
                val indexed = step.notes.indices.filter { step.notes[it].staff == staff }
                if (indexed.isEmpty()) return@mapNotNull null
                val clef = Clef.of(staff)
                val notes = indexed.map { step.notes[it] }
                StripChord(
                    beat = step.globalBeat + 1,
                    staff = staff,
                    midi = notes.map { it.midiNote },
                    positions = notes.map { clef.position(it.pitch) },
                    accidentals = indexed.map { stepMarks[it] },
                    duration = notes.first().duration,
                    heldBeats = notes.maxOf { it.heldBeats(maxOf(1, score.timeSignatureBottom)) },
                )
            }
        }.sortedBy { it.beat }
    }

    /** The chords whose beat is within [from]..[to]. */
    fun visible(from: Double, to: Double): List<StripChord> = chords.filter { it.beat in from..to }

    companion object {
        /** The x of [beat] with the playhead at [playhead] drawn at [playheadX]. */
        fun x(beat: Double, playhead: Double, playheadX: Float, pixelsPerBeat: Float): Float =
            playheadX + ((beat - playhead) * pixelsPerBeat).toFloat()
    }
}

@Composable
fun StaffStripView(
    music: StripMusic,
    playhead: () -> Double,
    targets: () -> Set<Int>,
    modifier: Modifier = Modifier,
) {
    val measurer = rememberTextMeasurer()
    Spacer(
        modifier.background(Palette.paper).drawWithCache {
            // Two staves: the treble's middle line, then the bass's 14 half-spaces lower
            val unit = size.height / 34f
            val space = unit * 2
            val trebleMiddle = unit * 10.5f
            val bassMiddle = trebleMiddle + unit * 14f
            fun y(staff: Staff, position: Int) = (if (staff == Staff.TREBLE) trebleMiddle else bassMiddle) - position * unit
            val keyCount = minOf(7, abs(music.keySignature))
            val headerWidth = space * 3.4f + keyCount * space * 0.95f + space * 0.6f
            val playheadX = headerWidth + space * 4f
            val pixelsPerBeat = space * 6f
            val line = maxOf(1.2f, unit * 0.12f)
            val headWidth = space * 1.3f
            val headHeight = space * 0.95f
            val numberStyle = TextStyle(color = Color.Gray, fontSize = (unit * 1.6f).toSp(), fontWeight = FontWeight.SemiBold)
            onDrawBehind {
                val beat = playhead()
                val lit = targets()
                val behind = (size.width - playheadX) / pixelsPerBeat
                val fromBeat = beat - (playheadX - headerWidth) / pixelsPerBeat - 1
                val toBeat = beat + behind + 1
                // Playhead band
                drawRect(StaffColors.current.copy(alpha = 0.10f), Offset(playheadX - space * 1.2f, 0f), Size(space * 2.4f, size.height))
                for (staff in Staff.entries) for (staffLine in -4..4 step 2) {
                    drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(0f, y(staff, staffLine)), Offset(size.width, y(staff, staffLine)), line)
                }
                // Barlines and measure numbers
                music.barlines.forEachIndexed { index, barBeat ->
                    if (barBeat < fromBeat || barBeat > toBeat) return@forEachIndexed
                    val x = StripMusic.x(barBeat, beat, playheadX, pixelsPerBeat)
                    if (x < headerWidth) return@forEachIndexed
                    drawLine(StaffColors.ink.copy(alpha = 0.8f), Offset(x, y(Staff.TREBLE, 4)), Offset(x, y(Staff.BASS, -4)), line)
                    music.measureNumbers.getOrNull(index)?.takeIf { it > 0 }?.let { number ->
                        val text = measurer.measure("$number", numberStyle)
                        drawText(text, topLeft = Offset(x + 4f, y(Staff.TREBLE, 4) - unit * 2.2f - text.size.height / 2f))
                    }
                }
                // Notes
                for (chord in music.visible(fromBeat, toBeat)) {
                    val x = StripMusic.x(chord.beat, beat, playheadX, pixelsPerBeat)
                    if (x < headerWidth + headWidth) continue
                    val passed = chord.beat + chord.heldBeats < beat - 0.02
                    val atPlayhead = chord.beat <= beat + 0.05 && beat < chord.beat + chord.heldBeats - 0.02
                    val color = when {
                        atPlayhead && chord.midi.any { it in lit } -> StaffColors.current
                        atPlayhead -> StaffColors.right
                        passed -> StaffColors.ink.copy(alpha = 0.35f)
                        else -> StaffColors.ink
                    }
                    val hollow = chord.duration in setOf(NoteDuration.WHOLE, NoteDuration.HALF, NoteDuration.DOTTED_HALF)
                    val dotted = chord.duration in setOf(NoteDuration.DOTTED_HALF, NoteDuration.DOTTED_QUARTER, NoteDuration.DOTTED_EIGHTH, NoteDuration.DOTTED_SIXTEENTH)
                    var previous = Int.MIN_VALUE
                    var shifted = false
                    var slot = 0
                    chord.positions.forEachIndexed { i, position ->
                        shifted = position - previous == 1 && !shifted
                        previous = position
                        val nx = x + if (shifted) headWidth * 0.95f else 0f
                        drawLedgerLines({ y(chord.staff, it) }, position, nx, headWidth, StaffColors.ink.copy(alpha = 0.7f), line * 1.1f)
                        drawHead(Offset(nx, y(chord.staff, position)), headWidth, headHeight, hollow, color, unit * 0.38f)
                        if (dotted) drawCircle(color, unit * 0.3f, Offset(nx + headWidth * 0.95f, y(chord.staff, if (position % 2 == 0) position + 1 else position)))
                        chord.accidentals[i]?.let { mark ->
                            accidental(mark, x - headWidth * 1.15f - slot * space * 0.85f, y(chord.staff, position), space, color)
                            slot += 1
                        }
                    }
                    if (chord.duration != NoteDuration.WHOLE) {
                        val up = chord.stemUp
                        val low = chord.positions.first()
                        val high = chord.positions.last()
                        val tip = if (up) maxOf(high + 7, 0) else minOf(low - 7, 0)
                        val stemX = if (up) x + headWidth / 2 - line / 2 else x - headWidth / 2 + line / 2
                        drawLine(color, Offset(stemX, y(chord.staff, if (up) low else high)), Offset(stemX, y(chord.staff, tip)), line * 1.3f)
                        val flags = when (chord.duration) {
                            NoteDuration.EIGHTH, NoteDuration.DOTTED_EIGHTH -> 1
                            NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND -> 2
                            else -> 0
                        }
                        for (flag in 0 until flags) drawPath(MusicGlyphs.flag(Offset(stemX, y(chord.staff, tip)), space, up, flag), color)
                    }
                }
                // The fixed header over the scrolling notes: clefs and key signature
                drawRect(Palette.paper, Offset.Zero, Size(headerWidth, size.height))
                for (staff in Staff.entries) for (staffLine in -4..4 step 2) {
                    drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(0f, y(staff, staffLine)), Offset(headerWidth, y(staff, staffLine)), line)
                }
                val left = space * 0.5f
                drawLine(StaffColors.ink, Offset(left - space * 0.2f, y(Staff.TREBLE, 4)), Offset(left - space * 0.2f, y(Staff.BASS, -4)), line * 2)
                trebleClef(left + space * 0.3f, y(Staff.TREBLE, -7) + unit * 0.3f, space * 7.0f, y(Staff.TREBLE, -2), space, StaffColors.ink)
                bassClef(left + space * 0.3f, y(Staff.BASS, -3) + unit * 0.1f, space * 3.6f, y(Staff.BASS, 2), space, StaffColors.ink)
                for (staff in Staff.entries) {
                    val steps = Clef.of(staff).keySignatureSteps(sharps = music.keySignature > 0)
                    for (index in 0 until keyCount) {
                        accidental(
                            if (music.keySignature > 0) Accidental.SHARP else Accidental.FLAT,
                            left + space * 3.2f + space * (0.45f + 0.95f * index), y(staff, steps[index] - 4), space, StaffColors.ink,
                        )
                    }
                }
                // The playhead
                drawLine(StaffColors.current.copy(alpha = 0.7f), Offset(playheadX, unit * 2), Offset(playheadX, size.height - unit * 2), 2.dp.toPx())
            }
        },
    )
}
