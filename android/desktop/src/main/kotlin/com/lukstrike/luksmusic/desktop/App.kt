// App.kt — the app's screens and how they connect: the library, the sight-reading drill and Modo Estudo for a score
// (switched with Tab or the button on either screen), and Ajustes over any of them. The MIDI keyboard's keys go to
// the screen showing; the keys and Deck buttons (Shortcuts.kt) too.
package com.lukstrike.luksmusic.desktop

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.desktop.audio.NotePlayer
import com.lukstrike.luksmusic.desktop.data.ScoreLibrary
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import com.lukstrike.luksmusic.desktop.drill.DrillController
import com.lukstrike.luksmusic.desktop.drill.DrillScreen
import com.lukstrike.luksmusic.desktop.drill.handle
import com.lukstrike.luksmusic.desktop.library.LIBRARY_COLUMNS
import com.lukstrike.luksmusic.desktop.library.LibraryNavigation
import com.lukstrike.luksmusic.desktop.library.LibraryScreen
import com.lukstrike.luksmusic.desktop.midi.KeyEvent
import com.lukstrike.luksmusic.desktop.study.BeatClock
import com.lukstrike.luksmusic.desktop.study.StudyController
import com.lukstrike.luksmusic.desktop.study.StudyScreen
import com.lukstrike.luksmusic.desktop.study.handle
import com.lukstrike.luksmusic.desktop.ui.LocalStrings
import com.lukstrike.luksmusic.desktop.ui.LuksTheme
import com.lukstrike.luksmusic.desktop.ui.Strings
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File

/** What the screens need from the system (fakes in the screenshot test). */
class AppServices(
    val library: ScoreLibrary,
    val settings: SettingsStore,
    val audio: NotePlayer,
    val metronome: BeatClock?,
    val midiEvents: SharedFlow<KeyEvent>,
    val midiConnected: StateFlow<List<String>>,
    val rescanMidi: () -> Unit = {},
    val setVolume: (Float) -> Unit = {},
    val audioAvailable: () -> Boolean = { true },
    /** Shows a file chooser for MusicXML files. */
    val pickFiles: () -> List<File> = { emptyList() },
    /** Metronome beats, for the button's flash. */
    val onBeat: ((() -> Unit) -> Unit) = {},
)

sealed interface Screen {
    data object Library : Screen
    data class Drill(val scoreId: String) : Screen
    data class Study(val scoreId: String) : Screen
}

/** Lets the window hand its keys to whatever the app is showing. */
class KeyRouter {
    var handler: (Shortcut) -> Boolean = { false }
}

@Composable
fun App(
    services: AppServices,
    strings: Strings,
    keys: KeyRouter,
    fullscreen: Boolean,
    onFullscreen: (Boolean) -> Unit,
    initialScreen: Screen = Screen.Library,
    initialSettingsOpen: Boolean = false,
) {
    val scores by services.library.scores.collectAsState()
    val connected by services.midiConnected.collectAsState()
    var screen by remember { mutableStateOf(initialScreen) }
    var settingsOpen by remember { mutableStateOf(initialSettingsOpen) }
    var deleteTarget by remember { mutableStateOf<Score?>(null) }
    var selected by remember { mutableIntStateOf(0) }
    var message by remember { mutableStateOf<String?>(null) }
    var held by remember { mutableStateOf(emptySet<Int>()) }
    var beatFlash by remember { mutableIntStateOf(0) }
    var settings by remember { mutableStateOf(services.settings.value) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { services.onBeat { beatFlash += 1 } }

    val currentScore = when (val s = screen) {
        is Screen.Drill -> services.library.get(s.scoreId)
        is Screen.Study -> services.library.get(s.scoreId)
        Screen.Library -> null
    }
    val drill = remember(screen) {
        (screen as? Screen.Drill)?.let { s -> services.library.get(s.scoreId) }?.let { score ->
            DrillController(score, services.audio, services.settings, scope, strings.usesLetters)
        }
    }
    val study = remember(screen) {
        (screen as? Screen.Study)?.let { s -> services.library.get(s.scoreId) }?.let { score ->
            StudyController(score, services.audio, services.metronome, services.settings, scope)
        }
    }
    val liveDrill by rememberUpdatedState(drill)
    val liveStudy by rememberUpdatedState(study)
    DisposableEffect(drill) { onDispose { drill?.close() } }
    DisposableEffect(study) { onDispose { study?.close() } }

    fun updateSettings(change: (com.lukstrike.luksmusic.desktop.data.DesktopSettings) -> com.lukstrike.luksmusic.desktop.data.DesktopSettings) {
        services.settings.update(change)
        settings = services.settings.value
    }

    fun switchScreen() {
        screen = when (val s = screen) {
            is Screen.Drill -> Screen.Study(s.scoreId)
            is Screen.Study -> Screen.Drill(s.scoreId)
            Screen.Library -> return
        }
    }

    fun import() {
        for (file in services.pickFiles()) {
            message = runCatching { services.library.import(file) }
                .fold({ strings.importDone(it.title) }, { strings.importFailed(file.name) })
        }
    }

    // The MIDI keyboard's keys, to the screen showing
    LaunchedEffect(Unit) {
        services.midiEvents.collect { event ->
            val sounds = services.settings.value.midiSound
            when (event) {
                is KeyEvent.NoteOn -> {
                    held = held + event.note
                    val d = liveDrill
                    val st = liveStudy
                    when {
                        d != null -> d.keyPressed(event.note, event.velocity, sounds)
                        st != null -> st.keyPressed(event.note, event.velocity, sounds)
                        sounds -> services.audio.playNote(event.note, event.velocity)
                    }
                }
                is KeyEvent.NoteOff -> {
                    held = held - event.note
                    if (sounds) services.audio.stopNote(event.note)
                }
                is KeyEvent.Sustain -> if (sounds) services.audio.setSustain(event.down)
            }
        }
    }

    SideEffect {
        keys.handler = handler@{ shortcut ->
            if (shortcut == Shortcut.FULLSCREEN) {
                onFullscreen(!fullscreen)
                return@handler true
            }
            deleteTarget?.let { target ->
                when (shortcut) {
                    Shortcut.ENTER -> { services.library.delete(target.id); deleteTarget = null; selected = 0 }
                    Shortcut.BACK -> deleteTarget = null
                    else -> Unit
                }
                return@handler true
            }
            if (settingsOpen) {
                when (shortcut) {
                    Shortcut.BACK, Shortcut.SETTINGS -> settingsOpen = false
                    Shortcut.LEFT, Shortcut.DOWN -> { val v = (settings.volume - 0.1f).coerceIn(0f, 1f); services.setVolume(v); updateSettings { it.copy(volume = v) } }
                    Shortcut.RIGHT, Shortcut.UP -> { val v = (settings.volume + 0.1f).coerceIn(0f, 1f); services.setVolume(v); updateSettings { it.copy(volume = v) } }
                    Shortcut.ENTER, Shortcut.SPACE -> updateSettings { it.copy(midiSound = !it.midiSound) }
                    else -> Unit
                }
                return@handler true
            }
            if (shortcut == Shortcut.SETTINGS) {
                settingsOpen = true
                return@handler true
            }
            when (screen) {
                Screen.Library -> {
                    val score = scores.getOrNull(selected)
                    when (shortcut) {
                        Shortcut.LEFT -> selected = LibraryNavigation.move(selected, scores.size, LIBRARY_COLUMNS, -1, 0)
                        Shortcut.RIGHT -> selected = LibraryNavigation.move(selected, scores.size, LIBRARY_COLUMNS, 1, 0)
                        Shortcut.UP -> selected = LibraryNavigation.move(selected, scores.size, LIBRARY_COLUMNS, 0, -1)
                        Shortcut.DOWN -> selected = LibraryNavigation.move(selected, scores.size, LIBRARY_COLUMNS, 0, 1)
                        Shortcut.ENTER, Shortcut.SPACE -> score?.let { screen = Screen.Drill(it.id) }
                        Shortcut.OPEN_STUDY, Shortcut.SWITCH_SCREEN -> score?.let { screen = Screen.Study(it.id) }
                        Shortcut.IMPORT -> import()
                        Shortcut.DELETE -> score?.takeIf { !it.isSample }?.let { deleteTarget = it }
                        else -> return@handler false
                    }
                    true
                }
                is Screen.Drill, is Screen.Study -> when (shortcut) {
                    Shortcut.BACK -> { screen = Screen.Library; true }
                    Shortcut.SWITCH_SCREEN -> { switchScreen(); true }
                    else -> drill?.handle(shortcut) ?: study?.handle(shortcut) ?: false
                }
            }
        }
    }

    CompositionLocalProvider(LocalStrings provides strings) {
        LuksTheme {
            Box(Modifier.fillMaxSize()) {
                when {
                    drill != null -> DrillScreen(drill, connected, held, { screen = Screen.Library }, ::switchScreen) { settingsOpen = true }
                    study != null && currentScore != null ->
                        StudyScreen(study, currentScore, connected, held, beatFlash, { screen = Screen.Library }, ::switchScreen) { settingsOpen = true }
                    else -> LibraryScreen(
                        scores, selected, connected, message,
                        onSelect = { selected = it },
                        onDrill = { screen = Screen.Drill(it.id) },
                        onStudy = { screen = Screen.Study(it.id) },
                        onImport = ::import,
                        onDelete = { deleteTarget = it },
                        onSettings = { settingsOpen = true },
                    )
                }
                if (settingsOpen) {
                    SettingsPanel(
                        connected, settings.midiSound, settings.volume, fullscreen, services.audioAvailable(),
                        onMidiSound = { on -> updateSettings { it.copy(midiSound = on) } },
                        onVolume = { v -> services.setVolume(v); updateSettings { it.copy(volume = v) } },
                        onFullscreen = onFullscreen,
                        onRescan = services.rescanMidi,
                        onClose = { settingsOpen = false },
                    )
                }
                deleteTarget?.let { target ->
                    ConfirmDialog(
                        strings.deleteConfirm(target.title), strings.delete,
                        onConfirm = { services.library.delete(target.id); deleteTarget = null; selected = 0 },
                        onCancel = { deleteTarget = null },
                    )
                }
            }
        }
    }
}
