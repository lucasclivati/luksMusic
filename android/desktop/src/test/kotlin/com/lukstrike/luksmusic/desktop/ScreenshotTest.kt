// ScreenshotTest.kt — renders the app's screens offscreen at the Steam Deck's 1280×800 (Compose's ImageComposeScene,
// no window needed) into build/screens, so the layout can be reviewed without a Deck. Run with
// `./gradlew :desktop:screenshots`; the plain test task skips it.
package com.lukstrike.luksmusic.desktop

import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.unit.Density
import com.lukstrike.luksmusic.core.lessons.ReadingDrill
import com.lukstrike.luksmusic.core.lessons.ReadingHand
import com.lukstrike.luksmusic.core.lessons.ReadingNotes
import com.lukstrike.luksmusic.desktop.audio.NotePlayer
import com.lukstrike.luksmusic.desktop.data.DesktopSettings
import com.lukstrike.luksmusic.desktop.data.ScoreLibrary
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import com.lukstrike.luksmusic.desktop.midi.KeyEvent
import com.lukstrike.luksmusic.desktop.ui.Strings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import org.jetbrains.skia.EncodedImageFormat
import org.junit.Test
import java.io.File
import java.nio.file.Files

class ScreenshotTest {

    private val out = File(System.getProperty("luksmusic.screens") ?: "build/screens").apply { mkdirs() }

    private object SilentPlayer : NotePlayer {
        override fun playNote(midi: Int, velocity: Int, durationSeconds: Double?) = Unit
        override fun stopNote(midi: Int) = Unit
        override fun stopAllNotes() = Unit
        override fun setSustain(down: Boolean) = Unit
    }

    private class Harness(settings: DesktopSettings, val strings: Strings = Strings.english, connected: List<String> = listOf("Digital Piano")) {
        val dir: File = Files.createTempDirectory("luksmusic-shot").toFile()
        val store = SettingsStore(File(dir, "settings.json")).apply { update { settings } }
        val library = ScoreLibrary(dir).apply { load() }
        val midi = MutableSharedFlow<KeyEvent>(extraBufferCapacity = 64)
        val keys = KeyRouter()
        val services = AppServices(library, store, SilentPlayer, null, midi, MutableStateFlow(connected))
    }

    private fun shoot(
        name: String,
        harness: Harness,
        screen: Screen,
        settingsOpen: Boolean = false,
        actions: suspend Harness.(render: () -> Unit) -> Unit = {},
    ) {
        val scene = ImageComposeScene(1280, 800, Density(1f), coroutineContext = Dispatchers.Unconfined) {
            App(harness.services, harness.strings, harness.keys, fullscreen = true, onFullscreen = {}, initialScreen = screen, initialSettingsOpen = settingsOpen)
        }
        var time = 0L
        fun render() {
            repeat(3) { scene.render(time); time += 16_000_000L }
        }
        try {
            render()
            kotlinx.coroutines.runBlocking { harness.actions(::render) }
            repeat(40) { scene.render(time); time += 16_000_000L }
            val image = scene.render(time)
            File(out, "$name.png").writeBytes(image.encodeToData(EncodedImageFormat.PNG)!!.bytes)
        } finally {
            scene.close()
        }
    }

    private fun firstStepKeys(harness: Harness, id: String, hand: ReadingHand, notes: ReadingNotes): List<Set<Int>> {
        val score = harness.library.get(id)!!
        return ReadingDrill.steps(score.measures, hand, score.timeSignatureTop, score.timeSignatureBottom, notes).map { it.midiNotes }
    }

    @Test
    fun library() {
        val harness = Harness(DesktopSettings())
        shoot("01-library", harness, Screen.Library)
    }

    @Test
    fun drillRightHand() {
        val harness = Harness(DesktopSettings(drillHand = "right", drillNotes = "one", drillSegmentSize = 6))
        val id = ScoreLibrary.sampleId("fur-elise.musicxml")
        val steps = firstStepKeys(harness, id, ReadingHand.RIGHT, ReadingNotes.ONE)
        shoot("02-drill-right-hand", harness, Screen.Drill(id)) { render ->
            // Two right, then a wrong key
            for (keysOfStep in steps.take(2)) for (key in keysOfStep) { midi.emit(KeyEvent.NoteOn(key, 90)); render() }
            midi.emit(KeyEvent.NoteOn(steps[2].first() - 3, 90)); render()
        }
    }

    @Test
    fun drillBothHands() {
        val harness = Harness(DesktopSettings(drillHand = "both", drillNotes = "all", drillSegmentSize = 4))
        val id = ScoreLibrary.sampleId("minuet-in-g.musicxml")
        val steps = firstStepKeys(harness, id, ReadingHand.BOTH, ReadingNotes.ALL)
        shoot("03-drill-both-hands", harness, Screen.Drill(id)) { render ->
            for (key in steps.first()) { midi.emit(KeyEvent.NoteOn(key, 90)); render() }
        }
    }

    @Test
    fun drillPortuguese() {
        val harness = Harness(DesktopSettings(drillHand = "left", drillNotes = "two", drillSegmentSize = 4), Strings.portuguese)
        val id = ScoreLibrary.sampleId("moonlight-sonata-1.musicxml")
        val steps = firstStepKeys(harness, id, ReadingHand.LEFT, ReadingNotes.TWO)
        shoot("04-drill-portugues", harness, Screen.Drill(id)) { render ->
            for (key in steps.first()) { midi.emit(KeyEvent.NoteOn(key, 90)); render() }
            keys.handler(Shortcut.HINT); render()
        }
    }

    @Test
    fun studyFalling() {
        val harness = Harness(DesktopSettings(studyMode = "GUIDED", studyView = "falling"))
        val id = ScoreLibrary.sampleId("fur-elise.musicxml")
        shoot("05-study-falling-notes", harness, Screen.Study(id)) { render ->
            keys.handler(Shortcut.SPACE); render()
        }
    }

    @Test
    fun studyStaff() {
        val harness = Harness(DesktopSettings(studyMode = "GUIDED", studyView = "staff"))
        val id = ScoreLibrary.sampleId("minuet-in-g.musicxml")
        val steps = firstStepKeys(harness, id, ReadingHand.BOTH, ReadingNotes.ALL)
        shoot("06-study-staff", harness, Screen.Study(id)) { render ->
            keys.handler(Shortcut.SPACE); render()
            for (step in steps.take(3)) { for (key in step) midi.emit(KeyEvent.NoteOn(key, 90)); render() }
        }
    }

    @Test
    fun settings() {
        val harness = Harness(DesktopSettings(), Strings.portuguese)
        shoot("07-settings-pt", harness, Screen.Library, settingsOpen = true)
    }

    @Test
    fun libraryNoKeyboardPortuguese() {
        val harness = Harness(DesktopSettings(), Strings.portuguese, connected = emptyList())
        shoot("08-library-pt-no-keyboard", harness, Screen.Library)
    }
}
