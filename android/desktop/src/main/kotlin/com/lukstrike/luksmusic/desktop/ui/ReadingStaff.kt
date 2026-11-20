// ReadingStaff.kt — the staff of the sight-reading drill (adapted from the Android app's feature/learn/ReadingStaff.kt),
// drawn as large as the screen allows so it can be read from the music stand: one clef (sol, fá or dó), the key
// signature and the passage's notes, each colored by how it was read. A wrong key shows faintly where it would be
// written, and a note's name appears under it once it was found.
package com.lukstrike.luksmusic.desktop.ui

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.graphics.drawscope.inset
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingStep
import com.lukstrike.luksmusic.core.lessons.ReadingStepResult
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Clef
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Pitch
import com.lukstrike.luksmusic.core.model.Staff
import com.lukstrike.luksmusic.desktop.ui.MusicGlyphs.accidental
import com.lukstrike.luksmusic.desktop.ui.MusicGlyphs.bassClef
import com.lukstrike.luksmusic.desktop.ui.MusicGlyphs.trebleClef
import kotlin.math.abs

/** One staff. [current] is the step being read ([steps].size when the passage is done). */
@Composable
fun ReadingStaff(
    steps: List<ReadingStep>,
    accidentals: List<List<Accidental?>>,
    results: List<ReadingStepResult>,
    current: Int,
    clef: Clef,
    keySignature: Int,
    usesLetters: Boolean,
    modifier: Modifier = Modifier,
    wrongPitch: Pitch? = null,
    listeningStep: Int? = null,
    /** Steps above and below the middle line always kept in view (smaller on a grand staff, so its notes are bigger). */
    minReach: Int = 9,
) {
    val measurer = rememberTextMeasurer()
    val highlight by animateFloatAsState(current.toFloat(), spring(stiffness = Spring.StiffnessMediumLow), label = "staffHighlight")
    Canvas(modifier) {
        StaffPainter(steps, accidentals, results, current, clef, keySignature, wrongPitch, listeningStep, usesLetters, minReach, measurer)
            .draw(this, highlight)
    }
}

/**
 * Both staves, one above the other, drawn with one size and their columns lined up. Each note goes on the staff it
 * belongs to.
 */
@Composable
fun GrandStaff(
    steps: List<ReadingStep>,
    accidentals: List<List<Accidental?>>,
    results: List<ReadingStepResult>,
    current: Int,
    keySignature: Int,
    usesLetters: Boolean,
    modifier: Modifier = Modifier,
    wrongPitch: Pitch? = null,
    listeningStep: Int? = null,
) {
    val measurer = rememberTextMeasurer()
    val highlight by animateFloatAsState(current.toFloat(), spring(stiffness = Spring.StiffnessMediumLow), label = "grandHighlight")
    Canvas(modifier) {
        val painters = listOf(Staff.TREBLE, Staff.BASS).map { staff ->
            val wrong = wrongPitch?.takeIf { (staff == Staff.TREBLE) == (it.midiNoteNumber >= 60) }
            StaffPainter(
                steps.map { step -> step.copy(notes = step.notes.filter { it.staff == staff }) },
                steps.zip(accidentals) { step, marks -> step.notes.zip(marks).filter { it.first.staff == staff }.map { it.second } },
                results, current, Clef.of(staff), keySignature, wrong, listeningStep, usesLetters, 7, measurer,
            )
        }
        val half = size.height / 2
        val unit = painters.minOf { with(it) { naturalUnit(half) } }
        inset(0f, 0f, 0f, half) { painters[0].draw(this, highlight, unit) }
        inset(0f, half, 0f, 0f) { painters[1].draw(this, highlight, unit) }
    }
}

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
    val usesLetters: Boolean,
    val minReach: Int,
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
        val duration = step.notes.firstOrNull()?.duration ?: NoteDuration.QUARTER
        val length = if (duration in setOf(NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND)) 8 else 7
        val stemTip = if (stemUp) maxOf(high + length, 0) else minOf(low - length, 0)
        return StaffColumn(x, positions, displaced, stemUp, stemTip)
    }

    private fun probeRange(): Pair<Int, Int> {
        val probes = mutableListOf(-minReach, minReach)
        for (step in steps) {
            val probe = column(step, 0f)
            probes += probe.positions
            if (step.notes.isNotEmpty() && hasStem(step.notes.first().duration)) probes += probe.stemTip
        }
        wrongPitch?.let { probes += position(it) }
        return probes.max() + 1 to probes.min() - 1
    }

    private fun namedLines(): Int = steps.indices.filter(::showsName).maxOfOrNull { steps[it].notes.size } ?: 0

    /** The half-space that fits this staff, its notes and their names in [height]. */
    fun DrawScope.naturalUnit(height: Float): Float {
        val (highest, lowest) = probeRange()
        val rough = (height - 6.dp.toPx()) / (highest - lowest + 3.2f * maxOf(1, namedLines()))
        return rough.coerceIn(2.5.dp.toPx(), 22.dp.toPx())
    }

    fun draw(scope: DrawScope, highlight: Float, fixedUnit: Float? = null) = with(scope) {
        if (size.width < 40.dp.toPx() || size.height < 40.dp.toPx()) return@with

        val probes = mutableListOf(-minReach, minReach)
        for (step in steps) {
            val probe = column(step, 0f)
            probes += probe.positions
            if (step.notes.isNotEmpty() && hasStem(step.notes.first().duration)) probes += probe.stemTip
        }
        wrongPitch?.let { probes += position(it) }
        val highest = probes.max() + 1
        val lowest = probes.min() - 1
        val namedLines = steps.indices.filter(::showsName).maxOfOrNull { steps[it].notes.size } ?: 0
        // The unit (half a space) is chosen first from the height, then the names' room is taken from it
        val topPad = 6.dp.toPx()
        val unit = fixedUnit ?: naturalUnit(size.height)
        val nameLine = unit * 2.9f
        val bottomPad = maxOf(1, namedLines) * nameLine + unit * 0.6f
        val usedHeight = (highest - lowest) * unit
        val originY = topPad + maxOf(0f, (size.height - topPad - bottomPad - usedHeight) / 2)
        val layout = StaffLayout(unit, highest, originY)
        val space = layout.space
        val line = maxOf(1.2.dp.toPx(), unit * 0.13f)

        val left = 14.dp.toPx()
        val right = size.width - 14.dp.toPx()
        val clefWidth = space * 3.2f
        val keyCount = minOf(7, abs(keySignature))
        val notesStart = left + clefWidth + keyCount * space * 0.95f + space * 1.2f
        val columnWidth = if (steps.isEmpty()) 0f else minOf((right - notesStart - space * 0.9f) / steps.size, space * 9)
        val columns = steps.mapIndexed { index, step -> column(step, notesStart + columnWidth * (index + 0.5f)) }

        val corner = CornerRadius(10.dp.toPx())
        fun columnBox(at: Float) = Rect(
            Offset(notesStart + columnWidth * at + 3.dp.toPx(), layout.y(highest)),
            Size(columnWidth - 6.dp.toPx(), usedHeight),
        )
        if (current < steps.size && steps.isNotEmpty()) {
            val box = columnBox(highlight.coerceIn(0f, (steps.size - 1).toFloat()))
            drawRoundRect(StaffColors.current.copy(alpha = 0.11f), box.topLeft, box.size, corner)
        }
        listeningStep?.takeIf { it in steps.indices }?.let {
            val box = columnBox(it.toFloat())
            drawRoundRect(StaffColors.listening.copy(alpha = 0.28f), box.topLeft, box.size, corner)
        }

        for (staffLine in -4..4 step 2) {
            drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(left, layout.y(staffLine)), Offset(right, layout.y(staffLine)), line)
        }
        drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(left, layout.y(4)), Offset(left, layout.y(-4)), line)

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

        // Barlines and measure numbers
        val numberStyle = TextStyle(color = Color.Gray, fontSize = (unit * 1.5f).toSp(), fontWeight = FontWeight.SemiBold)
        steps.forEachIndexed { index, step ->
            val boundary = notesStart + columnWidth * index
            if (index == 0 || steps[index - 1].measureIndex != step.measureIndex) {
                if (index > 0) {
                    drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(boundary, layout.y(4)), Offset(boundary, layout.y(-4)), line)
                }
                if (step.measureNumber > 0) {
                    val text = measurer.measure("${step.measureNumber}", numberStyle)
                    drawText(text, topLeft = Offset(boundary + 3.dp.toPx(), maxOf(0f, layout.y(4) - unit * 2.4f - text.size.height / 2f)))
                }
            }
        }
        drawLine(StaffColors.ink.copy(alpha = 0.85f), Offset(right, layout.y(4)), Offset(right, layout.y(-4)), line)

        val headWidth = space * 1.3f
        val headHeight = space * 0.95f
        val nameStyle = TextStyle(fontSize = (unit * 1.75f).toSp(), fontWeight = FontWeight.Bold)
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
                drawLedgerLines(layout, position, x, headWidth, StaffColors.ink.copy(alpha = 0.8f), line * 1.1f)
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
                val stemX = if (column.stemUp) column.x + headWidth / 2 - line / 2 else column.x - headWidth / 2 + line / 2
                drawLine(stepColor, Offset(stemX, layout.y(if (column.stemUp) low else high)), Offset(stemX, layout.y(column.stemTip)), line * 1.3f)
                val flags = when (duration) {
                    NoteDuration.EIGHTH, NoteDuration.DOTTED_EIGHTH -> 1
                    NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND -> 2
                    else -> 0
                }
                for (flag in 0 until flags) {
                    drawPath(MusicGlyphs.flag(Offset(stemX, layout.y(column.stemTip)), space, column.stemUp, flag), stepColor)
                }
            }

            if (showsName(index)) {
                val nameColor = if (result.isDone) stepColor else StaffColors.fixed
                step.notes.reversed().filter { !it.isRest }.forEachIndexed { lineIndex, note ->
                    val text = measurer.measure(ReadingDrill.name(note.pitch, usesLetters), nameStyle.copy(color = nameColor))
                    drawText(text, topLeft = Offset(column.x - text.size.width / 2f, layout.y(lowest) + unit * 0.6f + lineIndex * nameLine))
                }
            }
        }

        if (wrongPitch != null && current < columns.size) {
            val wrongPosition = position(wrongPitch)
            val x = columns[current].x + headWidth * 1.15f
            drawLedgerLines(layout, wrongPosition, x, headWidth, StaffColors.wrong.copy(alpha = 0.5f), line * 1.1f)
            drawHead(Offset(x, layout.y(wrongPosition)), headWidth, headHeight, false, StaffColors.wrong.copy(alpha = 0.6f), unit * 0.38f)
        }
    }

    private fun showsName(index: Int): Boolean {
        if (index >= results.size) return false
        return results[index].isDone || (index == current && results[index].revealed)
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
            NoteDuration.WHOLE -> drawRect(ink, Offset(x - space * 0.7f, layout.y(2)), Size(space * 1.4f, space * 0.5f))
            NoteDuration.HALF, NoteDuration.DOTTED_HALF ->
                drawRect(ink, Offset(x - space * 0.7f, layout.y(0) - space * 0.5f), Size(space * 1.4f, space * 0.5f))
            NoteDuration.QUARTER, NoteDuration.DOTTED_QUARTER -> drawPath(MusicGlyphs.quarterRest(box(space * 1.05f, space * 3.0f)), ink)
            NoteDuration.EIGHTH, NoteDuration.DOTTED_EIGHTH -> drawPath(MusicGlyphs.eighthRest(box(space * 1.1f, space * 2.2f)), ink)
            NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND ->
                drawPath(MusicGlyphs.sixteenthRest(box(space * 1.1f, space * 2.8f)), ink)
        }
    }
}

/** A notehead, tilted like an engraved one. */
internal fun DrawScope.drawHead(center: Offset, width: Float, height: Float, hollow: Boolean, color: Color, lineWidth: Float) {
    translate(center.x, center.y) {
        rotate(-20f, pivot = Offset.Zero) {
            val topLeft = Offset(-width / 2, -height / 2)
            if (hollow) drawOval(color, topLeft, Size(width, height), style = Stroke(lineWidth))
            else drawOval(color, topLeft, Size(width, height))
        }
    }
}

/** Ledger lines for a note at [position] steps from the middle line. */
internal fun DrawScope.drawLedgerLines(
    layoutY: (Int) -> Float, position: Int, x: Float, headWidth: Float, color: Color, width: Float,
) {
    val lines = when {
        position >= 6 -> (6..position step 2).toList()
        position <= -6 -> (-6 downTo position step 2).toList()
        else -> emptyList()
    }
    for (ledger in lines) {
        drawLine(color, Offset(x - headWidth * 0.8f, layoutY(ledger)), Offset(x + headWidth * 0.8f, layoutY(ledger)), width)
    }
}

private fun DrawScope.drawLedgerLines(layout: StaffLayout, position: Int, x: Float, headWidth: Float, color: Color, width: Float) =
    drawLedgerLines(layout::y, position, x, headWidth, color, width)
