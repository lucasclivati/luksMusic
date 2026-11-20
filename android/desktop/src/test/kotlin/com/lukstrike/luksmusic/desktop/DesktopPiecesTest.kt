package com.lukstrike.luksmusic.desktop

import androidx.compose.ui.input.key.Key
import com.lukstrike.luksmusic.desktop.audio.Pcm
import com.lukstrike.luksmusic.desktop.data.AppPaths
import com.lukstrike.luksmusic.desktop.data.DesktopSettings
import com.lukstrike.luksmusic.desktop.data.ResourceSamples
import com.lukstrike.luksmusic.desktop.data.ScoreLibrary
import com.lukstrike.luksmusic.desktop.data.SettingsStore
import com.lukstrike.luksmusic.desktop.library.LibraryNavigation
import com.lukstrike.luksmusic.desktop.midi.KeyEvent
import com.lukstrike.luksmusic.desktop.midi.MidiPorts
import com.lukstrike.luksmusic.desktop.midi.PortInfo
import com.lukstrike.luksmusic.desktop.ui.Strings
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

class DesktopPiecesTest {

    private fun tempDir(): File = Files.createTempDirectory("luksmusic").toFile()

    // ---- MIDI

    @Test
    fun midiMessagesBecomeKeyEvents() {
        assertEquals(KeyEvent.NoteOn(60, 100), MidiPorts.event(0x90, 0, 60, 100))
        // Note on with velocity 0 is a release
        assertEquals(KeyEvent.NoteOff(60), MidiPorts.event(0x90, 3, 60, 0))
        assertEquals(KeyEvent.NoteOff(61), MidiPorts.event(0x80, 0, 61, 40))
        assertEquals(KeyEvent.Sustain(true), MidiPorts.event(0xB0, 0, 64, 127))
        assertEquals(KeyEvent.Sustain(false), MidiPorts.event(0xB0, 0, 64, 10))
        assertNull(MidiPorts.event(0xB0, 0, 7, 100))
        assertNull(MidiPorts.event(0xE0, 0, 0, 64))
    }

    @Test
    fun onlyInputPortsOpenAndHotPlugIsADiff() {
        val keyboard = PortInfo("kb", "Digital Piano [hw:1,0,0]", true)
        val synth = PortInfo("gervill", "Gervill", false)
        val pad = PortInfo("pad", "Pads", true)
        assertEquals(listOf(keyboard), MidiPorts.inputs(listOf(keyboard, synth, keyboard)))
        val (gone, added) = MidiPorts.diff(setOf("kb", "old"), listOf(keyboard, pad))
        assertEquals(setOf("old"), gone)
        assertEquals(listOf(pad), added)
        assertEquals("Digital Piano", MidiPorts.displayName(keyboard.name))
        assertEquals("Pads", MidiPorts.displayName("Pads"))
    }

    // ---- Audio

    @Test
    fun floatsBecomeLittleEndian16BitPcm() {
        val out = ByteArray(8)
        Pcm.toPcm16(floatArrayOf(0f, 1f, -1f, 2f), 4, out)
        assertArrayEquals(byteArrayOf(0, 0, 0xFF.toByte(), 0x7F, 0x01, 0x80.toByte(), 0xFF.toByte(), 0x7F), out)
    }

    // ---- Storage

    @Test
    fun dataFolderFollowsXdg() {
        val xdg = tempDir().absolutePath
        assertEquals(File(xdg, "luksMusic"), AppPaths.dataDir({ if (it == "XDG_DATA_HOME") xdg else null }, "/home/deck"))
        assertEquals(File("/home/deck", ".local/share/luksMusic"), AppPaths.dataDir({ null }, "/home/deck"))
        // A relative XDG path is ignored, as the spec says
        assertEquals(File("/home/deck", ".local/share/luksMusic"), AppPaths.dataDir({ "relative" }, "/home/deck"))
    }

    @Test
    fun settingsSurviveARestartAndABrokenFile() {
        val file = File(tempDir(), "settings.json")
        SettingsStore(file).update { it.copy(volume = 0.3f, midiSound = false, drillPositions = mapOf("a/right/one" to 8)) }
        val again = SettingsStore(file).value
        assertEquals(0.3f, again.volume)
        assertFalse(again.midiSound)
        assertEquals(8, again.drillPositions["a/right/one"])
        file.writeText("{ not json")
        assertEquals(DesktopSettings(), SettingsStore(file).value)
    }

    @Test
    fun libraryHasTheSamplesAndKeepsImports() {
        val dir = tempDir()
        val library = ScoreLibrary(dir).apply { load() }
        val samples = library.scores.value
        assertEquals(ResourceSamples.names().size, samples.size)
        assertTrue(samples.size >= 4)
        assertTrue(samples.all { it.isSample && it.totalNoteCount > 0 })

        val bytes = ResourceSamples.read("minuet-in-g.musicxml")!!
        val imported = library.import(bytes, "my-minuet")
        assertFalse(imported.isSample)
        assertEquals(samples.size + 1, library.scores.value.size)
        // Samples stay first, imports follow
        assertEquals(imported.id, library.scores.value[samples.size].id)

        val reloaded = ScoreLibrary(dir).apply { load() }
        assertEquals(imported.measures.size, reloaded.get(imported.id)!!.measures.size)
        assertTrue(File(dir, "scores/${imported.id}.musicxml").exists())

        reloaded.delete(samples.first().id) // samples cannot be deleted
        reloaded.delete(imported.id)
        assertEquals(samples.size, reloaded.scores.value.size)
        assertFalse(File(dir, "scores/${imported.id}.json").exists())
    }

    @Test(expected = Exception::class)
    fun importRejectsWhatIsNotMusicXml() {
        ScoreLibrary(tempDir()).import("hello".toByteArray(), "notes")
    }

    // ---- Navigation and keys

    @Test
    fun libraryArrowsMoveInTheGrid() {
        assertEquals(1, LibraryNavigation.move(0, 5, 3, 1, 0))
        assertEquals(3, LibraryNavigation.move(0, 5, 3, 0, 1))
        assertEquals(4, LibraryNavigation.move(1, 5, 3, 0, 1))
        // No move past the edges
        assertEquals(0, LibraryNavigation.move(0, 5, 3, -1, 0))
        assertEquals(2, LibraryNavigation.move(2, 5, 3, 0, 1))
        assertEquals(0, LibraryNavigation.move(0, 0, 3, 1, 0))
    }

    @Test
    fun deckButtonsMapToShortcuts() {
        assertEquals(Shortcut.BACK, Shortcuts.of(Key.Escape))
        assertEquals(Shortcut.ENTER, Shortcuts.of(Key.Enter))
        assertEquals(Shortcut.SPACE, Shortcuts.of(Key.Spacebar))
        assertEquals(Shortcut.SWITCH_SCREEN, Shortcuts.of(Key.Tab))
        assertEquals(Shortcut.PAGE_DOWN, Shortcuts.of(Key.PageDown))
        assertEquals(Shortcut.FULLSCREEN, Shortcuts.of(Key.F11))
        assertEquals(Shortcut.HAND_BOTH, Shortcuts.of(Key.Three))
        assertNull(Shortcuts.of(Key.Z))
    }

    @Test
    fun languageFollowsTheLocale() {
        assertTrue(Strings.forLanguage("pt").isPortuguese)
        assertTrue(Strings.forLanguage("pt_BR").isPortuguese)
        assertFalse(Strings.forLanguage("en").isPortuguese)
        assertFalse(Strings.forLanguage("de").isPortuguese)
        assertTrue(Strings.portuguese.usesLetters.not())
        // The environment wins over Java's locale, and the override over everything
        assertTrue(Strings.system({ if (it == "LANG") "pt_BR.UTF-8" else null }, "en").isPortuguese)
        assertFalse(Strings.system({ if (it == "LANG") "C.UTF-8" else null }, "en").isPortuguese)
        assertTrue(Strings.system({ null }, "pt").isPortuguese)
        assertFalse(Strings.system({ mapOf("LUKSMUSIC_LANG" to "en", "LANG" to "pt_BR.UTF-8")[it] }, "pt").isPortuguese)
        assertEquals("Teclado conectado", Strings.portuguese.keyboardConnected)
    }
}
