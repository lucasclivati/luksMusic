// SettingsRepository.kt — small saved settings (the iOS app's UserDefaults / @AppStorage). Each feature declares its
// own keys next to the code that uses them, e.g.
//     private val A4_KEY = doublePreferencesKey("tuner.a4")
//     val a4 = settings.flow(A4_KEY, 440.0)
//     settings.set(A4_KEY, 442.0)
package com.lukstrike.luksmusic.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "settings")

class SettingsRepository(private val context: Context) {

    fun <T> flow(key: Preferences.Key<T>, default: T): Flow<T> =
        context.dataStore.data.map { it[key] ?: default }

    suspend fun <T> get(key: Preferences.Key<T>, default: T): T = flow(key, default).first()

    suspend fun <T> set(key: Preferences.Key<T>, value: T?) {
        context.dataStore.edit { prefs -> if (value == null) prefs.remove(key) else prefs[key] = value }
    }
}
