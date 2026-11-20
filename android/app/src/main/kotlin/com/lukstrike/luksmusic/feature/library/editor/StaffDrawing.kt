// StaffDrawing.kt — the native grand staff the editor draws, with Compose Canvas: port of iOS
// Views/Score/StaffView.swift (brace, clefs, key and time signatures), MeasureView.swift (a measure's two staves,
// beams, triplet "3", cursor) and NoteView.swift (noteheads, stems, flags, rests, accidentals, ledger lines).
// Every number is the iOS one, in dp: `L` is the gap between two staff lines.
package com.lukstrike.luksmusic.feature.library.editor

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.core.model.Accidental
import com.lukstrike.luksmusic.core.model.Measure
import com.lukstrike.luksmusic.core.model.Note
import com.lukstrike.luksmusic.core.model.NoteDuration
import com.lukstrike.luksmusic.core.model.Staff
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/** Sizes shared by the clef block and the measures, so their staves line up. */
object StaffMetrics {
    /** Room above the staves for the measure number (iOS: a 14 pt header and 2 pt spacing). */
    const val HEADER = 16f

    /** Height of a measure's staves area (iOS MeasureView: lineSpacing × 14.5). */
    fun bodyHeight(lineSpacing: Float) = lineSpacing * 14.5f

    fun totalHeight(lineSpacing: Float) = HEADER + bodyHeight(lineSpacing)

    /** Width the brace, clef, key signature and optional time signature need (iOS StaffView.preferredWidth). */
    fun clefBlockWidth(lineSpacing: Float, keySignatureValue: Int, showTimeSignature: Boolean): Float {
        val accidentals = min(7, abs(keySignatureValue)).toFloat()
        val timeSignature = if (showTimeSignature) lineSpacing * 1.4f + 5 else 0f
        return 10 + 4 + lineSpacing * 2.6f + 5 + accidentals * (lineSpacing * 0.9f + 2) + timeSignature + 8
    }

    /** The beat under a horizontal position inside a measure (inverse of the note layout, iOS MeasureView.beat). */
    fun beatAt(x: Float, measureWidth: Float): Double {
        val usable = max(50f, measureWidth - 28f)
        return 1.0 + ((x - 14f) / usable).coerceIn(0f, 1f) * 4.0
    }
}

private val Ink = Color.Black
private val CursorBlue = Color(0.15f, 0.55f, 0.98f)
private val DropletBlue = Color(0.56f, 0.77f, 0.99f)
private val ActiveNote = Color(0.1f, 0.45f, 0.95f)
private val FingerGray = Color(0.24f, 0.24f, 0.26f, 0.6f)

/** Draws in dp: every length is multiplied by the density, and text sizes ignore the font scale so glyphs keep
 *  their place on the staff. */
private class Pen(val scope: DrawScope, val measurer: TextMeasurer, val density: Density) {
    val d = density.density
    fun u(v: Float) = v * d

    /** [text] centered on (x, y) in dp, or with its left edge at x when [leading]. */
    fun text(
        text: String, x: Float, y: Float, size: Float, color: Color,
        weight: FontWeight = FontWeight.Normal, serif: Boolean = false, italic: Boolean = false, leading: Boolean = false,
    ) {
        val style = TextStyle(
            color = color,
            fontSize = (size / density.fontScale).sp,
            fontWeight = weight,
            fontFamily = if (serif) FontFamily.Serif else FontFamily.Default,
            fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
        )
        val layout = measurer.measure(text, style)
        val left = if (leading) u(x) else u(x) - layout.size.width / 2f
        scope.drawText(layout, topLeft = Offset(left, u(y) - layout.size.height / 2f))
    }

    fun rect(x: Float, y: Float, w: Float, h: Float, color: Color) =
        scope.drawRect(color, topLeft = Offset(u(x), u(y)), size = Size(u(w), u(h)))

    /** A rectangle centered on (cx, cy). */
    fun centeredRect(cx: Float, cy: Float, w: Float, h: Float, color: Color) = rect(cx - w / 2, cy - h / 2, w, h, color)

    /** [build] draws a shape in a w×h frame (dp) centered on (cx, cy), like a SwiftUI Shape in a frame. */
    fun shape(cx: Float, cy: Float, w: Float, h: Float, color: Color, build: Path.(w: Float, h: Float) -> Unit) {
        val path = Path().apply { build(u(w), u(h)) }
        path.translate(Offset(u(cx - w / 2), u(cy - h / 2)))
        scope.drawPath(path, color)
    }
}

// region Clef block (StaffView)

/**
 * The left end of the grand staff: brace, clefs, key signature and (on the first system) the time signature, with
 * staff lines filling the rest of its width. Laid out at the same height as [MeasureStaff] so the staves meet.
 */
@Composable
fun StaffClefs(
    lineSpacing: Float,
    keySignatureValue: Int,
    timeSignatureTop: Int,
    timeSignatureBottom: Int,
    modifier: Modifier = Modifier,
    showTimeSignature: Boolean = true,
) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val width = StaffMetrics.clefBlockWidth(lineSpacing, keySignatureValue, showTimeSignature)
    Canvas(modifier.size(width.dp, StaffMetrics.totalHeight(lineSpacing).dp)) {
        val pen = Pen(this, measurer, density)
        val l = lineSpacing
        val center = StaffMetrics.HEADER + StaffMetrics.bodyHeight(l) / 2
        val top = center - 5.75f * l
        val bottom = center + 5.75f * l

        // Grand staff brace: a vertical bar and the classic curly piano brace, 10 wide
        val braceW = 10f
        val h = bottom - top
        val brace = Path().apply {
            moveTo(pen.u(braceW - 2), pen.u(top)); lineTo(pen.u(braceW - 2), pen.u(bottom))
            moveTo(pen.u(braceW - 2), pen.u(top))
            cubicTo(pen.u(5f), pen.u(top + h * 0.15f), pen.u(2f), pen.u(top + h * 0.35f), pen.u(2f), pen.u(top + h * 0.5f))
            cubicTo(pen.u(2f), pen.u(top + h * 0.65f), pen.u(5f), pen.u(top + h * 0.85f), pen.u(braceW - 2), pen.u(bottom))
        }
        drawPath(brace, Ink, style = Stroke(width = pen.u(1.8f)))

        // Staff lines across the whole block
        for (staffMiddle in listOf(center - 3.75f * l, center + 3.75f * l)) {
            for (i in -2..2) pen.rect(braceW, staffMiddle + i * l - 0.55f, width - braceW, 1.1f, Ink.copy(alpha = 0.85f))
        }

        for (staff in listOf(Staff.TREBLE, Staff.BASS)) {
            val middle = if (staff == Staff.TREBLE) center - 3.75f * l else center + 3.75f * l
            var x = braceW + 2 + 2
            // Clef symbol
            val clefWidth = l * 2.6f
            if (staff == Staff.TREBLE) {
                pen.text("𝄞", x + clefWidth / 2, middle - l * 0.22f, l * 3.6f, Ink)
            } else {
                pen.text("𝄢", x + clefWidth / 2, middle - l * 0.1f, l * 2.7f, Ink)
            }
            x += clefWidth + 5

            // Key signature accidentals on their lines and spaces; step 4 is the middle line
            val sharps = keySignatureValue > 0
            val steps = keySignatureSteps(staff, sharps)
            repeat(min(7, abs(keySignatureValue))) { i ->
                val w = l * 0.9f
                pen.text(if (sharps) "♯" else "♭", x + w / 2, middle - (steps[i] - 4) * l * 0.5f, l * 1.45f, Ink, FontWeight.Bold)
                x += w + 2
            }
            if (keySignatureValue != 0) x += 3

            // Time signature
            if (showTimeSignature) {
                val w = l * 1.4f
                pen.text("$timeSignatureTop", x + w / 2, middle - l * 0.95f, l * 1.5f, Ink, FontWeight.Bold, serif = true)
                pen.text("$timeSignatureBottom", x + w / 2, middle + l * 0.95f, l * 1.5f, Ink, FontWeight.Bold, serif = true)
            }
        }
    }
}

/** Staff steps above the bottom line for each accidental, in key-signature order. */
private fun keySignatureSteps(staff: Staff, sharps: Boolean): List<Int> = when {
    staff == Staff.TREBLE && sharps -> listOf(8, 5, 9, 6, 3, 7, 4)   // F C G D A E B
    staff == Staff.TREBLE -> listOf(4, 7, 3, 6, 2, 5, 1)              // B E A D G C F
    sharps -> listOf(6, 3, 7, 4, 1, 5, 2)
    else -> listOf(2, 5, 1, 4, 0, 3, -1)
}

// endregion

// region Measure (MeasureView)

/**
 * One measure of the grand staff on white paper: both staves' notes with beams and triplet marks, the measure
 * number, the pedal line and the barline, and the playback-style cursor at [currentBeat] when [isCurrent].
 */
@Composable
fun MeasureStaff(
    measure: Measure,
    modifier: Modifier = Modifier,
    isCurrent: Boolean = false,
    currentBeat: Double = 1.0,
    lineSpacing: Float = 6.4f,
    measureWidth: Float = 300f,
    showMeasureNumber: Boolean = true,
) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val activeIds = remember(measure, isCurrent, currentBeat) {
        if (!isCurrent) emptySet()
        else measure.soundingNotes(measure.cursorBeat(currentBeat), beatUnit = 4).map { it.id }.toSet()
    }
    Canvas(modifier.size(measureWidth.dp, StaffMetrics.totalHeight(lineSpacing).dp)) {
        drawRect(Color.White)
        val pen = Pen(this, measurer, density)
        MeasurePainter(pen, measure, lineSpacing, measureWidth, activeIds).draw(isCurrent, currentBeat, showMeasureNumber)
    }
}

private class MeasurePainter(
    val pen: Pen,
    val measure: Measure,
    val l: Float,
    val width: Float,
    val activeIds: Set<String>,
) {
    val usable = max(50f, width - 28f)
    val center = StaffMetrics.HEADER + StaffMetrics.bodyHeight(l) / 2
    val bodyTop = StaffMetrics.HEADER

    fun xOf(beat: Double) = 14f + ((beat - 1.0) / 4.0).coerceIn(0.0, 1.0).toFloat() * usable

    fun draw(isCurrent: Boolean, currentBeat: Double, showMeasureNumber: Boolean) {
        if (showMeasureNumber && measure.number > 1) {
            pen.text("${measure.number}", 2f, StaffMetrics.HEADER / 2, 10f, Ink.copy(alpha = 0.75f), FontWeight.SemiBold,
                serif = true, italic = true, leading = true)
        }

        // Both 5-line staves
        for (staffMiddle in listOf(center - 3.75f * l, center + 3.75f * l)) {
            for (i in -2..2) pen.rect(0f, staffMiddle + i * l - 0.55f, width, 1.1f, Ink.copy(alpha = 0.85f))
        }

        staffNotes(measure.trebleNotes, center - 3.75f * l)
        staffNotes(measure.bassNotes, center + 3.75f * l)

        // Piano sustain pedal bracket (where iOS puts it: 7.4 line gaps from the top of the staves area)
        val pedY = bodyTop + l * 7.4f
        val pedal = Path().apply {
            moveTo(pen.u(8f), pen.u(pedY - 4)); lineTo(pen.u(8f), pen.u(pedY))
            lineTo(pen.u(width - 4), pen.u(pedY)); lineTo(pen.u(width - 4), pen.u(pedY - 4))
        }
        pen.scope.drawPath(pedal, Ink.copy(alpha = 0.85f), style = Stroke(width = pen.u(1f)))

        // Right barline from the top of the treble staff to the bottom of the bass staff
        pen.rect(width - 1.5f, center - 5.5f * l, 1.5f, 11f * l, Ink.copy(alpha = 0.85f))

        // MuseScore-style cursor with its teardrop handle
        if (isCurrent) {
            val x = xOf(measure.cursorBeat(currentBeat))
            val top = center - 5.8f * l
            pen.rect(x - 1.1f, top, 2.2f, 11.6f * l, CursorBlue)
            val dropletTop = top + 11.4f * l
            val droplet = teardrop(pen.u(15f), pen.u(21f)).apply { translate(Offset(pen.u(x - 7.5f), pen.u(dropletTop))) }
            pen.scope.drawPath(droplet, DropletBlue)
            pen.scope.drawPath(droplet, CursorBlue, style = Stroke(width = pen.u(1.4f)))
        }
    }

    private fun staffNotes(notes: List<Note>, middle: Float) {
        val groups = beamedGroups(notes)
        val beamed = groups.flatten().map { it.id }.toSet()
        for (note in notes) {
            NotePainter(pen, note, l, if (note.id in activeIds) ActiveNote else Ink, isBeamed = note.id in beamed)
                .draw(xOf(note.beat), middle)
        }
        for (group in groups) beam(group, middle)
    }

    /** Eighths and sixteenths (not dotted) of the same beat, two or more, are beamed together. */
    private fun beamedGroups(notes: List<Note>): List<List<Note>> =
        notes.filter { !it.isRest && (it.duration == NoteDuration.EIGHTH || it.duration == NoteDuration.SIXTEENTH) }
            .groupBy { floor(it.beat).toInt() }
            .toSortedMap().values
            .filter { it.size >= 2 }
            .map { group -> group.sortedBy { it.beat } }

    private fun beam(group: List<Note>, middle: Float) {
        val first = group.first()
        val last = group.last()
        val stemUp = if (first.staff == Staff.TREBLE && first.isTriplet) false else first.stemUp
        val stemX = if (stemUp) l * 0.6f else -l * 0.6f
        val xStart = xOf(first.beat) + stemX
        val xEnd = xOf(last.beat) + stemX
        val beamWidth = max(8f, xEnd - xStart)

        val positions = group.map { it.staffPosition.toFloat() }
        val stemHeight = l * 3.2f
        val beamY: Float
        val labelY: Float
        if (stemUp) {
            beamY = -positions.max() * (l * 0.5f) - stemHeight
            labelY = beamY - 11f
        } else {
            beamY = -positions.min() * (l * 0.5f) + stemHeight
            labelY = beamY + 3f
        }
        pen.rect(xStart, middle + beamY - 1.5f, beamWidth, 3f, Ink)

        if (group.size == 3 || first.isTriplet) {
            val labelX = (xStart + xEnd) * 0.5f - 4f
            pen.text("3", labelX, middle + labelY, 10f, Ink, FontWeight.Bold, serif = true, italic = true, leading = true)
        }
    }
}

/** Authentic MuseScore teardrop handle pointing up to the cursor line, in a w×h frame (px). */
private fun teardrop(w: Float, h: Float) = Path().apply {
    val midX = w / 2
    val radius = w / 2
    moveTo(midX, 0f)
    cubicTo(midX + w * 0.25f, h * 0.35f, w, h * 0.6f, w, h - radius)
    // Around the bottom bulb, through its lowest point
    arcTo(Rect(Offset(midX, h - radius), radius), 0f, 180f, false)
    cubicTo(0f, h * 0.6f, midX - w * 0.25f, h * 0.35f, midX, 0f)
    close()
}

// endregion

// region Note (NoteView)

private class NotePainter(val pen: Pen, val note: Note, val l: Float, val color: Color, val isBeamed: Boolean) {

    /** Draws the note centered on x, its staff's middle line at [middle]. */
    fun draw(x: Float, middle: Float) = if (note.isRest) rest(x, middle) else head(x, middle)

    private fun rest(x: Float, middle: Float) {
        val restColor = color.copy(alpha = color.alpha * 0.85f)
        when (note.duration) {
            // Whole rest hangs below line 4; half rest sits on line 3
            NoteDuration.WHOLE -> pen.centeredRect(x, middle - l * 0.77f, l * 1.4f, l * 0.45f, restColor)
            NoteDuration.HALF, NoteDuration.DOTTED_HALF -> pen.centeredRect(x, middle - l * 0.22f, l * 1.4f, l * 0.45f, restColor)
            NoteDuration.QUARTER, NoteDuration.DOTTED_QUARTER ->
                pen.shape(x, middle - l * 0.1f, l * 0.85f, l * 2.8f, restColor) { w, h -> quarterRest(w, h) }
            NoteDuration.EIGHTH, NoteDuration.DOTTED_EIGHTH ->
                pen.shape(x, middle - l * 0.1f, l * 0.9f, l * 2.2f, restColor) { w, h -> eighthRest(w, h) }
            NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH, NoteDuration.THIRTY_SECOND ->
                pen.shape(x, middle - l * 0.1f, l * 1.0f, l * 2.6f, restColor) { w, h -> sixteenthRest(w, h) }
        }
    }

    private fun head(x: Float, middle: Float) {
        val duration = note.duration
        val isFilled = duration != NoteDuration.WHOLE && duration != NoteDuration.HALF && duration != NoteDuration.DOTTED_HALF
        val hasStem = duration != NoteDuration.WHOLE
        val stemUp = if (note.staff == Staff.TREBLE && note.isTriplet) false else note.stemUp
        val y = middle - note.staffPosition * (l * 0.5f)

        // Ledger lines outside the five lines
        for (i in 1..note.ledgerLinesAbove) pen.centeredRect(x, middle - (4 + i * 2) * (l * 0.5f), l * 2.2f, 1.4f, Ink.copy(alpha = 0.75f))
        for (i in 1..note.ledgerLinesBelow) pen.centeredRect(x, middle + (4 + i * 2) * (l * 0.5f), l * 2.2f, 1.4f, Ink.copy(alpha = 0.75f))

        // Accidental, left of the notehead without moving the beat's anchor
        if (note.pitch.accidental != Accidental.NATURAL) {
            pen.text(note.pitch.accidental.symbol, x - l * 1.15f, y, l * 1.6f, color, FontWeight.Bold)
        }

        // Notehead: a tilted ellipse
        val headW = pen.u(l * 1.35f)
        val headH = pen.u(l * 0.95f)
        val headCenter = Offset(pen.u(x), pen.u(y))
        pen.scope.rotate(-20f, pivot = headCenter) {
            val topLeft = Offset(headCenter.x - headW / 2, headCenter.y - headH / 2)
            if (isFilled) drawOval(color, topLeft, Size(headW, headH))
            drawOval(color, topLeft, Size(headW, headH), style = Stroke(width = pen.u(2.2f)))
        }

        if (hasStem) {
            val stemHeight = l * 3.2f
            val stemX = if (stemUp) l * 0.6f else -l * 0.6f
            val stemCenterY = y + if (stemUp) -stemHeight * 0.5f else stemHeight * 0.5f
            pen.centeredRect(x + stemX, stemCenterY, 1.6f, stemHeight, color)

            // Flag for a lone eighth or sixteenth
            if (!isBeamed) {
                val flagX = x + stemX + l * 0.45f
                when (duration) {
                    NoteDuration.EIGHTH, NoteDuration.DOTTED_EIGHTH -> {
                        val fy = if (stemUp) y - stemHeight + l * 0.9f else y + stemHeight - l * 0.9f
                        pen.shape(flagX, fy, l * 0.9f, l * 1.8f, color) { w, h -> flag(w, h, stemUp, sixteenth = false) }
                    }
                    NoteDuration.SIXTEENTH, NoteDuration.DOTTED_SIXTEENTH -> {
                        val fy = if (stemUp) y - stemHeight + l * 1.2f else y + stemHeight - l * 1.2f
                        pen.shape(flagX, fy, l * 0.9f, l * 2.4f, color) { w, h -> flag(w, h, stemUp, sixteenth = true) }
                    }
                    else -> Unit
                }
            }
        }

        // Lyric syllable below the staff
        note.lyric?.let {
            pen.text(it, x, middle + l * 4.6f, max(10f, l * 1.05f), Ink.copy(alpha = 0.85f), FontWeight.SemiBold, serif = true)
        }

        // Rhythmic dot
        if (duration == NoteDuration.DOTTED_HALF || duration == NoteDuration.DOTTED_QUARTER ||
            duration == NoteDuration.DOTTED_EIGHTH || duration == NoteDuration.DOTTED_SIXTEENTH
        ) {
            pen.scope.drawCircle(color, radius = pen.u(1.75f), center = Offset(pen.u(x + l * 1.15f), pen.u(y)))
        }

        // Fingering
        note.fingerNumber?.let {
            pen.text("$it", x, y + if (stemUp) -l * 3.6f else l * 2.6f, 9f, FingerGray, FontWeight.Bold)
        }
    }
}

// endregion

// region Engraving shapes (iOS NoteFlagShape, QuarterRestShape, EighthRestShape, SixteenthRestShape)

private fun Path.flag(w: Float, h: Float, stemUp: Boolean, sixteenth: Boolean) {
    if (stemUp) {
        moveTo(0f, 0f)
        cubicTo(w * 0.8f, h * 0.1f, w * 1.1f, h * 0.35f, w, h * 0.6f)
        cubicTo(w * 0.6f, h * 0.5f, w * 0.2f, h * 0.45f, 0f, h * 0.4f)
        close()
        if (sixteenth) {
            moveTo(0f, h * 0.35f)
            cubicTo(w * 0.8f, h * 0.45f, w * 1.1f, h * 0.7f, w, h * 0.95f)
            cubicTo(w * 0.6f, h * 0.85f, w * 0.2f, h * 0.8f, 0f, h * 0.75f)
            close()
        }
    } else {
        moveTo(0f, h)
        cubicTo(w * 0.8f, h * 0.9f, w * 1.1f, h * 0.65f, w, h * 0.4f)
        cubicTo(w * 0.6f, h * 0.5f, w * 0.2f, h * 0.55f, 0f, h * 0.6f)
        close()
        if (sixteenth) {
            moveTo(0f, h * 0.65f)
            cubicTo(w * 0.8f, h * 0.55f, w * 1.1f, h * 0.3f, w, h * 0.05f)
            cubicTo(w * 0.6f, h * 0.15f, w * 0.2f, h * 0.2f, 0f, h * 0.25f)
            close()
        }
    }
}

/** Classical quarter rest (lightning zig-zag). */
private fun Path.quarterRest(w: Float, h: Float) {
    moveTo(w * 0.2f, 0f)
    lineTo(w * 0.85f, h * 0.28f)
    lineTo(w * 0.1f, h * 0.55f)
    lineTo(w * 0.9f, h * 0.75f)
    cubicTo(w * 0.6f, h * 0.85f, w * 0.2f, h * 0.92f, w * 0.1f, h)
    lineTo(w * 0.25f, h * 0.78f)
    lineTo(0f, h * 0.55f)
    lineTo(w * 0.6f, h * 0.28f)
    close()
}

private fun Path.eighthRest(w: Float, h: Float) {
    // Round head
    addOval(Rect(Offset(0f, h * 0.1f), Size(w * 0.55f, w * 0.55f)))
    // Hook and slanted stem
    moveTo(w * 0.45f, h * 0.25f)
    cubicTo(w * 0.7f, h * 0.2f, w * 0.85f, h * 0.3f, w * 0.85f, h * 0.4f)
    lineTo(w * 0.35f, h)
    lineTo(w * 0.2f, h * 0.95f)
    lineTo(w * 0.68f, h * 0.45f)
    close()
}

/** Sixteenth rest: two heads on a slanted stem. */
private fun Path.sixteenthRest(w: Float, h: Float) {
    addOval(Rect(Offset(0f, h * 0.05f), Size(w * 0.5f, w * 0.5f)))
    addOval(Rect(Offset(0f, h * 0.4f), Size(w * 0.5f, w * 0.5f)))
    moveTo(w * 0.8f, h * 0.2f)
    lineTo(w * 0.3f, h)
    lineTo(w * 0.15f, h * 0.95f)
    lineTo(w * 0.65f, h * 0.2f)
    close()
}

// endregion
