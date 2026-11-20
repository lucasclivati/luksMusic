// PianoKeyboard.kt — the on-screen piano (port of Views/Practice/PianoKeyboardView.swift), used by Modo Estudo,
// the lessons and the reading drill. The state is a plain class of Compose states, like the iOS
// PianoKeyboardViewModel: the screen's ViewModel owns one and changes it; the keyboard redraws.
//
// The whole keyboard is one drawing that reads the state while drawing, so a key lighting up (60 times a second under
// the falling notes) redraws it without recomposing anything. Touch is one pointer handler for every finger: a finger
// sliding onto another key releases the first and presses the next, like a glissando.
//
// PUBLIC API — practice, lessons and the reading drill use these members; keep their signatures stable
// (new members with defaults are fine).
package com.lukstrike.luksmusic.ui.components

import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
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
import androidx.compose.ui.input.pointer.PointerId
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.core.practice.KeyboardLayout
import com.lukstrike.luksmusic.core.practice.PianoKeys
import com.lukstrike.luksmusic.ui.theme.LuksColors
import com.lukstrike.luksmusic.ui.usesLetterNames
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class KeyLabelStyle { HIDDEN, LETTER, SOLFEGE }

class PianoKeyboardState(rangeStart: Int = 48, rangeEnd: Int = 84) {
    /** Lowest and highest MIDI notes shown (inclusive). */
    var rangeStart by mutableStateOf(rangeStart)
    var rangeEnd by mutableStateOf(rangeEnd)

    /** Keys held on the screen. */
    var pressedKeys by mutableStateOf(emptySet<Int>())
    /** Keys held on an external MIDI keyboard or heard by the microphone. */
    var midiActiveKeys by mutableStateOf(emptySet<Int>())
    /** The keys the student should play next. */
    var targetNoteKeys by mutableStateOf(emptySet<Int>())
    /** Keys sounding in the playback, per hand. */
    var bassActiveKeys by mutableStateOf(emptySet<Int>())
    var trebleActiveKeys by mutableStateOf(emptySet<Int>())
    /** Per-note colors (beat colors of the falling notes). */
    var keyColorsByNote by mutableStateOf(emptyMap<Int, Color>())
    var correctKeys by mutableStateOf(emptySet<Int>())
    var incorrectKeys by mutableStateOf(emptySet<Int>())
    var isSustainActive by mutableStateOf(false)
    var labelStyle by mutableStateOf(KeyLabelStyle.LETTER)
    /** Adds the octave number to the C keys' labels. */
    var marksOctaves by mutableStateOf(false)

    /**
     * The color a key shows, or null for its natural white or black: green or red for a key just judged, the beat
     * color (or the hand's color) for a key held, a paler hand color for a key to play next. Left hand = below middle
     * C unless the playback says otherwise.
     */
    fun keyColor(midi: Int): Color? {
        if (midi in correctKeys) return neonGreen
        if (midi in incorrectKeys) return systemRed

        val isActive = midi in pressedKeys || midi in midiActiveKeys
        if (isActive) keyColorsByNote[midi]?.let { return it }
        val isLeftHand = midi in bassActiveKeys || (midi < 60 && midi !in trebleActiveKeys)
        if (isActive) return if (isLeftHand) neonGreen else electricCyan

        if (midi in targetNoteKeys) {
            val guide = if (isLeftHand) neonGreen else electricCyan
            return guide.copy(alpha = if (PianoKeys.isBlack(midi)) 0.55f else 0.6f)
        }
        return null
    }

    companion object {
        /** Colors of the Synthesia-like look, shared with the falling notes. */
        val neonGreen = Color(0.22f, 0.95f, 0.38f)
        val electricCyan = Color(0.0f, 0.88f, 1.0f)
        internal val systemRed = Color(1.0f, 0.23f, 0.19f)
    }
}

/**
 * Draws [state]'s keys filling the available size. [onKeyPress] / [onKeyRelease] get the MIDI note touched;
 * several fingers at once and sliding across keys work like on the iOS keyboard.
 */
@Composable
fun PianoKeyboard(
    state: PianoKeyboardState,
    modifier: Modifier = Modifier,
    onKeyPress: (Int) -> Unit = {},
    onKeyRelease: (Int) -> Unit = {},
) {
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val textMeasurer = rememberTextMeasurer(cacheSize = 128)
    val usesLetters = usesLetterNames()
    val press by rememberUpdatedState(onKeyPress)
    val release by rememberUpdatedState(onKeyRelease)
    val description = stringResource(R.string.practice_keyboard)

    // Which key each finger holds, and the keys let go while the sustain pedal was down (still lit until it lifts)
    val touches = remember { mutableMapOf<PointerId, Int>() }
    val sustained = remember { mutableSetOf<Int>() }

    fun keyDown(midi: Int) {
        state.pressedKeys += midi
        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
        if (midi in state.targetNoteKeys) {
            state.correctKeys += midi
            scope.launch { delay(500); state.correctKeys -= midi }
        } else if (state.targetNoteKeys.isNotEmpty()) {
            state.incorrectKeys += midi
            view.performHapticFeedback(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT
                else HapticFeedbackConstants.LONG_PRESS
            )
            scope.launch { delay(300); state.incorrectKeys -= midi }
        }
        press(midi)
    }

    fun keyUp(midi: Int) {
        if (state.isSustainActive) sustained += midi else state.pressedKeys -= midi
        release(midi)
    }

    // The pedal lifted: the keys let go meanwhile go dark
    LaunchedEffect(state) {
        snapshotFlow { state.isSustainActive }.collect { down ->
            if (!down && sustained.isNotEmpty()) {
                state.pressedKeys -= (sustained - touches.values.toSet())
                sustained.clear()
            }
        }
    }

    Spacer(
        modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(4.dp))
            .semantics { contentDescription = description }
            .pointerInput(state) {
                var layout = KeyboardLayout(state.rangeStart, state.rangeEnd)
                fun keyAt(position: Offset): Int? {
                    if (layout.rangeStart != state.rangeStart || layout.rangeEnd != state.rangeEnd) {
                        layout = KeyboardLayout(state.rangeStart, state.rangeEnd)
                    }
                    val whiteWidth = size.width.toDouble() / maxOf(layout.whiteKeyCount, 1)
                    return layout.keyAt(position.x / whiteWidth, position.y.toDouble() / size.height)
                }
                awaitPointerEventScope {
                    try {
                        while (true) {
                            val event = awaitPointerEvent()
                            for (change in event.changes) {
                                val previous = touches[change.id]
                                val now = if (change.pressed) keyAt(change.position) else null
                                if (now != previous) {
                                    if (previous != null) {
                                        touches.remove(change.id)
                                        // Another finger may still hold it
                                        if (previous !in touches.values) keyUp(previous)
                                    }
                                    if (now != null) {
                                        val alreadyHeld = now in touches.values
                                        touches[change.id] = now
                                        if (!alreadyHeld) keyDown(now)
                                    }
                                }
                                if (change.pressed != change.previousPressed || change.positionChanged()) change.consume()
                            }
                        }
                    } finally {
                        // The keyboard went away under the fingers
                        touches.values.toSet().forEach(::keyUp)
                        touches.clear()
                    }
                }
            }
            .drawWithCache {
                val layout = KeyboardLayout(state.rangeStart, state.rangeEnd)
                val geometry = KeyGeometry(this, size, layout)
                val labels = KeyLabels(this, textMeasurer, layout, geometry, state.labelStyle, state.marksOctaves, usesLetters)
                val sustainLabel = textMeasurer.measure(
                    "SUS",
                    TextStyle(fontSize = 11.dp.toSp(), fontWeight = FontWeight.Bold, color = LuksColors.accentIndigo),
                )
                onDrawBehind {
                    drawWhiteKeys(state, layout, geometry, labels)
                    drawBlackKeys(state, layout, geometry, labels)
                    if (state.isSustainActive) drawSustainIndicator(sustainLabel)
                }
            }
    )
}

// MARK: - Geometry

/** Sizes in pixels for the current size, as on iOS: black keys 60% as wide and 62% as tall as the white ones. */
private class KeyGeometry(scope: Density, size: Size, layout: KeyboardLayout) {
    val whiteWidth = size.width / maxOf(layout.whiteKeyCount, 1)
    val whiteHeight = size.height
    val blackWidth = whiteWidth * KeyboardLayout.BLACK_WIDTH.toFloat()
    val blackHeight = whiteHeight * KeyboardLayout.BLACK_HEIGHT.toFloat()
    val corner = with(scope) { CornerRadius(3.dp.toPx()) }
    val hairline = with(scope) { 0.5.dp.toPx() }
    val glow = with(scope) { 8.dp.toPx() }
    val blackGlow = with(scope) { 10.dp.toPx() }
    val shadowOffset = with(scope) { 2.dp.toPx() }
    val whiteLabelPadding = with(scope) { 8.dp.toPx() }
    val blackLabelPadding = with(scope) { 6.dp.toPx() }

    fun blackLeft(layout: KeyboardLayout, midi: Int): Float =
        (layout.blackKeyLeft(midi, KeyboardLayout.BLACK_WIDTH) * whiteWidth).toFloat()
}

// MARK: - Labels

/** The key names, measured once per size and label style; drawn in the key's text color. */
private class KeyLabels(
    scope: Density,
    measurer: TextMeasurer,
    layout: KeyboardLayout,
    geometry: KeyGeometry,
    style: KeyLabelStyle,
    marksOctaves: Boolean,
    usesLetters: Boolean,
) {
    val white: Map<Int, TextLayoutResult>
    val black: Map<Int, TextLayoutResult>

    init {
        with(scope) {
            // iOS: min(width × 0.35, 14 pt) medium on white keys, min(width × 0.3, 10 pt) semibold on black keys,
            // shrinking to 60% when the name does not fit
            val whiteSize = minOf(geometry.whiteWidth * 0.35f, 14.dp.toPx())
            val blackSize = minOf(geometry.blackWidth * 0.3f, 10.dp.toPx())
            white = layout.whiteKeys.mapNotNull { midi ->
                whiteLabel(midi, style, marksOctaves, usesLetters)?.let {
                    midi to fitted(measurer, it, whiteSize, FontWeight.Medium, geometry.whiteWidth - 2f)
                }
            }.toMap()
            black = if (style == KeyLabelStyle.HIDDEN) emptyMap() else layout.blackKeys.associateWith { midi ->
                fitted(measurer, NoteNaming.chromaticName(midi, style == KeyLabelStyle.LETTER), blackSize, FontWeight.SemiBold, geometry.blackWidth - 2f)
            }
        }
    }

    private fun Density.fitted(measurer: TextMeasurer, text: String, sizePx: Float, weight: FontWeight, maxWidth: Float): TextLayoutResult {
        fun measure(px: Float) = measurer.measure(
            text,
            TextStyle(fontSize = px.toSp(), fontWeight = weight),
            overflow = TextOverflow.Clip,
            softWrap = false,
            maxLines = 1,
            constraints = Constraints(maxWidth = maxOf(1, maxWidth.toInt() * 2)),
        )
        val full = measure(sizePx)
        if (full.size.width <= maxWidth || full.size.width == 0) return full
        return measure(sizePx * maxOf(0.6f, maxWidth / full.size.width))
    }

    companion object {
        /**
         * The text written on a white key for a label style; with [marksOctave], each C also shows its octave
         * ("Dó4", or "C4" in English when the other keys have no label).
         */
        fun whiteLabel(midi: Int, style: KeyLabelStyle, marksOctave: Boolean, usesLetters: Boolean): String? {
            val name = when (style) {
                KeyLabelStyle.HIDDEN -> null
                KeyLabelStyle.LETTER -> NoteNaming.chromaticName(midi, usesLetters = true)
                KeyLabelStyle.SOLFEGE -> NoteNaming.chromaticName(midi, usesLetters = false)
            }
            if (!marksOctave || Math.floorMod(midi, 12) != 0) return name
            return (name ?: NoteNaming.chromaticName(midi, usesLetters)) + (midi / 12 - 1)
        }
    }
}

// MARK: - Drawing

private val whiteKeyColors = listOf(Color(0.98f, 0.98f, 0.98f), Color(0.93f, 0.93f, 0.93f), Color(0.88f, 0.88f, 0.88f))
private val blackKeyColors = listOf(Color(0.22f, 0.22f, 0.22f), Color(0.12f, 0.12f, 0.12f), Color(0.05f, 0.05f, 0.05f))
private val whiteBorder = Color.Gray.copy(alpha = 0.3f)
private val blackBorder = Color.Black.copy(alpha = 0.5f)

private fun DrawScope.drawWhiteKeys(state: PianoKeyboardState, layout: KeyboardLayout, g: KeyGeometry, labels: KeyLabels) {
    val colors = layout.whiteKeys.map(state::keyColor)
    val keySize = Size(g.whiteWidth, g.whiteHeight)
    layout.whiteKeys.forEachIndexed { index, _ ->
        val topLeft = Offset(index * g.whiteWidth, 0f)
        // On white, so a translucent guide color stays bright on a dark screen
        drawRoundRect(Color.White, topLeft, keySize, g.corner)
        val color = colors[index]
        val brush = if (color != null) {
            Brush.verticalGradient(listOf(color, color.copy(alpha = color.alpha * 0.85f)))
        } else {
            Brush.verticalGradient(whiteKeyColors)
        }
        drawRoundRect(brush, topLeft, keySize, g.corner)
    }
    // A glow spilling onto the neighbors of each lit key
    layout.whiteKeys.forEachIndexed { index, _ ->
        val color = colors[index] ?: return@forEachIndexed
        val left = index * g.whiteWidth
        drawSideGlow(color.copy(alpha = color.alpha * 0.6f), left, left + g.whiteWidth, 0f, g.whiteHeight, g.glow)
    }
    layout.whiteKeys.forEachIndexed { index, midi ->
        val left = index * g.whiteWidth
        drawRoundRect(whiteBorder, Offset(left, 0f), keySize, g.corner, style = Stroke(g.hairline))
        labels.white[midi]?.let { text ->
            val textColor = if (colors[index] == null) Color.Gray else Color.Black.copy(alpha = 0.75f)
            drawText(
                text, color = textColor,
                topLeft = Offset(left + (g.whiteWidth - text.size.width) / 2, g.whiteHeight - g.whiteLabelPadding - text.size.height),
            )
        }
    }
}

private fun DrawScope.drawBlackKeys(state: PianoKeyboardState, layout: KeyboardLayout, g: KeyGeometry, labels: KeyLabels) {
    val keySize = Size(g.blackWidth, g.blackHeight)
    for (midi in layout.blackKeys) {
        val left = g.blackLeft(layout, midi)
        val color = state.keyColor(midi)
        if (color != null) {
            drawSideGlow(color.copy(alpha = color.alpha * 0.8f), left, left + g.blackWidth, 0f, g.blackHeight, g.blackGlow)
        } else {
            // Soft shadow below the key
            drawRoundRect(
                Color.Black.copy(alpha = 0.3f), Offset(left - 1f, g.shadowOffset), Size(g.blackWidth + 2f, g.blackHeight),
                g.corner,
            )
        }
        val brush = if (color != null) {
            Brush.verticalGradient(listOf(color, color.copy(alpha = color.alpha * 0.8f)), startY = 0f, endY = g.blackHeight)
        } else {
            Brush.verticalGradient(blackKeyColors, startY = 0f, endY = g.blackHeight)
        }
        drawRoundRect(brush, Offset(left, 0f), keySize, g.corner)
        drawRoundRect(blackBorder, Offset(left, 0f), keySize, g.corner, style = Stroke(g.hairline))
        labels.black[midi]?.let { text ->
            drawText(
                text, color = color ?: Color.Gray,
                topLeft = Offset(left + (g.blackWidth - text.size.width) / 2, g.blackHeight - g.blackLabelPadding - text.size.height),
            )
        }
    }
}

/** A glow fading out from the sides (and bottom) of a lit key, like the iOS shadow in the key's color. */
private fun DrawScope.drawSideGlow(color: Color, left: Float, right: Float, top: Float, bottom: Float, radius: Float) {
    val clear = color.copy(alpha = 0f)
    drawRect(
        Brush.horizontalGradient(listOf(clear, color), startX = left - radius, endX = left),
        Offset(left - radius, top), Size(radius, bottom - top),
    )
    drawRect(
        Brush.horizontalGradient(listOf(color, clear), startX = right, endX = right + radius),
        Offset(right, top), Size(radius, bottom - top),
    )
    if (bottom < size.height) {
        drawRect(
            Brush.verticalGradient(listOf(color, clear), startY = bottom, endY = bottom + radius),
            Offset(left, bottom), Size(right - left, radius),
        )
    }
}

/** "SUS" in a capsule near the bottom right while the sustain pedal is down. */
private fun DrawScope.drawSustainIndicator(label: TextLayoutResult) {
    val padH = 6.dp.toPx()
    val padV = 3.dp.toPx()
    val width = label.size.width + padH * 2
    val height = label.size.height + padV * 2
    val center = Offset(size.width - 40.dp.toPx(), size.height - 20.dp.toPx())
    val topLeft = Offset(center.x - width / 2, center.y - height / 2)
    drawRoundRect(LuksColors.accentIndigo.copy(alpha = 0.2f), topLeft, Size(width, height), CornerRadius(height / 2))
    drawText(label, topLeft = Offset(topLeft.x + padH, topLeft.y + padV))
}
