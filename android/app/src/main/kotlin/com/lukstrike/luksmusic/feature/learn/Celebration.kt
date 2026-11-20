// Celebration.kt — the burst of confetti and the stars popping in when a lesson ends with a star.
package com.lukstrike.luksmusic.feature.learn

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

private class Confetto(val angle: Float, val speed: Float, val spin: Float, val color: Color, val width: Float, val height: Float)

/** Confetti thrown up from the top center, falling under gravity and fading out. Plays once. */
@Composable
fun ConfettiBurst(modifier: Modifier = Modifier, pieces: Int = 90) {
    val colors = listOf(LearnColors.amber, LearnColors.cyan, LearnColors.green, LearnColors.violet, LearnColors.red, Color.White)
    val confetti = remember {
        List(pieces) {
            Confetto(
                angle = (-90f + Random.nextFloat() * 140f - 70f) * (Math.PI / 180).toFloat(),
                speed = 0.55f + Random.nextFloat() * 0.75f,
                spin = Random.nextFloat() * 720f - 360f,
                color = colors.random(),
                width = 6f + Random.nextFloat() * 6f,
                height = 3f + Random.nextFloat() * 4f,
            )
        }
    }
    val time = remember { Animatable(0f) }
    LaunchedEffect(Unit) { time.animateTo(1f, tween(2200, easing = LinearEasing)) }
    Canvas(modifier) {
        val t = time.value
        if (t >= 1f) return@Canvas
        val origin = Offset(size.width / 2, size.height * 0.28f)
        val reach = size.minDimension * 0.9f
        val gravity = size.height * 1.4f
        for (piece in confetti) {
            val x = origin.x + cos(piece.angle) * piece.speed * reach * t
            val y = origin.y + sin(piece.angle) * piece.speed * reach * t + gravity * t * t
            val alpha = (1f - t).coerceIn(0f, 1f)
            rotate(piece.spin * t, pivot = Offset(x, y)) {
                drawRect(
                    piece.color.copy(alpha = alpha),
                    topLeft = Offset(x - piece.width.dp.toPx() / 2, y - piece.height.dp.toPx() / 2),
                    size = Size(piece.width.dp.toPx(), piece.height.dp.toPx()),
                )
            }
        }
    }
}

/** Three stars, the earned ones popping in one after the other. */
@Composable
fun StarRow(earned: Int, starSize: Dp, modifier: Modifier = Modifier, animated: Boolean = true) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(starSize / 5)) {
        for (star in 1..3) {
            val filled = star <= earned
            val scale = remember { Animatable(if (animated && filled) 0f else 1f) }
            if (animated && filled) {
                LaunchedEffect(Unit) {
                    delay(250L + star * 220L)
                    scale.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow))
                }
            }
            Icon(
                if (filled) Icons.Filled.Star else Icons.Outlined.StarOutline,
                contentDescription = null,
                tint = LearnColors.amber,
                modifier = Modifier.size(starSize).graphicsLayer {
                    scaleX = scale.value
                    scaleY = scale.value
                    rotationZ = (1f - scale.value) * -45f
                },
            )
        }
    }
}
