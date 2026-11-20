// PlayerKeyboard.kt — port of Views/Score/Player/PlayerKeyboard.swift. The score player's keyboard, drawn like the
// web player's: keys under the cursor light up cyan for the right hand and green for the left, the keyboard slides
// to keep them in sight, and touching a key plays it (several fingers at once).
package com.lukstrike.luksmusic.feature.player

import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.input.pointer.PointerId
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.core.model.NoteNaming
import com.lukstrike.luksmusic.ui.usesLetterNames
import kotlin.math.floor
import kotlin.math.max

private val BlackPitchClasses = setOf(1, 3, 6, 8, 10)
private fun isBlack(midi: Int) = Math.floorMod(midi, 12) in BlackPitchClasses

private val WhiteGradient = listOf(Color.White, Color(226, 232, 240))
private val RightHandGradient = listOf(PlayerTheme.cyan, Color(2, 132, 199))
private val LeftHandGradient = listOf(PlayerTheme.green, Color(22, 163, 74))
private val TouchGradient = listOf(Color(251, 191, 36), Color(217, 119, 6))
private val BlackGradient = listOf(Color(51, 65, 85), Color(15, 23, 42))
private val KeyOutline = Color(148, 163, 184)
private val LabelColor = Color(100, 116, 139)

@Composable
fun PlayerKeyboard(
    trebleKeys: Set<Int>,
    bassKeys: Set<Int>,
    modifier: Modifier = Modifier,
    range: IntRange = 36..96,
    onPress: (Int) -> Unit = {},
    onRelease: (Int) -> Unit = {},
) {
    val whiteKeys = remember(range) { range.filterNot(::isBlack) }
    val blackKeys = remember(range) { range.filter(::isBlack) }
    val whiteIndex = remember(range) { whiteKeys.withIndex().associate { (i, midi) -> midi to i } }
    val letters = usesLetterNames()
    val textMeasurer = rememberTextMeasurer()
    val view = LocalView.current
    val density = LocalDensity.current
    val currentPress by rememberUpdatedState(onPress)
    val currentRelease by rememberUpdatedState(onRelease)

    // Touched keys by finger
    val pressed = remember { mutableStateMapOf<PointerId, Int>() }
    val offset = remember { Animatable(0f) }
    val follow = remember { KeyboardFollow() }

    BoxWithConstraints(
        modifier = modifier
            .background(Brush.verticalGradient(listOf(PlayerTheme.panel, Color(8, 13, 26))))
            .padding(start = 6.dp, end = 6.dp, bottom = 4.dp)
            .clipToBounds(),
    ) {
        val viewWidth = constraints.maxWidth.toFloat()
        // About three octaves on a phone, wider keys on bigger screens
        val keyWidth = max(with(density) { 18.dp.toPx() }, viewWidth / 21)
        val keyHeight = constraints.maxHeight - with(density) { 10.dp.toPx() }
        val totalWidth = whiteKeys.size * keyWidth
        val lit = trebleKeys + bassKeys

        LaunchedEffect(lit, viewWidth) {
            if (follow.width != viewWidth) {
                follow.width = viewWidth
                follow.positioned = false
            }
            val target = follow.target(lit, keyWidth, viewWidth, totalWidth, whiteIndex, offset.value) ?: return@LaunchedEffect
            if (follow.positioned) {
                offset.animateTo(target, tween(250, easing = FastOutSlowInEasing))
            } else {
                offset.snapTo(target)
                follow.positioned = true
            }
        }

        /** The key under a finger: a black key's front first, then the white key below. */
        fun keyAt(position: Offset): Int? {
            val x = position.x + offset.value
            if (position.y < 0 || position.y > keyHeight) return null
            if (position.y < keyHeight * 0.62f) {
                blackKeys.firstOrNull { midi ->
                    val index = whiteIndex[midi - 1] ?: return@firstOrNull false
                    val left = (index + 1) * keyWidth - keyWidth * 0.31f
                    x >= left && x < left + keyWidth * 0.62f
                }?.let { return it }
            }
            return whiteKeys.getOrNull(floor(x / keyWidth).toInt())
        }

        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(keyWidth, keyHeight, range) {
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        do {
                            val event = awaitPointerEvent()
                            for (change in event.changes) {
                                val held = pressed[change.id]
                                if (change.pressed && held == null) {
                                    val key = keyAt(change.position) ?: continue
                                    if (key in pressed.values) {
                                        pressed[change.id] = -1 // a second finger on a held key stays silent
                                    } else {
                                        pressed[change.id] = key
                                        currentPress(key)
                                        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                                    }
                                } else if (!change.pressed && held != null) {
                                    pressed.remove(change.id)
                                    if (held >= 0) currentRelease(held)
                                }
                                change.consume()
                            }
                        } while (event.changes.any { it.pressed })
                        // Fingers lifted outside the gesture's view of them
                        pressed.values.filter { it >= 0 }.forEach { currentRelease(it) }
                        pressed.clear()
                    }
                },
        ) {
            val touched = pressed.values.toSet()
            fun gradient(midi: Int): List<Color>? = when (midi) {
                in touched -> TouchGradient
                in trebleKeys -> RightHandGradient
                in bassKeys -> LeftHandGradient
                else -> null
            }
            val radius = 3.dp.toPx()
            val glow = 6.dp.toPx()
            translate(left = -offset.value) {
                // White keys, unlit first so a lit key's glow shows over its neighbours
                val whites = whiteKeys.withIndex().sortedBy { (_, midi) -> gradient(midi) != null }
                for ((index, midi) in whites) {
                    val left = index * keyWidth
                    if (left + keyWidth < offset.value - glow || left > offset.value + viewWidth + glow) continue
                    val colors = gradient(midi)
                    if (colors != null) drawGlow(Offset(left, 0f), Size(keyWidth, keyHeight), colors[0].copy(alpha = 0.8f), glow, radius)
                    drawKey(Offset(left, 0f), Size(keyWidth, keyHeight), colors ?: WhiteGradient, radius)
                    drawKeyOutline(Offset(left, 0f), Size(keyWidth, keyHeight), KeyOutline, 0.5.dp.toPx(), radius)
                    if (midi % 12 == 0) {
                        val label = textMeasurer.measure(
                            NoteNaming.nameWithOctave(midi, letters),
                            TextStyle(fontSize = 8.sp, fontWeight = FontWeight.Bold, color = if (colors != null) Color.White else LabelColor),
                        )
                        drawText(
                            label,
                            topLeft = Offset(left + (keyWidth - label.size.width) / 2, keyHeight - 4.dp.toPx() - label.size.height),
                        )
                    }
                }
                // Black keys sit on the line after their white neighbour
                val blackSize = Size(keyWidth * 0.62f, keyHeight * 0.62f)
                for (midi in blackKeys) {
                    val index = whiteIndex[midi - 1] ?: continue
                    val topLeft = Offset((index + 1) * keyWidth - keyWidth * 0.31f, 0f)
                    val colors = gradient(midi)
                    if (colors != null) {
                        drawGlow(topLeft, blackSize, colors[0].copy(alpha = 0.9f), glow, radius)
                        drawKey(topLeft, blackSize, listOf(colors[1], colors[1]), radius)
                    } else {
                        // Its shadow on the white keys
                        drawKey(topLeft + Offset(1.dp.toPx(), 2.dp.toPx()), blackSize, listOf(Color.Black.copy(alpha = 0.35f), Color.Black.copy(alpha = 0.35f)), radius)
                        drawKey(topLeft, blackSize, BlackGradient, radius)
                    }
                    drawKeyOutline(topLeft, blackSize, Color.Black, 1.dp.toPx(), radius)
                }
            }
        }
    }
}

/** Where the keyboard slides to keep the lit keys in sight; it stays put while they already are. */
private class KeyboardFollow {
    var positioned = false
    var width = -1f

    fun target(keys: Set<Int>, keyWidth: Float, viewWidth: Float, totalWidth: Float, whiteIndex: Map<Int, Int>, offset: Float): Float? {
        if (totalWidth <= viewWidth) return 0f
        // A black key sits on the line after its white neighbour
        val xs = keys.mapNotNull { midi ->
            whiteIndex[midi]?.let { (it + 0.5f) * keyWidth } ?: whiteIndex[midi - 1]?.let { (it + 1) * keyWidth }
        }
        val target = if (xs.isNotEmpty()) {
            val low = xs.min()
            val high = xs.max()
            if (positioned && low >= offset + keyWidth && high <= offset + viewWidth - keyWidth) return null
            (low + high) / 2 - viewWidth / 2
        } else if (!positioned) {
            val middleC = whiteIndex[60] ?: return null
            (middleC + 0.5f) * keyWidth - viewWidth / 2
        } else {
            return null
        }
        return target.coerceIn(0f, totalWidth - viewWidth)
    }
}

private fun keyPath(topLeft: Offset, size: Size, radius: Float) = Path().apply {
    addRoundRect(
        RoundRect(
            left = topLeft.x, top = topLeft.y, right = topLeft.x + size.width, bottom = topLeft.y + size.height,
            topLeftCornerRadius = CornerRadius.Zero, topRightCornerRadius = CornerRadius.Zero,
            bottomRightCornerRadius = CornerRadius(radius), bottomLeftCornerRadius = CornerRadius(radius),
        ),
    )
}

private fun DrawScope.drawKey(topLeft: Offset, size: Size, colors: List<Color>, radius: Float) {
    drawPath(keyPath(topLeft, size, radius), Brush.verticalGradient(colors, startY = topLeft.y, endY = topLeft.y + size.height))
}

private fun DrawScope.drawKeyOutline(topLeft: Offset, size: Size, color: Color, width: Float, radius: Float) {
    drawPath(keyPath(topLeft, size, radius), color, style = Stroke(width))
}

/** A soft halo around a lit key (iOS draws it as the key's shadow). */
private fun DrawScope.drawGlow(topLeft: Offset, size: Size, color: Color, spread: Float, radius: Float) {
    val steps = 3
    for (i in steps downTo 1) {
        val grow = spread * i / steps
        drawRoundRect(
            color = color.copy(alpha = color.alpha * 0.18f),
            topLeft = topLeft - Offset(grow, grow),
            size = Size(size.width + 2 * grow, size.height + 2 * grow),
            cornerRadius = CornerRadius(radius + grow),
        )
    }
}
