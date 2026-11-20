// TunerGauge.kt — a needle over an arc from -50 to +50 cents, with the green "in tune" band of ±5 cents in the middle
// (iOS TunerGauge in Views/Tuner/TunerView.swift). Also the microphone's level meter.
package com.lukstrike.luksmusic.feature.tuner

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.EaseOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.TuningReading
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

private const val RANGE = 50f
/** The arc's half-width, in degrees from the vertical. */
private const val SWEEP = 62f

/** The color for a reading [cents] off: green in tune, amber within 20 cents, red beyond. */
internal fun tuningColor(cents: Double?): Color = when {
    cents == null -> TunerPalette.border
    abs(cents) <= TuningReading.IN_TUNE_CENTS -> TunerPalette.green
    abs(cents) <= 20 -> TunerPalette.beat
    else -> TunerPalette.downbeat
}

/** [cents] null rests the needle in the middle, dimmed. */
@Composable
fun TunerGauge(cents: Double?, modifier: Modifier = Modifier) {
    val shown by animatedNeedle(cents)
    val needleColor = tuningColor(cents)
    val measurer = rememberTextMeasurer()
    val labelStyle = TextStyle(
        color = TunerPalette.muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum",
    )
    val description = cents?.let { "${it.roundToInt()} cents" } ?: "--"

    Canvas(modifier.semantics { stateDescription = description }) {
        val pivot = Offset(size.width / 2, size.height - 8.dp.toPx())
        val radius = minOf(size.width / 2 - 12.dp.toPx(), size.height - 24.dp.toPx())
        val band = 16.dp.toPx()

        drawPath(arc(-RANGE, RANGE, pivot, radius), TunerPalette.raised, style = Stroke(band, cap = StrokeCap.Round))
        drawPath(arc(-20f, 20f, pivot, radius), TunerPalette.beat.copy(alpha = 0.25f), style = Stroke(band))
        val inTune = TuningReading.IN_TUNE_CENTS.toFloat()
        drawPath(arc(-inTune, inTune, pivot, radius), TunerPalette.green, style = Stroke(band))

        // Ticks every 5 cents, longer every 25
        for (value in -50..50 step 5) {
            val long = value % 25 == 0
            drawLine(
                TunerPalette.muted.copy(alpha = 0.7f),
                point(value.toFloat(), pivot, radius - 12.dp.toPx()),
                point(value.toFloat(), pivot, radius - (if (long) 22 else 16).dp.toPx()),
                strokeWidth = 1.5.dp.toPx(),
            )
        }
        for (value in listOf(-50, -25, 0, 25, 50)) {
            val layout = measurer.measure(if (value > 0) "+$value" else "$value", labelStyle)
            val center = point(value.toFloat(), pivot, radius - 30.dp.toPx())
            drawText(layout, topLeft = center - Offset(layout.size.width / 2f, layout.size.height / 2f))
        }

        // The needle, turned around the pivot
        val length = radius + 6.dp.toPx()
        rotate(degrees = shown / RANGE * SWEEP, pivot = pivot) {
            drawLine(
                needleColor, pivot, Offset(pivot.x, pivot.y - length),
                strokeWidth = 4.dp.toPx(), cap = StrokeCap.Round,
            )
        }
        drawCircle(needleColor, radius = 8.dp.toPx(), center = pivot)
    }
}

@Composable
private fun animatedNeedle(cents: Double?) = animateFloatAsState(
    targetValue = (cents ?: 0.0).toFloat().coerceIn(-RANGE, RANGE),
    animationSpec = tween(durationMillis = 180, easing = EaseOut),
    label = "needle",
)

/** Where [cents] falls on a circle of [distance] around the pivot. */
private fun point(cents: Float, pivot: Offset, distance: Float): Offset {
    val angle = Math.toRadians((cents / RANGE * SWEEP).toDouble())
    return Offset(pivot.x + distance * sin(angle).toFloat(), pivot.y - distance * cos(angle).toFloat())
}

private fun arc(start: Float, end: Float, pivot: Offset, radius: Float): Path = Path().apply {
    val steps = 48
    for (step in 0..steps) {
        val location = point(start + (end - start) * step / steps, pivot, radius)
        if (step == 0) moveTo(location.x, location.y) else lineTo(location.x, location.y)
    }
}

/** Five bars that light with the microphone's level. */
@Composable
fun LevelMeter(level: Float, isListening: Boolean, modifier: Modifier = Modifier) {
    val label = stringResource(if (isListening) R.string.tuner_listening else R.string.tuner_mic_off)
    Row(
        modifier
            .background(TunerPalette.panel, CircleShape)
            .padding(horizontal = 10.dp, vertical = 6.dp)
            .semantics(mergeDescendants = true) { contentDescription = label },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            if (isListening) Icons.Filled.Mic else Icons.Filled.MicOff,
            contentDescription = null,
            tint = if (isListening) TunerPalette.cyan else TunerPalette.muted,
            modifier = Modifier.size(16.dp),
        )
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for (bar in 0 until 5) {
                Box(
                    Modifier
                        .width(4.dp)
                        .height((6 + bar * 3).dp)
                        .background(
                            if (bar < level * 5) TunerPalette.cyan else TunerPalette.raised,
                            RoundedCornerShape(1.5.dp),
                        )
                )
            }
        }
    }
}
