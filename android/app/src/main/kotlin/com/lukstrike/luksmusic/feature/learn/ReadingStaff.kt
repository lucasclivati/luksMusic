// ReadingStaff.kt — port of luksMusic/Views/Practice/ReadingStaffView.swift (and LessonPlayerView's GrandStaffView).
//
// The staff drawn for the lessons and the sight-reading drill: one clef (sol, fá or dó), the key signature and the
// segment's notes, each colored by how it was read. A wrong key shows faintly where it would be written, and a
// note's name appears under it once it was found.
package com.lukstrike.luksmusic.feature.learn

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingStep
import com.lukstrike.luksmusic.core.lessons.ReadingStepResult
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Clef
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Staff
import com.lukstrike.luksmusic.feature.learn.MusicGlyphs.accidental
import com.lukstrike.luksmusic.feature.learn.MusicGlyphs.bassClef
import com.lukstrike.luksmusic.feature.learn.MusicGlyphs.drawCenteredInk
import com.lukstrike.luksmusic.feature.learn.MusicGlyphs.trebleClef
import com.lukstrike.luksmusic.ui.usesLetterNames
import kotlin.math.abs

object StaffColors {
    val ink = Color(0.07f, 0.09f, 0.13f)
    val current = Color(0.14f, 0.42f, 0.94f)
    val right = Color(0.09f, 0.62f, 0.27f)
    /** Found after a wrong key or a hint */
    val fixed = Color(0.90f, 0.50f, 0.04f)
    val wrong = Color(0.86f, 0.15f, 0.15f)
    val listening = Color(1f, 0.84f, 0f)
}

/**
 * One staff. [current] is the step being read ([steps].size when the segment is done); [listeningStep] the one
 * being heard; [showsAllNames] writes every note's name from the start (a lesson introducing notes);
 * [timeSignature] draws beats per measure over 4.
 */
@Composable
fun ReadingStaff(
    steps: List<ReadingStep>,
    accidentals: List<List<Accidental?>>,
    results: List<ReadingStepResult>,
    current: Int,
    clef: Clef,
    keySignature: Int,
    modifier: Modifier = Modifier,
    wrongPitch: Pitch? = null,
    listeningStep: Int? = null,
    showsAllNames: Boolean = false,
    timeSignature: Int? = null,
) {
    val measurer = rememberTextMeasurer()
    val letters = usesLetterNames()
    val clefName = stringResource(
        when (clef) { Clef.TREBLE -> R.string.learn_clef_treble; Clef.BASS -> R.string.learn_clef_bass; Clef.ALTO -> R.string.learn_clef_alto }
    )
    val description = pluralStringResource(R.plurals.learn_staff_notes, steps.size, clefName, steps.size)
    // The highlight glides to the next column
    val highlight by animateFloatAsState(
        current.toFloat(), spring(stiffness = Spring.StiffnessMediumLow), label = "staffHighlight",
    )
    Canvas(modifier.semantics { contentDescription = description }) {
        StaffPainter(
            steps, accidentals, results, current, clef, keySignature, wrongPitch, listeningStep, showsAllNames,
            timeSignature, letters, measurer,
        ).draw(this, highlight)
    }
}

/** Both staves, one above the other, with their columns lined up. Each note goes on the staff it belongs to. */
@Composable
fun GrandStaff(
    steps: List<ReadingStep>,
    accidentals: List<List<Accidental?>>,
    results: List<ReadingStepResult>,
    current: Int,
    keySignature: Int,
    modifier: Modifier = Modifier,
    wrongPitch: Pitch? = null,
    listeningStep: Int? = null,
    showsAllNames: Boolean = false,
    timeSignature: Int? = null,
) {
    Column(modifier) {
        for (staff in listOf(Staff.TREBLE, Staff.BASS)) {
            // A wrong key is drawn on the staff that would write it
            val wrong = wrongPitch?.takeIf { (staff == Staff.TREBLE) == (it.midiNoteNumber >= 60) }
            ReadingStaff(
                steps = steps.map { step -> step.copy(notes = step.notes.filter { it.staff == staff }) },
                accidentals = steps.zip(accidentals) { step, marks ->
                    step.notes.zip(marks).filter { it.first.staff == staff }.map { it.second }
                },
                results = results,
                current = current,
                clef = Clef.of(staff),
                keySignature = keySignature,
                modifier = Modifier.fillMaxWidth().weight(1f),
                wrongPitch = wrong,
                listeningStep = listeningStep,
                showsAllNames = showsAllNames,
                timeSignature = timeSignature,
            )
        }
    }
}

/** Pitch positions are diatonic steps from the staff's middle line (+1 is one step up). */
private class StaffLayout(val unit: Float, val topPosition: Int, val originY: Float) {
    val space get() = unit * 2
    fun y(position: Int): Float = originY + (topPosition - position) * unit
}

private class StaffColumn(val x: Float, val positions: List<Int>, val displaced: List<Boolean>, val stemUp: Boolean, val stemTip: Int)

private class StaffPainter(
    val steps: List<ReadingStep>,
    val accidentals: List<List<Accidental?>>,
    val results: List<ReadingStepResult>,
    val current: Int,
    val clef: Clef,
    val keySignature: Int,
    val wrongPitch: Pitch?,
    val listeningStep: Int?,
    val showsAllNames: Boolean,
    val timeSignature: Int?,
    val usesLetters: Boolean,
    val measurer: TextMeasurer,
) {
    private fun position(pitch: Pitch) = clef.position(pitch)

    private fun hasStem(duration: NoteDuration) = duration != NoteDuration.WHOLE

    private fun column(step: ReadingStep, x: Float): StaffColumn {
        val positions = step.notes.map { if (it.isRest) 0 else position(it.pitch) }
        val displaced = MutableList(positions.size) { false }
        for (index in 1 until positions.size) {
            if (positions[index] - positions[index - 1] == 1 && !displaced[index - 1]) displaced[index] = true
        }
        val low = positions.minOrNull() ?: 0
        val high = positions.maxOrNull() ?: 0
        val stemUp = low + high < 0
        // Stems are three and a half spaces long (four with two flags) and reach at least the middle line
        val duration = step.notes.firstOrNull()?.duration ?: NoteDuration.QUARTER
        val length = if (duration in setOf(NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND)) 8 else 7
        val stemTip = if (stemUp) maxOf(high + length, 0) else minOf(low - length, 0)
        return StaffColumn(x, positions, displaced, stemUp, stemTip)
    }

    fun draw(scope: DrawScope, highlight: Float) = with(scope) {
        if (size.width < 40.dp.toPx() || size.height < 40.dp.toPx()) return@with

        // Vertical room: the staff, every note, ledger line and stem of the segment, the wrong key
        val probes = mutableListOf(-10, 10)
        for (step in steps) {
            val probe = column(step, 0f)
            probes += probe.positions
            if (hasStem(step.notes.firstOrNull()?.duration ?: NoteDuration.QUARTER)) probes += probe.stemTip
        }
        wrongPitch?.let { probes += position(it) }
        val highest = probes.max() + 2
        val lowest = probes.min() - 2
        val namedLines = steps.indices.filter(::showsName).maxOfOrNull { steps[it].notes.size } ?: 0
        val topPad = 16.dp.toPx()
        val bottomPad = maxOf(1, namedLines) * 13.dp.toPx() + 6.dp.toPx()
        val unit = ((size.height - topPad - bottomPad) / (highest - lowest)).coerceIn(3.dp.toPx(), 9.dp.toPx())
        val usedHeight = (highest - lowest) * unit
        val originY = topPad + maxOf(0f, (size.height - topPad - bottomPad - usedHeight) / 2)
        val layout = StaffLayout(unit, highest, originY)
        val space = layout.space
        val line = 1.1.dp.toPx()

        // Columns
        val left = 10.dp.toPx()
        val right = size.width - 10.dp.toPx()
        val clefWidth = space * 3.2f
        val keyCount = minOf(7, abs(keySignature))
        val timeWidth = if (timeSignature == null) 0f else space * 1.8f
        val notesStart = left + clefWidth + keyCount * space * 0.95f + timeWidth + space * 1.2f
        // Room after the last column for an eighth's flag
        val columnWidth = if (steps.isEmpty()) 0f else minOf((right - notesStart - space * 0.9f) / steps.size, space * 7)
        val columns = steps.mapIndexed { index, step -> column(step, notesStart + columnWidth * (index + 0.5f)) }

        // Highlight behind the step being read (gliding between columns), and the one being heard
        val corner = CornerRadius(8.dp.toPx())
        fun columnBox(at: Float) = Rect(Offset(notesStart + columnWidth * at + 2.dp.toPx(), layout.y(highest)), Size(columnWidth - 4.dp.toPx(), usedHeight))
        if (current < steps.size && steps.isNotEmpty()) {
            val box = columnBox(highlight.coerceIn(0f, (steps.size - 1).toFloat()))
            drawRoundRect(StaffColors.current.copy(alpha = 0.09f), box.topLeft, box.size, corner)
        }
        listeningStep?.takeIf { it in steps.indices }?.let {
            val box = columnBox(it.toFloat())
            drawRoundRect(StaffColors.listening.copy(alpha = 0.22f), box.topLeft, box.size, corner)
        }

        // Staff lines
        for (staffLine in -4..4 step 2) {
            drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(left, layout.y(staffLine)), Offset(right, layout.y(staffLine)), line)
        }

        // Clef, sized and placed by its ink as an engraving font would: the treble clef's curl around the G line,
        // the bass clef's dots around the F line, the C clef's point on the middle line
        when (clef) {
            Clef.TREBLE -> trebleClef(left + space * 0.3f, layout.y(-7) + unit * 0.3f, space * 7.0f, layout.y(-2), space, StaffColors.ink)
            Clef.BASS -> bassClef(left + space * 0.3f, layout.y(-3) + unit * 0.1f, space * 3.6f, layout.y(2), space, StaffColors.ink)
            Clef.ALTO -> drawPath(MusicGlyphs.cClefPath(left + space * 0.3f, layout.y(0), space), StaffColors.ink)
        }
        val keySteps = clef.keySignatureSteps(sharps = keySignature > 0)
        for (index in 0 until keyCount) {
            accidental(
                if (keySignature > 0) Accidental.SHARP else Accidental.FLAT,
                left + clefWidth + space * (0.45f + 0.95f * index), layout.y(keySteps[index] - 4), space, StaffColors.ink,
            )
        }

        timeSignature?.let { top ->
            val x = left + clefWidth + keyCount * space * 0.95f + space * 0.9f
            for ((digit, at) in listOf(top to 2, 4 to -2)) {
                drawCenteredInk("$digit", x, layout.y(at), space * 2.1f, StaffColors.ink)
            }
        }

        // Barlines and measure numbers
        val numberStyle = TextStyle(color = Color.Gray, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
        steps.forEachIndexed { index, step ->
            val boundary = notesStart + columnWidth * index
            if (index == 0 || steps[index - 1].measureIndex != step.measureIndex) {
                if (index > 0) {
                    drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(boundary, layout.y(4)), Offset(boundary, layout.y(-4)), line)
                }
                // A pickup (measure 0) has no number
                if (step.measureNumber > 0) {
                    drawText(measurer, "${step.measureNumber}", Offset(boundary + 3.dp.toPx(), 2.dp.toPx()), numberStyle)
                }
            }
        }

        // Notes
        val headWidth = space * 1.3f
        val headHeight = space * 0.95f
        val nameStyle = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold)
        steps.forEachIndexed { index, step ->
            val column = columns[index]
            val result = results.getOrElse(index) { ReadingStepResult() }
            val duration = step.notes.firstOrNull()?.duration ?: NoteDuration.QUARTER
            val isHollow = duration == NoteDuration.WHOLE || duration == NoteDuration.HALF || duration == NoteDuration.DOTTED_HALF
            val isDotted = duration in setOf(NoteDuration.DOTTED_HALF, NoteDuration.DOTTED_QUARTER, NoteDuration.DOTTED_EIGHTH, NoteDuration.DOTTED_SIXTEENTH)
            val stepColor = color(index, result, null)
            var accidentalSlot = 0

            for (noteIndex in step.notes.indices.reversed()) {
                val note = step.notes[noteIndex]
                if (note.isRest) {
                    drawRest(note.duration, layout, column.x)
                    continue
                }
                val position = column.positions[noteIndex]
                val x = column.x + if (column.displaced[noteIndex]) headWidth * 0.95f else 0f
                val noteColor = color(index, result, note.midiNote)

                drawLedgerLines(layout, position, x, headWidth, StaffColors.ink.copy(alpha = 0.8f))
                drawHead(Offset(x, layout.y(position)), headWidth, headHeight, isHollow, noteColor, unit * 0.38f)

                if (isDotted) {
                    val dotY = layout.y(if (position % 2 == 0) position + 1 else position)
                    drawCircle(noteColor, unit * 0.3f, Offset(x + headWidth * 0.95f, dotY))
                }

                accidentals.getOrNull(index)?.getOrNull(noteIndex)?.let { mark ->
                    val ax = column.x - headWidth * 1.15f - accidentalSlot * space * 0.85f
                    accidental(mark, ax, layout.y(position), space, noteColor)
                    accidentalSlot += 1
                }
            }

            if (hasStem(duration) && !step.isRest && column.positions.isNotEmpty()) {
                val low = column.positions.min()
                val high = column.positions.max()
                val stemX = if (column.stemUp) column.x + headWidth / 2 - 0.7.dp.toPx() else column.x - headWidth / 2 + 0.7.dp.toPx()
                drawLine(stepColor, Offset(stemX, layout.y(if (column.stemUp) low else high)), Offset(stemX, layout.y(column.stemTip)), 1.5.dp.toPx())
                val flags = when (duration) {
                    NoteDuration.EIGHTH, NoteDuration.DOTTED_EIGHTH -> 1
                    NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND -> 2
                    else -> 0
                }
                for (flag in 0 until flags) {
                    drawPath(MusicGlyphs.flag(Offset(stemX, layout.y(column.stemTip)), space, column.stemUp, flag), stepColor)
                }
            }

            // The note's name once it was found, or when the answer was shown
            if (showsName(index)) {
                val nameColor = if (result.isDone) stepColor else if (showsAllNames) StaffColors.ink else StaffColors.fixed
                step.notes.reversed().filter { !it.isRest }.forEachIndexed { lineIndex, note ->
                    val text = measurer.measure(ReadingDrill.name(note.pitch, usesLetters), nameStyle.copy(color = nameColor))
                    drawText(text, topLeft = Offset(column.x - text.size.width / 2f, layout.y(lowest) + 4.dp.toPx() + lineIndex * 13.dp.toPx()))
                }
            }
        }

        // The wrong key, faint, beside the note being read
        if (wrongPitch != null && current < columns.size) {
            val wrongPosition = position(wrongPitch)
            val x = columns[current].x + headWidth * 1.15f
            drawLedgerLines(layout, wrongPosition, x, headWidth, StaffColors.wrong.copy(alpha = 0.5f))
            drawHead(Offset(x, layout.y(wrongPosition)), headWidth, headHeight, false, StaffColors.wrong.copy(alpha = 0.6f), unit * 0.38f)
        }
    }

    private fun showsName(index: Int): Boolean {
        if (index >= results.size) return showsAllNames
        return showsAllNames || results[index].isDone || (index == current && results[index].revealed)
    }

    private fun color(index: Int, result: ReadingStepResult, midi: Int?): Color {
        if (result.isDone) return if (result.isClean) StaffColors.right else StaffColors.fixed
        if (index == current) {
            if (midi != null && midi in result.played) return StaffColors.right
            return StaffColors.current
        }
        return StaffColors.ink
    }

    private fun DrawScope.drawRest(duration: NoteDuration, layout: StaffLayout, x: Float) {
        val space = layout.space
        val ink = StaffColors.ink
        fun box(width: Float, height: Float) = Rect(Offset(x - width / 2, layout.y(0) - height / 2), Size(width, height))
        when (duration) {
            // Hangs from the fourth line
            NoteDuration.WHOLE -> drawRect(ink, Offset(x - space * 0.7f, layout.y(2)), Size(space * 1.4f, space * 0.5f))
            // Sits on the middle line
            NoteDuration.HALF, NoteDuration.DOTTED_HALF ->
                drawRect(ink, Offset(x - space * 0.7f, layout.y(0) - space * 0.5f), Size(space * 1.4f, space * 0.5f))
            NoteDuration.QUARTER, NoteDuration.DOTTED_QUARTER -> drawPath(MusicGlyphs.quarterRest(box(space * 1.05f, space * 3.0f)), ink)
            NoteDuration.EIGHTH, NoteDuration.DOTTED_EIGHTH -> drawPath(MusicGlyphs.eighthRest(box(space * 1.1f, space * 2.2f)), ink)
            NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND ->
                drawPath(MusicGlyphs.sixteenthRest(box(space * 1.1f, space * 2.8f)), ink)
        }
    }

    private fun DrawScope.drawHead(center: Offset, width: Float, height: Float, hollow: Boolean, color: Color, lineWidth: Float) {
        translate(center.x, center.y) {
            rotate(-20f, pivot = Offset.Zero) {
                val topLeft = Offset(-width / 2, -height / 2)
                if (hollow) drawOval(color, topLeft, Size(width, height), style = Stroke(lineWidth))
                else drawOval(color, topLeft, Size(width, height))
            }
        }
    }

    private fun DrawScope.drawLedgerLines(layout: StaffLayout, position: Int, x: Float, headWidth: Float, color: Color) {
        val lines = when {
            position >= 6 -> (6..position step 2).toList()
            position <= -6 -> (-6 downTo position step 2).toList()
            else -> emptyList()
        }
        for (ledger in lines) {
            drawLine(color, Offset(x - headWidth * 0.8f, layout.y(ledger)), Offset(x + headWidth * 0.8f, layout.y(ledger)), 1.3.dp.toPx())
        }
    }
}
