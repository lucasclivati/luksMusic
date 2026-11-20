// MusicGlyphs.kt — the music symbols the staves draw, as vector paths so they look the same on every system
// (adapted from the Android app's feature/learn/MusicGlyphs.kt). The treble and bass clefs come from a system font
// with the musical symbols (found through Skia's font manager) when there is one, drawn by their ink like an
// engraving font; otherwise the drawn clefs here.
package com.lukstrike.luksmusic.desktop.ui

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import com.lukstrike.luksmusic.core.model.Accidental
import org.jetbrains.skia.Font
import org.jetbrains.skia.FontMgr
import org.jetbrains.skia.FontStyle
import org.jetbrains.skia.Paint
import org.jetbrains.skia.Typeface

internal object MusicGlyphs {

    private const val TREBLE_CLEF = "𝄞" // 𝄞
    private const val BASS_CLEF = "𝄢"   // 𝄢

    /** A font that has the clefs, or null (then they are drawn). */
    private val clefTypeface: Typeface? by lazy {
        runCatching {
            FontMgr.default.matchFamilyStyleCharacter(null, FontStyle.NORMAL, null, 0x1D11E)
                ?.takeIf { face -> face.getUTF32Glyph(0x1D11E) != 0.toShort() && face.getUTF32Glyph(0x1D122) != 0.toShort() }
        }.getOrNull()
    }

    private val digitTypeface: Typeface? by lazy {
        runCatching {
            FontMgr.default.matchFamilyStyle("serif", FontStyle.BOLD) ?: FontMgr.default.legacyMakeTypeface("", FontStyle.BOLD)
        }.getOrNull()
    }

    // ---- Clefs

    /** The treble clef, its ink [inkHeight] tall from [left] and its lowest point at [bottom]; [gLine] for the drawn one. */
    fun DrawScope.trebleClef(left: Float, bottom: Float, inkHeight: Float, gLine: Float, space: Float, color: Color) {
        clefTypeface?.let { face -> if (drawGlyph(face, TREBLE_CLEF, left, bottom, inkHeight, color)) return }
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
        drawCircle(color, radius = space * 0.24f, center = p(0.72f, -2.1f))
    }

    /** The bass clef, its ink [inkHeight] tall from [left] and [bottom]; [fLine] is the line between its dots. */
    fun DrawScope.bassClef(left: Float, bottom: Float, inkHeight: Float, fLine: Float, space: Float, color: Color) {
        clefTypeface?.let { face -> if (drawGlyph(face, BASS_CLEF, left, bottom, inkHeight, color)) return }
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

    /** The C clef: two bars the height of the staff and two curls meeting on the middle line ([middle]). */
    fun cClefPath(left: Float, middle: Float, space: Float): Path {
        val path = Path()
        path.addRect(Rect(left, middle - space * 2, left + space * 0.48f, middle + space * 2))
        path.addRect(Rect(left + space * 0.64f, middle - space * 2, left + space * 0.76f, middle + space * 2))
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

    /** Draws a font symbol with its ink [inkHeight] tall, ink's left edge at [left] and lowest point at [bottom]. */
    private fun DrawScope.drawGlyph(face: Typeface, symbol: String, left: Float, bottom: Float, inkHeight: Float, color: Color): Boolean {
        val probe = Font(face, 100f)
        val bounds = probe.measureText(symbol)
        if (bounds.height <= 0f) return false
        val font = Font(face, 100f * inkHeight / bounds.height)
        val ink = font.measureText(symbol)
        val paint = Paint().apply { this.color = color.toArgb(); isAntiAlias = true }
        drawIntoCanvas { it.nativeCanvas.drawString(symbol, left - ink.left, bottom - ink.bottom, font, paint) }
        return true
    }

    /** Draws [text] (digits) with its ink centered on ([x], [y]). */
    fun DrawScope.drawCenteredInk(text: String, x: Float, y: Float, size: Float, color: Color) {
        val font = Font(digitTypeface, size)
        val ink = font.measureText(text)
        val paint = Paint().apply { this.color = color.toArgb(); isAntiAlias = true }
        drawIntoCanvas {
            it.nativeCanvas.drawString(text, x - (ink.left + ink.right) / 2, y - (ink.top + ink.bottom) / 2, font, paint)
        }
    }

    // ---- Accidentals

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
            drawRect(color, Offset(x + dx - corner, y + dy - corner), Size(corner * 2, corner * 2))
        }
    }

    // ---- Rests and Flags

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

    fun eighthRest(rect: Rect): Path = Path().apply {
        val w = rect.width
        val h = rect.height
        fun p(x: Float, y: Float) = Offset(rect.left + x * w, rect.top + y * h)
        addOval(Rect(p(0f, 0.1f), Size(w * 0.55f, w * 0.55f)))
        p(0.45f, 0.25f).let { moveTo(it.x, it.y) }
        cubic(p(0.7f, 0.2f), p(0.85f, 0.3f), p(0.85f, 0.4f))
        line(p(0.35f, 1f)); line(p(0.2f, 0.95f)); line(p(0.68f, 0.45f))
        close()
    }

    fun sixteenthRest(rect: Rect): Path = Path().apply {
        val w = rect.width
        val h = rect.height
        fun p(x: Float, y: Float) = Offset(rect.left + x * w, rect.top + y * h)
        addOval(Rect(p(0f, 0.05f), Size(w * 0.5f, w * 0.5f)))
        addOval(Rect(p(0f, 0.4f), Size(w * 0.5f, w * 0.5f)))
        p(0.8f, 0.2f).let { moveTo(it.x, it.y) }
        line(p(0.3f, 1f)); line(p(0.15f, 0.95f)); line(p(0.65f, 0.2f))
        close()
    }

    /** An engraved flag from the stem's tip toward the notehead; [index] 1 is a sixteenth's second flag. */
    fun flag(tip: Offset, space: Float, stemUp: Boolean, index: Int): Path {
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
