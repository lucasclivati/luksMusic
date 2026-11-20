// PlayerSettings.kt — the score player's remembered choices (iOS ScoreView's @AppStorage keys, same names), from
// score to score: how the engraving is laid out, its zoom, the keyboard, the concert hall reverb, the clef of each
// hand's staff, the metronome and the speed.
package com.lukstrike.luksmusic.feature.player

import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.lukstrike.luksmusic.core.model.ClefChoice
import com.lukstrike.luksmusic.data.SettingsRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/** The player remembers the chosen mode by its raw value (shared with iOS), so the raw values must not change. */
enum class ScoreDisplayMode(val raw: String) {
    /** "Página": two measures per line. */
    VERTICAL_SCROLL("Vertical Scroll"),
    /** "Linha única": the score runs sideways. */
    SINGLE_LINE("Single Line"),
    /** "Ampliada": one larger measure per line. */
    PORTRAIT_VIEW("Portrait View");

    companion object {
        fun fromRaw(raw: String?): ScoreDisplayMode = entries.firstOrNull { it.raw == raw } ?: PORTRAIT_VIEW
    }
}

/** What the engraving and the dock show. */
data class PlayerDisplay(
    val mode: ScoreDisplayMode = ScoreDisplayMode.PORTRAIT_VIEW,
    /** Zoom of the engraving (below 0.95 fits two measures per line). */
    val zoom: Double = 1.0,
    val showKeyboard: Boolean = true,
    /** "Sala de concerto": reverb on the piano. */
    val concertHall: Boolean = true,
    val rightClef: ClefChoice = ClefChoice.SCORE,
    val leftClef: ClefChoice = ClefChoice.SCORE,
    val automaticUsesAlto: Boolean = true,
) {
    /** "Página" fits two measures per line; "Ampliada" shows one larger measure per line. */
    val renderZoom: Double get() = zoom * (if (mode == ScoreDisplayMode.VERTICAL_SCROLL) 0.8 else 1.0)
}

class PlayerSettings(private val settings: SettingsRepository) {

    val display: Flow<PlayerDisplay> = combine(
        settings.flow(DISPLAY_MODE, ScoreDisplayMode.PORTRAIT_VIEW.raw),
        settings.flow(ZOOM, 1.0),
        settings.flow(SHOW_KEYBOARD, true),
        settings.flow(CONCERT_HALL, true),
        combine(
            settings.flow(RIGHT_CLEF, ClefChoice.SCORE.raw),
            settings.flow(LEFT_CLEF, ClefChoice.SCORE.raw),
            settings.flow(AUTOMATIC_USES_ALTO, true),
        ) { right, left, alto -> Triple(ClefChoice.fromRaw(right), ClefChoice.fromRaw(left), alto) },
    ) { mode, zoom, keyboard, hall, (right, left, alto) ->
        PlayerDisplay(ScoreDisplayMode.fromRaw(mode), zoom, keyboard, hall, right, left, alto)
    }

    suspend fun setMode(mode: ScoreDisplayMode) = settings.set(DISPLAY_MODE, mode.raw)
    suspend fun setZoom(zoom: Double) = settings.set(ZOOM, zoom)
    suspend fun setShowKeyboard(show: Boolean) = settings.set(SHOW_KEYBOARD, show)
    suspend fun setConcertHall(on: Boolean) = settings.set(CONCERT_HALL, on)
    suspend fun setRightClef(choice: ClefChoice) = settings.set(RIGHT_CLEF, choice.raw)
    suspend fun setLeftClef(choice: ClefChoice) = settings.set(LEFT_CLEF, choice.raw)
    suspend fun setAutomaticUsesAlto(on: Boolean) = settings.set(AUTOMATIC_USES_ALTO, on)

    suspend fun metronome(): Boolean = settings.get(METRONOME, false)
    suspend fun setMetronome(on: Boolean) = settings.set(METRONOME, on)
    suspend fun speed(): Double = settings.get(SPEED, 1.0)
    suspend fun setSpeed(speed: Double) = settings.set(SPEED, speed)

    companion object {
        private val DISPLAY_MODE = stringPreferencesKey("scorePlayer.displayMode")
        private val ZOOM = doublePreferencesKey("scorePlayer.zoom")
        private val SHOW_KEYBOARD = booleanPreferencesKey("scorePlayer.showKeyboard")
        private val CONCERT_HALL = booleanPreferencesKey("scorePlayer.concertHall")
        private val METRONOME = booleanPreferencesKey("scorePlayer.metronome")
        private val SPEED = doublePreferencesKey("scorePlayer.speed")
        // Shared with the reading drill
        private val RIGHT_CLEF = stringPreferencesKey(ClefChoice.RIGHT_HAND_KEY)
        private val LEFT_CLEF = stringPreferencesKey(ClefChoice.LEFT_HAND_KEY)
        private val AUTOMATIC_USES_ALTO = booleanPreferencesKey(ClefChoice.AUTOMATIC_USES_ALTO_KEY)

        val zoomLevels = listOf(0.8, 1.0, 1.15, 1.3)
        val speeds = listOf(0.5, 0.75, 1.0, 1.25)
    }
}
