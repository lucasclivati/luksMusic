// TunerPalette.kt — the web player's colors the iOS tuner is drawn with (PlayerTheme in
// Views/Score/Player/PlayerChrome.swift), so both apps' tuners look the same.
package com.lukstrike.luksmusic.feature.tuner

import androidx.compose.ui.graphics.Color

internal object TunerPalette {
    val background = Color(0xFF0B1120)
    val panel = Color(0xFF111827)
    val raised = Color(0xFF1E293B)
    val border = Color(0xFF334155)
    val deepBlue = Color(0xFF2563EB)
    val cyan = Color(0xFF38BDF8)
    val green = Color(0xFF4ADE80)
    val text = Color(0xFFF8FAFC)
    val muted = Color(0xFF94A3B8)
    /** Red, beyond 20 cents off. */
    val downbeat = Color(0xFFEF4444)
    /** Amber, within 20 cents. */
    val beat = Color(0xFFEAB308)
}
