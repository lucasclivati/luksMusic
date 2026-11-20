// PlayerIcons.kt — icons the Material set lacks (iOS SF Symbols "metronome").
package com.lukstrike.luksmusic.feature.player

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/** A pyramid metronome with its pendulum swung to the right (tinted like any icon). */
val MetronomeIcon: ImageVector by lazy {
    ImageVector.Builder(name = "Metronome", defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f)
        .path(
            stroke = SolidColor(Color.Black), strokeLineWidth = 2f,
            strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
        ) {
            // Body
            moveTo(9f, 3f)
            lineTo(15f, 3f)
            lineTo(19.5f, 21f)
            lineTo(4.5f, 21f)
            close()
            // Base
            moveTo(6f, 16f)
            lineTo(18f, 16f)
            // Pendulum
            moveTo(12f, 16f)
            lineTo(17.5f, 6.5f)
        }
        .path(fill = SolidColor(Color.Black)) {
            // The pendulum's weight
            moveTo(14.4f, 10.2f)
            lineTo(16.6f, 11.4f)
            lineTo(15.6f, 13.2f)
            lineTo(13.4f, 12f)
            close()
        }
        .build()
}
