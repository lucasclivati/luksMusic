// Routes.kt — every screen the app can navigate to between features (type-safe Navigation Compose routes).
// A feature registers its own screens in its `xxxGraph()` (feature/<name>/<Name>Graph.kt); routes used only inside
// one feature may live in that feature's package.
package com.lukstrike.luksmusic.ui.navigation

import kotlinx.serialization.Serializable

// Tabs
@Serializable data object LearnRoute
@Serializable data object LibraryRoute
@Serializable data object TunerRoute
@Serializable data object ProgressRoute
@Serializable data object SettingsRoute

// Learn
@Serializable data class LessonRoute(val lessonId: String)
@Serializable data object ReadingDrillRoute
/** The reading drill for one score of the library (from the Aprender picker or the score player). */
@Serializable data class ReadingDrillScoreRoute(val scoreId: String)

// Play
@Serializable data class PlayerRoute(val scoreId: String)
/** [mode] is a PracticeMode name, null = the screen's default. */
@Serializable data class PracticeRoute(val scoreId: String, val mode: String? = null)
@Serializable data object OnlineLibraryRoute
@Serializable data class EditorRoute(val scoreId: String)
