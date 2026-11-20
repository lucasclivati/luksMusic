// Main.kt — luksMusic for Linux desktops, made for the Steam Deck propped on a piano's music stand with a MIDI
// keyboard on its USB port. One window titled "luksMusic", full screen by default (F11 switches), its keys handed to
// the app (Shortcuts.kt). Starts the piano sound and the MIDI search, and stops them on exit.
package com.lukstrike.luksmusic.desktop

import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.key.key
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.WindowPlacement
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.lukstrike.luksmusic.desktop.audio.DesktopAudio
import com.lukstrike.luksmusic.desktop.audio.Metronome
import com.lukstrike.luksmusic.desktop.data.AppPaths
import com.lukstrike.luksmusic.desktop.data.ScoreLibrary
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import com.lukstrike.luksmusic.desktop.midi.MidiInput
import com.lukstrike.luksmusic.desktop.ui.Strings
import java.awt.FileDialog
import java.io.File
import org.jetbrains.skia.Image

fun main() {
    val dataDir = AppPaths.dataDir().apply { mkdirs() }
    val settings = SettingsStore(File(dataDir, "settings.json"))
    val library = ScoreLibrary(dataDir).apply { load() }
    val audio = DesktopAudio().apply {
        volume = settings.value.volume
        start()
    }
    val metronome = Metronome(audio)
    val midi = MidiInput().apply { start() }
    val strings = Strings.system()
    val icon = Main::class.java.getResourceAsStream("/icon/luksMusic.png")?.use {
        BitmapPainter(Image.makeFromEncoded(it.readBytes()).toComposeImageBitmap())
    }

    application {
        val windowState = rememberWindowState(
            // LUKSMUSIC_WINDOWED=1 opens a 1280×800 window (handy for a check on a desktop computer)
            placement = if (settings.value.fullscreen && System.getenv("LUKSMUSIC_WINDOWED") == null) WindowPlacement.Fullscreen
            else WindowPlacement.Floating,
            size = DpSize(1280.dp, 800.dp),
        )
        val keys = androidx.compose.runtime.remember { KeyRouter() }
        fun setFullscreen(on: Boolean) {
            windowState.placement = if (on) WindowPlacement.Fullscreen else WindowPlacement.Floating
            settings.update { it.copy(fullscreen = on) }
        }
        Window(
            onCloseRequest = {
                midi.shutdown()
                audio.shutdown()
                exitApplication()
            },
            state = windowState,
            title = "luksMusic",
            icon = icon,
            onPreviewKeyEvent = { event ->
                if (event.type != KeyEventType.KeyDown) return@Window false
                val shortcut = Shortcuts.of(event.key) ?: return@Window false
                keys.handler(shortcut)
            },
        ) {
            val services = androidx.compose.runtime.remember {
                AppServices(
                    library = library,
                    settings = settings,
                    audio = audio,
                    metronome = metronome,
                    midiEvents = midi.events,
                    midiConnected = midi.connected,
                    rescanMidi = midi::rescan,
                    setVolume = { audio.volume = it },
                    audioAvailable = { audio.isAvailable },
                    pickFiles = {
                        val dialog = FileDialog(window, strings.importScore, FileDialog.LOAD).apply {
                            isMultipleMode = true
                            setFilenameFilter { _, name -> name.substringAfterLast('.').lowercase() in ScoreLibrary.importExtensions }
                            directory = System.getProperty("user.home")
                            isVisible = true
                        }
                        dialog.files.orEmpty().toList()
                    },
                    onBeat = { tick -> metronome.onBeat = { _, _ -> tick() } },
                )
            }
            App(
                services, strings, keys,
                fullscreen = windowState.placement == WindowPlacement.Fullscreen,
                onFullscreen = ::setFullscreen,
            )
        }
    }
}

/** Anchor for loading the app's resources. */
private object Main
