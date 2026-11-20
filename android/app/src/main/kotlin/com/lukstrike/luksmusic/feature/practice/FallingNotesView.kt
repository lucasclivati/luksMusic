// FallingNotesView.kt — Synthesia-style falling notes above the keyboard (port of Views/Practice/FallingNotesView.swift).
// Bars fall in the beat colors of the score (LuksColors.colorForBeat) and light their keys as they cross the hit line.
//
// The clock advances once per display frame (withFrameNanos, so 60 or 120 Hz as the screen runs) by the real time
// since the last frame at the practice tempo. Only the drawing reads the clock, so each frame redraws the canvas
// without recomposing; the bars' timing is core/practice/FallingNotes.kt.
package com.lukstrike.luksmusic.feature.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.lukstrike.luksmusic.core.practice.FallingHits
import com.lukstrike.luksmusic.core.practice.FallingNote
import com.lukstrike.luksmusic.core.practice.FallingNoteTrack
import com.lukstrike.luksmusic.core.practice.KeyboardLayout
import com.lukstrike.luksmusic.core.practice.PianoKeys
import com.lukstrike.luksmusic.ui.theme.LuksColors
import kotlinx.coroutines.flow.collectLatest
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

/**
 * The falling notes' state (iOS FallingNotesViewModel). Owned by the practice ViewModel so it outlives redraws; the
 * view only advances the clock and draws.
 */
class FallingNotesState {
    var track: FallingNoteTrack by mutableStateOf(FallingNoteTrack(emptyList()))
        private set

    /** Current playback position in beats. Read only while drawing. */
    var currentBeat by mutableDoubleStateOf(0.0)
        private set
    /** Tempo in beats per minute. */
    var tempo: Double = 72.0
    /** Beat the notes stop at (guided practice waits there for the expected notes); null keeps them falling. */
    var holdBeat: Double? = null
    /** Number of beats visible above the hit line. */
    var visibleBeats by mutableDoubleStateOf(8.0)
    /** Time signature numerator (beats per measure). */
    var beatsPerMeasure by mutableIntStateOf(4)
    /** Whether playback is active (the frame clock runs only then). */
    var isPlaying by mutableStateOf(false)
    /** The keyboard below, so each bar falls on its key. */
    var keyboardRangeStart by mutableIntStateOf(48)
    var keyboardRangeEnd by mutableIntStateOf(84)

    /** The bars crossing the hit line, told whenever they change (to light the keyboard). */
    var onHitsChanged: ((FallingHits) -> Unit)? = null
    var hits = FallingHits()
        private set

    fun setNotes(notes: List<FallingNote>) {
        track = FallingNoteTrack(notes)
        updateHits()
    }

    /** Advances the current beat based on elapsed time. */
    fun advance(deltaSeconds: Double) {
        if (!isPlaying) return
        currentBeat = FallingNoteTrack.advance(currentBeat, deltaSeconds, tempo, holdBeat)
        updateHits()
    }

    /** Jumps to [beat] (practice started, looped or moved to a tapped note). */
    fun seek(beat: Double) {
        currentBeat = beat
        updateHits()
    }

    private fun updateHits() {
        val now = track.hits(currentBeat)
        if (now != hits) {
            hits = now
            onHitsChanged?.invoke(now)
        }
    }

    companion object {
        /** Palette matching the Synthesia visual reference. */
        val neonGreen = Color(0.22f, 0.95f, 0.38f)
        val electricCyan = Color(0.0f, 0.88f, 1.0f)
        val backgroundDark = Color(0.07f, 0.09f, 0.11f)

        /** The hit line, as a fraction of the height from the top. */
        const val HIT_LINE = 0.88f
    }
}

@Composable
fun FallingNotesView(state: FallingNotesState, modifier: Modifier = Modifier) {
    val textMeasurer = rememberTextMeasurer(cacheSize = 32)

    // The frame clock, only while playing: each frame advances by the real time since the last one
    LaunchedEffect(state) {
        snapshotFlow { state.isPlaying }.collectLatest { playing ->
            if (!playing) return@collectLatest
            var last = -1L
            while (true) {
                withFrameNanos { now ->
                    if (last >= 0) state.advance((now - last) / 1_000_000_000.0)
                    last = now
                }
            }
        }
    }

    Spacer(
        modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(6.dp))
            .background(FallingNotesState.backgroundDark)
            .drawWithCache {
                val layout = KeyboardLayout(state.keyboardRangeStart, state.keyboardRangeEnd)
                val whiteKeyWidth = size.width / max(layout.whiteKeyCount, 1)
                val hitLineY = size.height * FallingNotesState.HIT_LINE
                val numberStyle = TextStyle(
                    fontSize = 13.dp.toSp(), fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
                    color = Color.White.copy(alpha = 0.45f),
                )
                val measureNumbers = HashMap<Int, TextLayoutResult>()
                onDrawBehind {
                    val beat = state.currentBeat
                    val visibleBeats = state.visibleBeats
                    val beatsPerMeasure = max(1, state.beatsPerMeasure)
                    val pixelsPerBeat = (hitLineY / visibleBeats).toFloat()
                    drawKeyTracks(layout, whiteKeyWidth)
                    drawBeatGrid(beat, visibleBeats, beatsPerMeasure, hitLineY, pixelsPerBeat) { number ->
                        measureNumbers.getOrPut(number) { textMeasurer.measure(number.toString(), numberStyle) }
                    }
                    // Translucent dark bar across the bottom hit zone
                    drawRect(Color.Black.copy(alpha = 0.35f), Offset(0f, hitLineY), Size(size.width, size.height - hitLineY))
                    val visible = state.track.visible(beat, visibleBeats)
                    drawNotes(visible, layout, whiteKeyWidth, beat, beatsPerMeasure, hitLineY, pixelsPerBeat)
                    drawImpactSparks(visible, layout, whiteKeyWidth, beat, beatsPerMeasure, hitLineY)
                    // The crisp impact line
                    drawLine(Color.White.copy(alpha = 0.35f), Offset(0f, hitLineY), Offset(size.width, hitLineY), 1.5.dp.toPx())
                }
            }
    )
}

// MARK: - Drawing

/** Faint vertical tracks for the key lanes. */
private fun DrawScope.drawKeyTracks(layout: KeyboardLayout, whiteKeyWidth: Float) {
    for (midi in layout.rangeStart..layout.rangeEnd) {
        val x = (layout.centerX(midi) * whiteKeyWidth).toFloat()
        val isBlack = PianoKeys.isBlack(midi)
        drawLine(
            if (isBlack) Color.Black.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.02f),
            Offset(x, 0f), Offset(x, size.height),
            strokeWidth = if (isBlack) whiteKeyWidth * 0.6f else whiteKeyWidth,
        )
    }
}

/** Horizontal measure lines with their numbers, and faint beat lines. */
private inline fun DrawScope.drawBeatGrid(
    currentBeat: Double, visibleBeats: Double, beatsPerMeasure: Int, hitLineY: Float, pixelsPerBeat: Float,
    measureNumber: (Int) -> TextLayoutResult,
) {
    val start = floor(currentBeat).toInt()
    val end = ceil(currentBeat + visibleBeats).toInt()
    for (beat in start..end) {
        val y = hitLineY - ((beat - currentBeat) * pixelsPerBeat).toFloat()
        if (y < 0 || y > size.height) continue
        // Beats count from 1 at the first measure, so measures start at 1, 1 + beatsPerMeasure, ...
        val isMeasureLine = Math.floorMod(beat - 1, beatsPerMeasure) == 0
        if (isMeasureLine) {
            drawLine(Color.White.copy(alpha = 0.28f), Offset(0f, y), Offset(size.width, y), 1.2.dp.toPx())
            if (beat >= 1) {
                val text = measureNumber((beat - 1) / beatsPerMeasure + 1)
                // Centered on (18, y − 10), on the left margin
                drawText(text, topLeft = Offset(18.dp.toPx() - text.size.width / 2f, y - 10.dp.toPx() - text.size.height / 2f))
            }
        } else {
            drawLine(Color.White.copy(alpha = 0.06f), Offset(0f, y), Offset(size.width, y), 0.5.dp.toPx())
        }
    }
}

/** The visible bars, rounded, with a slight 3D gradient and a crisp border. */
private fun DrawScope.drawNotes(
    notes: List<FallingNote>, layout: KeyboardLayout, whiteKeyWidth: Float, currentBeat: Double, beatsPerMeasure: Int,
    hitLineY: Float, pixelsPerBeat: Float,
) {
    val corner = CornerRadius(3.5.dp.toPx())
    val border = Stroke(0.75.dp.toPx())
    val minHeight = 6.dp.toPx()
    val inset = 2.5.dp.toPx()
    for (note in notes) {
        val x = (layout.centerX(note.midiNote) * whiteKeyWidth).toFloat()
        val noteWidth = if (PianoKeys.isBlack(note.midiNote)) whiteKeyWidth * 0.58f else whiteKeyWidth - inset
        val relativeBeat = note.startBeat - currentBeat
        val top = hitLineY - ((relativeBeat + note.durationBeats) * pixelsPerBeat).toFloat()
        val bottom = hitLineY - (relativeBeat * pixelsPerBeat).toFloat()
        val height = max(bottom - top, minHeight)
        val topLeft = Offset(x - noteWidth / 2, top)
        val rectSize = Size(noteWidth, height)
        val color = LuksColors.colorForBeat(note.startBeat, beatsPerMeasure)
        drawRoundRect(
            Brush.linearGradient(
                listOf(color.copy(alpha = 0.95f), color, color.copy(alpha = 0.85f)),
                start = topLeft, end = Offset(topLeft.x + noteWidth, topLeft.y + height),
            ),
            topLeft, rectSize, corner,
        )
        drawRoundRect(Color.White.copy(alpha = 0.4f), topLeft, rectSize, corner, style = border)
    }
}

/** Upward radiating sparks (dx, dy, radius in dp) where a bar meets its key. */
private val sparkOffsets = listOf(
    Triple(-5f, -16f, 2.0f), Triple(4f, -22f, 2.5f), Triple(-10f, -28f, 1.8f), Triple(8f, -32f, 2.2f),
    Triple(-2f, -38f, 2.6f), Triple(12f, -18f, 1.6f), Triple(-7f, -44f, 2.0f),
)

/** Glowing flares and spark bursts where bars are crossing the hit line. */
private fun DrawScope.drawImpactSparks(
    notes: List<FallingNote>, layout: KeyboardLayout, whiteKeyWidth: Float, currentBeat: Double, beatsPerMeasure: Int,
    hitLineY: Float,
) {
    val dp = 1.dp.toPx()
    for (note in notes) {
        val relativeBeat = note.startBeat - currentBeat
        val endBeat = note.endBeat - currentBeat
        if (relativeBeat > 0.05 || endBeat <= 0.02) continue
        val x = (layout.centerX(note.midiNote) * whiteKeyWidth).toFloat()
        val color = LuksColors.colorForBeat(note.startBeat, beatsPerMeasure)
        // 1. Soft wide outer glow
        drawOval(color.copy(alpha = 0.4f), Offset(x - 18 * dp, hitLineY - 12 * dp), Size(36 * dp, 24 * dp))
        // 2. Bright white-hot core
        drawOval(Color.White.copy(alpha = 0.95f), Offset(x - 10 * dp, hitLineY - 7 * dp), Size(20 * dp, 14 * dp))
        // 3. Sparks: colored high up, white near the line
        for ((dx, dy, radius) in sparkOffsets) {
            val sparkColor = if (dy < -30) color.copy(alpha = 0.7f) else Color.White.copy(alpha = 0.85f)
            drawOval(sparkColor, Offset(x + dx * dp, hitLineY + dy * dp), Size(radius * 2 * dp, radius * 2 * dp))
        }
    }
}
