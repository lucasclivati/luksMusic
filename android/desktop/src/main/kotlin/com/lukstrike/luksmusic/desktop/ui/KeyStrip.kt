// KeyStrip.kt — a slim piano under the music: no playing on it (the real keyboard is for that), it only shows what to
// press and what is pressed. Keys line up with the falling notes above through core's KeyboardLayout.
package com.lukstrike.luksmusic.desktop.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.core.practice.KeyboardLayout

/**
 * [targets] lit blue (or in [targetColors]), [held] the keys down on the MIDI keyboard, [correct] and [incorrect] a
 * moment after each key is judged.
 */
@Composable
fun KeyStrip(
    range: IntRange,
    modifier: Modifier = Modifier,
    targets: Set<Int> = emptySet(),
    targetColors: Map<Int, Color> = emptyMap(),
    held: Set<Int> = emptySet(),
    correct: Set<Int> = emptySet(),
    incorrect: Set<Int> = emptySet(),
    usesLetters: Boolean = true,
) {
    val measurer = rememberTextMeasurer()
    Canvas(modifier) {
        val layout = KeyboardLayout(range.first, range.last)
        if (layout.whiteKeyCount == 0) return@Canvas
        val keyWidth = size.width / layout.whiteKeyCount
        val gap = maxOf(1f, keyWidth * 0.06f)
        val corner = CornerRadius(minOf(6.dp.toPx(), keyWidth * 0.2f))
        fun colorOf(midi: Int, base: Color): Color = when {
            midi in incorrect -> Palette.red
            midi in correct -> Palette.green
            midi in targets -> targetColors[midi] ?: Palette.blue
            midi in held -> Palette.cyan
            else -> base
        }
        val labelStyle = TextStyle(color = Color(0xFF475569), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        layout.whiteKeys.forEachIndexed { index, midi ->
            val x = index * keyWidth
            drawRoundRect(colorOf(midi, Palette.paper), Offset(x + gap / 2, 0f), Size(keyWidth - gap, size.height), corner)
            if (midi in held && (midi in targets || midi in correct || midi in incorrect)) {
                drawCircle(Palette.background, keyWidth * 0.16f, Offset(x + keyWidth / 2, size.height - keyWidth * 0.35f))
            }
            if (midi % 12 == 0 && keyWidth > 14.dp.toPx()) {
                val text = measurer.measure(NoteNaming.nameWithOctave(midi, usesLetters), labelStyle)
                if (text.size.width < keyWidth) {
                    drawText(text, topLeft = Offset(x + (keyWidth - text.size.width) / 2, size.height - text.size.height - 3.dp.toPx()))
                }
            }
        }
        val blackWidth = keyWidth * KeyboardLayout.BLACK_WIDTH.toFloat()
        val blackHeight = size.height * KeyboardLayout.BLACK_HEIGHT.toFloat()
        for (midi in layout.blackKeys) {
            val x = layout.blackKeyLeft(midi, KeyboardLayout.BLACK_WIDTH).toFloat() * keyWidth
            drawRoundRect(colorOf(midi, Color(0xFF111827)), Offset(x, 0f), Size(blackWidth, blackHeight), corner)
            if (midi in held && (midi in targets || midi in correct || midi in incorrect)) {
                drawCircle(Palette.text, blackWidth * 0.2f, Offset(x + blackWidth / 2, blackHeight - blackWidth * 0.45f))
            }
        }
    }
}
