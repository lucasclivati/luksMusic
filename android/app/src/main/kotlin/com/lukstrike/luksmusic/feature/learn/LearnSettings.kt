// LearnSettings.kt — what the Aprender tab remembers, under the iOS app's UserDefaults keys (same names, same
// meaning): the best stars of each lesson, "unlock every lesson", the lessons' microphone switch, and the reading
// drill's choices. The clef of each hand is shared with the score player (ClefChoice keys).
package com.lukstrike.luksmusic.feature.learn

import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.lukstrike.luksmusic.core.lessons.LessonProgress
import com.lukstrike.luksmusic.core.model.ClefChoice
import com.lukstrike.luksmusic.data.SettingsRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

object LearnKeys {
    /** Best stars per lesson id, as JSON `{"treble-1": 3}` (iOS: a [String: Int] dictionary) */
    val STARS = stringPreferencesKey("lessons.stars")
    val UNLOCK_ALL = booleanPreferencesKey("lessons.unlockAll")
    val USE_MICROPHONE = booleanPreferencesKey("lessons.useMicrophone")

    val DRILL_HAND = stringPreferencesKey("readingTrainer.hand")
    val DRILL_ORDER = stringPreferencesKey("readingTrainer.order")
    val DRILL_SEGMENT_SIZE = intPreferencesKey("readingTrainer.segmentSize")
    val DRILL_AUTO_ADVANCE = booleanPreferencesKey("readingTrainer.autoAdvance")
    val DRILL_KEY_LABELS = stringPreferencesKey("readingTrainer.keyLabels")

    /** Where the piece was being read in order, per score and hand */
    fun drillPosition(scoreKey: String, hand: String) = intPreferencesKey("readingTrainer.position.$scoreKey.$hand")

    val CLEF_RIGHT = stringPreferencesKey(ClefChoice.RIGHT_HAND_KEY)
    val CLEF_LEFT = stringPreferencesKey(ClefChoice.LEFT_HAND_KEY)
    val AUTOMATIC_USES_ALTO = booleanPreferencesKey(ClefChoice.AUTOMATIC_USES_ALTO_KEY)
}

/** The lessons' saved progress. */
class LessonProgressStore(private val settings: SettingsRepository) {
    private val starsSerializer = MapSerializer(String.serializer(), Int.serializer())

    val progress: Flow<LessonProgress> = combine(
        settings.flow(LearnKeys.STARS, ""),
        settings.flow(LearnKeys.UNLOCK_ALL, false),
    ) { stars, unlockAll -> LessonProgress(decode(stars), unlockAll) }

    /** Keeps the best result of [lessonId]. */
    suspend fun record(lessonId: String, stars: Int) {
        val current = LessonProgress(decode(settings.get(LearnKeys.STARS, "")))
        settings.set(LearnKeys.STARS, Json.encodeToString(starsSerializer, current.recording(lessonId, stars).stars))
    }

    suspend fun setUnlocksEverything(value: Boolean) = settings.set(LearnKeys.UNLOCK_ALL, value)

    private fun decode(json: String): Map<String, Int> =
        if (json.isEmpty()) emptyMap() else runCatching { Json.decodeFromString(starsSerializer, json) }.getOrDefault(emptyMap())
}
