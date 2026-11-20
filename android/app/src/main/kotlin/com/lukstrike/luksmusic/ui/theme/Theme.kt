// Theme.kt — the dark, piano-centric look of the iOS app (Extensions/Color+Theme.swift), in Material 3.
package com.lukstrike.luksmusic.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object LuksColors {
    val pianoBlack = Color(0.08f, 0.08f, 0.10f)
    val pianoWhite = Color(0.95f, 0.93f, 0.90f)
    val staffLine = Color(0.55f, 0.55f, 0.60f)
    val noteDefault = Color(0.85f, 0.85f, 0.88f)
    val noteCorrect = Color(0.30f, 0.85f, 0.45f)
    val noteIncorrect = Color(0.92f, 0.30f, 0.30f)
    val noteMissed = Color(0.95f, 0.60f, 0.20f)
    val noteUpcoming = Color(0.45f, 0.45f, 0.50f)
    val accentIndigo = Color(0.35f, 0.34f, 0.84f)
    val backgroundPrimary = Color(0.07f, 0.07f, 0.09f)
    val backgroundSecondary = Color(0.12f, 0.12f, 0.15f)
    val backgroundTertiary = Color(0.17f, 0.17f, 0.21f)
    val textSecondary = Color(0.62f, 0.62f, 0.67f)
    val success = Color(0.30f, 0.85f, 0.45f)
    val warning = Color(0.95f, 0.60f, 0.20f)

    /** The color of each beat of a measure, shared by the score and the falling notes. */
    fun colorForBeat(beat: Double, beatsPerMeasure: Int = 4): Color {
        val beatInt = maxOf(1, kotlin.math.floor(beat).toInt())
        return when ((beatInt - 1) % maxOf(1, beatsPerMeasure)) {
            0 -> Color(1.0f, 0.32f, 0.35f)   // coral red
            1 -> Color(1.0f, 0.72f, 0.05f)   // amber
            2 -> Color(0.15f, 0.90f, 0.45f)  // emerald
            3 -> Color(0.0f, 0.85f, 1.0f)    // cyan
            4 -> Color(0.75f, 0.40f, 0.95f)  // purple
            else -> Color(1.0f, 0.40f, 0.75f) // pink
        }
    }
}

private val DarkColors = darkColorScheme(
    primary = LuksColors.accentIndigo,
    onPrimary = Color.White,
    primaryContainer = Color(0.22f, 0.21f, 0.52f),
    onPrimaryContainer = Color.White,
    secondary = Color(0.55f, 0.54f, 0.98f),
    background = LuksColors.backgroundPrimary,
    onBackground = Color(0.95f, 0.95f, 0.97f),
    surface = LuksColors.backgroundPrimary,
    onSurface = Color(0.95f, 0.95f, 0.97f),
    surfaceVariant = LuksColors.backgroundSecondary,
    onSurfaceVariant = LuksColors.textSecondary,
    surfaceContainer = LuksColors.backgroundSecondary,
    surfaceContainerHigh = LuksColors.backgroundTertiary,
    surfaceContainerLow = Color(0.10f, 0.10f, 0.12f),
    error = LuksColors.noteIncorrect,
    outline = Color(0.30f, 0.30f, 0.35f),
    outlineVariant = Color(0.22f, 0.22f, 0.26f),
)

@Composable
fun LuksMusicTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkColors, content = content)
}
