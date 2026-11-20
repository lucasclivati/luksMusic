// FallingNotesView.kt — Synthesia-style falling notes (adapted from the Android app's feature/practice/
// FallingNotesView.kt): bars fall in the beat colors toward the key strip and light their keys as they cross the hit
// line at the bottom. Only the drawing reads the playhead, so each frame redraws without recomposing.
package com.lukstrike.luksmusic.desktop.study

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.lukstrike.luksmusic.core.practice.FallingNoteTrack
import com.lukstrike.luksmusic.core.practice.KeyboardLayout
import com.lukstrike.luksmusic.core.practice.PianoKeys
import com.lukstrike.luksmusic.desktop.ui.Palette
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

/** The hit line, as a fraction of the height from the top (the key strip sits right under the view). */
private const val HIT_LINE = 0.94f

@Composable
fun FallingNotesView(
    track: FallingNoteTrack,
    playhead: () -> Double,
    keyRange: IntRange,
    beatsPerMeasure: Int,
    modifier: Modifier = Modifier,
    visibleBeats: Double = 8.0,
) {
    val measurer = rememberTextMeasurer(cacheSize = 32)
    Spacer(
        modifier
            .background(Color(0.07f, 0.09f, 0.11f))
            .drawWithCache {
                val layout = KeyboardLayout(keyRange.first, keyRange.last)
                val keyWidth = size.width / max(layout.whiteKeyCount, 1)
                val hitLineY = size.height * HIT_LINE
                val numberStyle = TextStyle(
                    fontSize = 16.dp.toSp(), fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
                    color = Color.White.copy(alpha = 0.5f),
                )
                val numbers = HashMap<Int, TextLayoutResult>()
                val corner = CornerRadius(4.dp.toPx())
                val border = Stroke(1.dp.toPx())
                onDrawBehind {
                    val beat = playhead()
                    val pixelsPerBeat = (hitLineY / visibleBeats).toFloat()
                    // Key lanes
                    for (midi in layout.rangeStart..layout.rangeEnd) {
                        if (!PianoKeys.isBlack(midi)) continue
                        val x = (layout.centerX(midi) * keyWidth).toFloat()
                        drawLine(Color.Black.copy(alpha = 0.22f), Offset(x, 0f), Offset(x, size.height), keyWidth * 0.6f)
                    }
                    for (index in 0..layout.whiteKeyCount) {
                        val x = index * keyWidth
                        val isC = layout.whiteKeys.getOrNull(index)?.let { it % 12 == 0 } == true
                        drawLine(Color.White.copy(alpha = if (isC) 0.10f else 0.035f), Offset(x, 0f), Offset(x, size.height), 1f)
                    }
                    // Measure and beat lines
                    for (b in floor(beat).toInt()..ceil(beat + visibleBeats).toInt()) {
                        val y = hitLineY - ((b - beat) * pixelsPerBeat).toFloat()
                        if (y < 0 || y > size.height) continue
                        if (Math.floorMod(b - 1, max(1, beatsPerMeasure)) == 0) {
                            drawLine(Color.White.copy(alpha = 0.3f), Offset(0f, y), Offset(size.width, y), 1.5.dp.toPx())
                            if (b >= 1) {
                                val text = numbers.getOrPut((b - 1) / max(1, beatsPerMeasure) + 1) {
                                    measurer.measure(((b - 1) / max(1, beatsPerMeasure) + 1).toString(), numberStyle)
                                }
                                drawText(text, topLeft = Offset(8.dp.toPx(), y - text.size.height - 2.dp.toPx()))
                            }
                        } else {
                            drawLine(Color.White.copy(alpha = 0.07f), Offset(0f, y), Offset(size.width, y), 1f)
                        }
                    }
                    drawRect(Color.Black.copy(alpha = 0.35f), Offset(0f, hitLineY), Size(size.width, size.height - hitLineY))
                    // Bars
                    track.forEachIn(beat - FallingNoteTrack.VISIBLE_BELOW, beat + visibleBeats) { note ->
                        val x = (layout.centerX(note.midiNote) * keyWidth).toFloat()
                        val width = if (PianoKeys.isBlack(note.midiNote)) keyWidth * 0.58f else keyWidth - 3.dp.toPx()
                        val relative = note.startBeat - beat
                        val top = hitLineY - ((relative + note.durationBeats) * pixelsPerBeat).toFloat()
                        val bottom = hitLineY - (relative * pixelsPerBeat).toFloat()
                        val height = max(bottom - top, 6.dp.toPx())
                        val topLeft = Offset(x - width / 2, top)
                        val color = Palette.colorForBeat(note.startBeat, beatsPerMeasure)
                        drawRoundRect(
                            Brush.linearGradient(listOf(color.copy(alpha = 0.95f), color, color.copy(alpha = 0.8f)), topLeft, Offset(topLeft.x + width, topLeft.y + height)),
                            topLeft, Size(width, height), corner,
                        )
                        drawRoundRect(Color.White.copy(alpha = 0.4f), topLeft, Size(width, height), corner, style = border)
                        if (FallingNoteTrack.isHitting(note, beat)) {
                            drawOval(color.copy(alpha = 0.45f), Offset(x - keyWidth, hitLineY - keyWidth * 0.6f), Size(keyWidth * 2, keyWidth * 1.2f))
                            drawOval(Color.White.copy(alpha = 0.9f), Offset(x - keyWidth * 0.45f, hitLineY - keyWidth * 0.3f), Size(keyWidth * 0.9f, keyWidth * 0.6f))
                        }
                    }
                    drawLine(Color.White.copy(alpha = 0.4f), Offset(0f, hitLineY), Offset(size.width, hitLineY), 2.dp.toPx())
                }
            },
    )
}
