// Theme.kt — the app's dark look (Android ui/theme/Theme.kt and feature/learn/LearnChrome.kt's web player colors),
// sized for the Steam Deck: read from a music stand, touched with a finger.
package com.lukstrike.luksmusic.desktop.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Colors of the web player (iOS PlayerTheme, Android LearnColors). */
object Palette {
    val background = Color(11, 17, 32)
    val panel = Color(17, 24, 39)
    val raised = Color(30, 41, 59)
    val raisedHigh = Color(45, 58, 80)
    val border = Color(51, 65, 85)
    val blue = Color(59, 130, 246)
    val deepBlue = Color(37, 99, 235)
    val cyan = Color(56, 189, 248)
    val green = Color(74, 222, 128)
    val text = Color(248, 250, 252)
    val muted = Color(148, 163, 184)
    val amber = Color(251, 191, 36)
    val violet = Color(167, 139, 250)
    val red = Color(248, 113, 113)
    val orange = Color(251, 146, 60)
    val paper = Color(0.98f, 0.97f, 0.94f)

    /** The color of each beat of a measure, shared by the falling notes and the keys they light (LuksColors). */
    fun colorForBeat(beat: Double, beatsPerMeasure: Int = 4): Color {
        val beatInt = maxOf(1, kotlin.math.floor(beat).toInt())
        return when ((beatInt - 1) % maxOf(1, beatsPerMeasure)) {
            0 -> Color(1.0f, 0.32f, 0.35f)
            1 -> Color(1.0f, 0.72f, 0.05f)
            2 -> Color(0.15f, 0.90f, 0.45f)
            3 -> Color(0.0f, 0.85f, 1.0f)
            4 -> Color(0.75f, 0.40f, 0.95f)
            else -> Color(1.0f, 0.40f, 0.75f)
        }
    }
}

/** Ink on the paper the staff is drawn on (Android StaffColors). */
object StaffColors {
    val ink = Color(0.07f, 0.09f, 0.13f)
    val current = Color(0.14f, 0.42f, 0.94f)
    val right = Color(0.09f, 0.62f, 0.27f)
    /** Found after a wrong key or a hint */
    val fixed = Color(0.90f, 0.50f, 0.04f)
    val wrong = Color(0.86f, 0.15f, 0.15f)
    val listening = Color(1f, 0.84f, 0f)
}

private val DarkColors = darkColorScheme(
    primary = Palette.deepBlue,
    onPrimary = Color.White,
    primaryContainer = Color(0.22f, 0.21f, 0.52f),
    onPrimaryContainer = Color.White,
    secondary = Palette.cyan,
    background = Palette.background,
    onBackground = Palette.text,
    surface = Palette.panel,
    onSurface = Palette.text,
    surfaceVariant = Palette.raised,
    onSurfaceVariant = Palette.muted,
    surfaceContainer = Palette.panel,
    surfaceContainerHigh = Palette.raised,
    surfaceContainerHighest = Palette.raisedHigh,
    surfaceContainerLow = Palette.panel,
    error = Palette.red,
    outline = Palette.border,
    outlineVariant = Palette.raised,
)

@Composable
fun LuksTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DarkColors, content = content)
}
