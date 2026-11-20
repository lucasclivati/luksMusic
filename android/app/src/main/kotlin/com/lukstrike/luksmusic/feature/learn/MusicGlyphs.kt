// MusicGlyphs.kt — the music symbols the reading staff draws, as vector paths so they look the same on every
// phone: accidentals, rests, flags and the C clef (ported from iOS ReadingStaffView and NoteView's rest shapes).
// The treble and bass clefs come from the system's music font when it has them (Noto Music), drawn by their ink
// like an engraving font; phones without one get the drawn clefs here.
package com.lukstrike.luksmusic.feature.learn

import android.graphics.Paint
import android.graphics.Rect as AndroidRect
import android.graphics.Typeface
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import com.lukstrike.luksmusic.core.model.Accidental

internal object MusicGlyphs {

    private const val TREBLE_CLEF = "𝄞" // 𝄞
    private const val BASS_CLEF = "𝄢"   // 𝄢

    private val glyphPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.DEFAULT }
    private val hasTrebleGlyph by lazy { glyphPaint.hasGlyph(TREBLE_CLEF) }
    private val hasBassGlyph by lazy { glyphPaint.hasGlyph(BASS_CLEF) }

    // ---- Clefs

    /**
     * The treble clef, its ink [inkHeight] tall, its left edge at [left] and lowest point at [bottom]; [gLine] is
     * the G line its curl winds around (for the drawn fallback).
     */
    fun DrawScope.trebleClef(left: Float, bottom: Float, inkHeight: Float, gLine: Float, space: Float, color: Color) {
        if (hasTrebleGlyph) return drawGlyph(TREBLE_CLEF, left, bottom, inkHeight, color)
        // Spaces right of `left` and above the G line
        fun p(x: Float, y: Float) = Offset(left + x * space, gLine - y * space)
        val path = Path().apply {
            p(1.2f, 0f).let { moveTo(it.x, it.y) }
            cubic(p(1.2f, -0.45f), p(0.7f, -0.5f), p(0.55f, -0.15f))
            cubic(p(0.35f, 0.35f), p(0.6f, 0.85f), p(1.05f, 0.85f))
            cubic(p(1.6f, 0.85f), p(1.9f, 0.45f), p(1.85f, 0f))
            cubic(p(1.8f, -0.6f), p(1.45f, -1.05f), p(1.0f, -1.05f))
            cubic(p(0.4f, -1.05f), p(0.05f, -0.5f), p(0.15f, 0.3f))
            cubic(p(0.25f, 1.4f), p(1.5f, 2.2f), p(1.45f, 3.3f))
            cubic(p(1.42f, 4.0f), p(1.3f, 4.55f), p(1.15f, 4.55f))
            cubic(p(0.9f, 4.55f), p(0.75f, 3.9f), p(0.85f, 3.2f))
            cubic(p(0.95f, 2.0f), p(1.35f, -0.6f), p(1.2f, -2.0f))
            cubic(p(1.15f, -2.45f), p(0.85f, -2.55f), p(0.6f, -2.35f))
        }
        drawPath(path, color, style = Stroke(width = space * 0.2f, cap = StrokeCap.Round))
        val dot = p(0.72f, -2.1f)
        drawCircle(color, radius = space * 0.24f, center = dot)
    }

    /** The bass clef, its ink [inkHeight] tall from [left] and [bottom]; [fLine] is the line between its dots. */
    fun DrawScope.bassClef(left: Float, bottom: Float, inkHeight: Float, fLine: Float, space: Float, color: Color) {
        if (hasBassGlyph) return drawGlyph(BASS_CLEF, left, bottom, inkHeight, color)
        fun p(x: Float, y: Float) = Offset(left + x * space, fLine - y * space)
        drawCircle(color, radius = space * 0.3f, center = p(0.35f, 0f))
        val path = Path().apply {
            p(0.3f, 0.05f).let { moveTo(it.x, it.y) }
            cubic(p(0.4f, 0.95f), p(1.55f, 1.05f), p(1.65f, 0.25f))
            cubic(p(1.75f, -0.75f), p(1.05f, -1.75f), p(0.2f, -2.35f))
        }
        drawPath(path, color, style = Stroke(width = space * 0.24f, cap = StrokeCap.Round))
        drawCircle(color, radius = space * 0.17f, center = p(2.15f, 0.5f))
        drawCircle(color, radius = space * 0.17f, center = p(2.15f, -0.5f))
    }

    /**
     * The C clef, drawn rather than typed because the system fonts may not have it: a thick and a thin bar the
     * height of the staff, and two curls meeting in a point on the middle line ([middle]), which is middle C.
     */
    fun cClefPath(left: Float, middle: Float, space: Float): Path {
        val path = Path()
        path.addRect(Rect(left, middle - space * 2, left + space * 0.48f, middle + space * 2))
        path.addRect(Rect(left + space * 0.64f, middle - space * 2, left + space * 0.76f, middle + space * 2))
        // The upper curl from its point on the middle line, in spaces right of `left` and above the middle line:
        // end, first control, second control. The lower curl is its mirror image.
        val curl = listOf(
            floatArrayOf(2.55f, 1.05f, 1.40f, 0.36f, 2.55f, 0.36f),
            floatArrayOf(1.72f, 2.04f, 2.55f, 1.70f, 2.20f, 2.04f),
            floatArrayOf(0.98f, 1.58f, 1.30f, 2.04f, 0.98f, 1.86f),
            floatArrayOf(1.38f, 1.16f, 0.98f, 1.32f, 1.16f, 1.16f),
            floatArrayOf(1.78f, 1.54f, 1.60f, 1.16f, 1.78f, 1.32f),
            floatArrayOf(1.84f, 1.68f, 1.78f, 1.60f, 1.80f, 1.66f),
            floatArrayOf(2.02f, 1.08f, 1.98f, 1.62f, 2.02f, 1.36f),
            floatArrayOf(1.64f, 0.58f, 2.02f, 0.80f, 1.88f, 0.58f),
            floatArrayOf(1.04f, 0.00f, 1.34f, 0.58f, 1.12f, 0.26f),
        )
        for (direction in listOf(1f, -1f)) {
            fun x(v: Float) = left + v * space
            fun y(v: Float) = middle - direction * v * space
            path.moveTo(x(0.80f), y(0f))
            for (s in curl) path.cubicTo(x(s[2]), y(s[3]), x(s[4]), y(s[5]), x(s[0]), y(s[1]))
            path.close()
        }
        return path
    }

    /**
     * Draws a font symbol with its ink [inkHeight] tall, the ink's left edge at [left] and its lowest point at
     * [bottom]. A text's box follows the font's line height, not the glyph, so symbols placed by their box land
     * off their staff lines.
     */
    private fun DrawScope.drawGlyph(symbol: String, left: Float, bottom: Float, inkHeight: Float, color: Color) {
        val bounds = AndroidRect()
        val paint = Paint(glyphPaint).apply { this.color = color.toArgb(); textSize = 100f }
        paint.getTextBounds(symbol, 0, symbol.length, bounds)
        if (bounds.height() <= 0) return
        paint.textSize = 100f * inkHeight / bounds.height()
        paint.getTextBounds(symbol, 0, symbol.length, bounds)
        drawIntoCanvas { it.nativeCanvas.drawText(symbol, left - bounds.left, bottom - bounds.bottom, paint) }
    }

    /** Draws [text] (digits) with its ink centered on ([x], [y]). */
    fun DrawScope.drawCenteredInk(text: String, x: Float, y: Float, size: Float, color: Color, serif: Boolean = true) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.create(if (serif) Typeface.SERIF else Typeface.DEFAULT, Typeface.BOLD)
            textSize = size
            this.color = color.toArgb()
        }
        val bounds = AndroidRect()
        paint.getTextBounds(text, 0, text.length, bounds)
        drawIntoCanvas { it.nativeCanvas.drawText(text, x - bounds.exactCenterX(), y - bounds.exactCenterY(), paint) }
    }

    // ---- Accidentals

    /** An accidental centered on ([x], [y]), the line or space of its note. */
    fun DrawScope.accidental(accidental: Accidental, x: Float, y: Float, space: Float, color: Color) {
        when (accidental) {
            Accidental.SHARP -> sharp(x, y, space, color)
            Accidental.FLAT -> flat(x, y, space, color)
            Accidental.NATURAL -> natural(x, y, space, color)
            Accidental.DOUBLE_SHARP -> doubleSharp(x, y, space, color)
            Accidental.DOUBLE_FLAT -> {
                flat(x - space * 0.3f, y, space, color)
                flat(x + space * 0.3f, y, space, color)
            }
        }
    }

    /** A thick bar rising to the right, as the bars of ♯ and ♮ are engraved. */
    private fun DrawScope.slantedBar(x0: Float, x1: Float, y: Float, rise: Float, thickness: Float, color: Color) {
        val path = Path().apply {
            moveTo(x0, y + rise / 2 - thickness / 2)
            lineTo(x1, y - rise / 2 - thickness / 2)
            lineTo(x1, y - rise / 2 + thickness / 2)
            lineTo(x0, y + rise / 2 + thickness / 2)
            close()
        }
        drawPath(path, color)
    }

    private fun DrawScope.sharp(x: Float, y: Float, space: Float, color: Color) {
        val thin = space * 0.11f
        drawLine(color, Offset(x - space * 0.22f, y - space * 1.25f), Offset(x - space * 0.22f, y + space * 1.4f), thin)
        drawLine(color, Offset(x + space * 0.22f, y - space * 1.4f), Offset(x + space * 0.22f, y + space * 1.25f), thin)
        slantedBar(x - space * 0.52f, x + space * 0.52f, y - space * 0.42f, space * 0.3f, space * 0.26f, color)
        slantedBar(x - space * 0.52f, x + space * 0.52f, y + space * 0.42f, space * 0.3f, space * 0.26f, color)
    }

    private fun DrawScope.natural(x: Float, y: Float, space: Float, color: Color) {
        val thin = space * 0.11f
        drawLine(color, Offset(x - space * 0.27f, y - space * 1.3f), Offset(x - space * 0.27f, y + space * 0.62f), thin)
        drawLine(color, Offset(x + space * 0.27f, y - space * 0.62f), Offset(x + space * 0.27f, y + space * 1.3f), thin)
        slantedBar(x - space * 0.27f, x + space * 0.27f, y - space * 0.4f, space * 0.22f, space * 0.24f, color)
        slantedBar(x - space * 0.27f, x + space * 0.27f, y + space * 0.4f, space * 0.22f, space * 0.24f, color)
    }

    /** The flat's bowl sits on its note's line or space; the stem rises above it. */
    private fun DrawScope.flat(x: Float, y: Float, space: Float, color: Color) {
        val stem = x - space * 0.3f
        drawLine(color, Offset(stem, y - space * 1.75f), Offset(stem, y + space * 0.5f), space * 0.11f)
        val bowl = Path().apply {
            moveTo(stem, y + space * 0.5f)
            cubicTo(stem + space * 1.0f, y - space * 0.05f, stem + space * 0.8f, y - space * 0.75f, stem, y - space * 0.25f)
            cubicTo(stem + space * 0.5f, y - space * 0.48f, stem + space * 0.58f, y + space * 0.02f, stem, y + space * 0.36f)
            close()
        }
        drawPath(bowl, color)
    }

    private fun DrawScope.doubleSharp(x: Float, y: Float, space: Float, color: Color) {
        val arm = space * 0.42f
        val width = space * 0.16f
        drawLine(color, Offset(x - arm, y - arm), Offset(x + arm, y + arm), width)
        drawLine(color, Offset(x - arm, y + arm), Offset(x + arm, y - arm), width)
        val corner = space * 0.17f
        for (dx in listOf(-arm, arm)) for (dy in listOf(-arm, arm)) {
            drawRect(color, Offset(x + dx - corner, y + dy - corner), androidx.compose.ui.geometry.Size(corner * 2, corner * 2))
        }
    }

    // ---- Rests and Flags

    /** Classical quarter rest (lightning zig-zag), filling [rect]. */
    fun quarterRest(rect: Rect): Path = Path().apply {
        val w = rect.width
        val h = rect.height
        fun p(x: Float, y: Float) = Offset(rect.left + x * w, rect.top + y * h)
        p(0.2f, 0f).let { moveTo(it.x, it.y) }
        line(p(0.85f, 0.28f)); line(p(0.1f, 0.55f)); line(p(0.9f, 0.75f))
        cubic(p(0.6f, 0.85f), p(0.2f, 0.92f), p(0.1f, 1f))
        line(p(0.25f, 0.78f)); line(p(0f, 0.55f)); line(p(0.6f, 0.28f))
        close()
    }

    /** Classical eighth rest, filling [rect]. */
    fun eighthRest(rect: Rect): Path = Path().apply {
        val w = rect.width
        val h = rect.height
        fun p(x: Float, y: Float) = Offset(rect.left + x * w, rect.top + y * h)
        addOval(Rect(p(0f, 0.1f), androidx.compose.ui.geometry.Size(w * 0.55f, w * 0.55f)))
        p(0.45f, 0.25f).let { moveTo(it.x, it.y) }
        cubic(p(0.7f, 0.2f), p(0.85f, 0.3f), p(0.85f, 0.4f))
        line(p(0.35f, 1f)); line(p(0.2f, 0.95f)); line(p(0.68f, 0.45f))
        close()
    }

    /** Classical sixteenth rest (two hooks), filling [rect]. */
    fun sixteenthRest(rect: Rect): Path = Path().apply {
        val w = rect.width
        val h = rect.height
        fun p(x: Float, y: Float) = Offset(rect.left + x * w, rect.top + y * h)
        addOval(Rect(p(0f, 0.05f), androidx.compose.ui.geometry.Size(w * 0.5f, w * 0.5f)))
        addOval(Rect(p(0f, 0.4f), androidx.compose.ui.geometry.Size(w * 0.5f, w * 0.5f)))
        p(0.8f, 0.2f).let { moveTo(it.x, it.y) }
        line(p(0.3f, 1f)); line(p(0.15f, 0.95f)); line(p(0.65f, 0.2f))
        close()
    }

    /**
     * An engraved flag hanging from the stem's tip toward the notehead: thick at the stem, tapering to a point.
     * [index] 1 is the second flag of a sixteenth, nearer the notehead.
     */
    fun flag(tip: Offset, space: Float, stemUp: Boolean, index: Int): Path {
        // Drawn for a stem going up (the flag goes down from the tip); mirrored for a stem going down
        val direction = if (stemUp) 1f else -1f
        val start = tip.y + direction * index * space * 0.8f
        fun p(dx: Float, dy: Float) = Offset(tip.x + dx * space, start + direction * dy * space)
        return Path().apply {
            p(0f, 0f).let { moveTo(it.x, it.y) }
            cubic(p(0.15f, 0.95f), p(1.3f, 1.3f), p(0.95f, 2.5f))
            cubic(p(0.95f, 1.6f), p(0.4f, 1.15f), p(0f, 0.8f))
            close()
        }
    }

    private fun Path.cubic(c1: Offset, c2: Offset, end: Offset) = cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y)
    private fun Path.line(to: Offset) = lineTo(to.x, to.y)
}
