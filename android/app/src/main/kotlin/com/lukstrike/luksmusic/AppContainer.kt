// AppContainer.kt — the app's shared services, made once (the iOS app's `.shared` singletons). Screens reach it
// with `appContainer()`; ViewModels get it from their factory. No DI framework: add a line here for a new service.
package com.lukstrike.luksmusic

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.lukstrike.luksmusic.account.AuthRepository
import com.lukstrike.luksmusic.audio.AudioEngine
import com.lukstrike.luksmusic.audio.MicrophonePitchService
import com.lukstrike.luksmusic.data.PracticeRepository
import com.lukstrike.luksmusic.data.ScoreRepository
import com.lukstrike.luksmusic.data.SettingsRepository
import com.lukstrike.luksmusic.midi.MidiInputService

class AppContainer(context: Context) {
    private val app = context.applicationContext

    /** The application context (assets, files), for services that are not Composables. */
    val appContext: Context get() = app

    val scores by lazy { ScoreRepository(app) }
    val practice by lazy { PracticeRepository(app) }
    val settings by lazy { SettingsRepository(app) }
    val auth by lazy { AuthRepository(app) }
    val audio by lazy { AudioEngine(app) }
    val microphone by lazy { MicrophonePitchService(app) }
    val midi by lazy { MidiInputService(app) }
}

/** The app's [AppContainer], from any composable. */
@Composable
fun appContainer(): AppContainer = (LocalContext.current.applicationContext as LuksMusicApp).container

/** The app's [AppContainer], from any Context. */
val Context.appContainer: AppContainer get() = (applicationContext as LuksMusicApp).container
