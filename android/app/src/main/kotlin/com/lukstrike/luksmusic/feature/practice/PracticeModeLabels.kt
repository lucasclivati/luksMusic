// PracticeModeLabels.kt — each practice mode's name and icon (PracticeMode.displayName / iconName in
// Models/PracticeSession.swift). Public so the progress history can show them too.
package com.lukstrike.luksmusic.feature.practice

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.QueueMusic
import androidx.compose.material.icons.outlined.BackHand
import androidx.compose.material.icons.outlined.FrontHand
import androidx.compose.material.icons.outlined.Piano
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.ui.graphics.vector.ImageVector
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.core.model.PracticeMode

@get:StringRes
val PracticeMode.labelRes: Int
    get() = when (this) {
        PracticeMode.FREE_PLAY -> R.string.practice_mode_free
        PracticeMode.GUIDED -> R.string.practice_mode_guided
        PracticeMode.HANDS_SEPARATE_RIGHT -> R.string.practice_mode_right_hand
        PracticeMode.HANDS_SEPARATE_LEFT -> R.string.practice_mode_left_hand
        PracticeMode.SLOW_PRACTICE -> R.string.practice_mode_slow
    }

val PracticeMode.icon: ImageVector
    get() = when (this) {
        PracticeMode.FREE_PLAY -> Icons.Outlined.Piano
        PracticeMode.GUIDED -> Icons.AutoMirrored.Outlined.QueueMusic
        PracticeMode.HANDS_SEPARATE_RIGHT -> Icons.Outlined.FrontHand
        PracticeMode.HANDS_SEPARATE_LEFT -> Icons.Outlined.BackHand
        PracticeMode.SLOW_PRACTICE -> Icons.Outlined.Speed
    }

/** The mode a [com.lukstrike.luksmusic.ui.navigation.PracticeRoute] names (enum name or saved name); guided by default. */
fun practiceModeFromRoute(name: String?): PracticeMode {
    if (name == null) return PracticeMode.GUIDED
    return PracticeMode.entries.firstOrNull { it.name.equals(name, ignoreCase = true) }
        ?: when (name) {
            "freePlay" -> PracticeMode.FREE_PLAY
            "handsSeparate_right" -> PracticeMode.HANDS_SEPARATE_RIGHT
            "handsSeparate_left" -> PracticeMode.HANDS_SEPARATE_LEFT
            "slowPractice" -> PracticeMode.SLOW_PRACTICE
            else -> PracticeMode.GUIDED
        }
}
