// Storage.kt — where the desktop app keeps its files (the XDG data folder: ~/.local/share/luksMusic on the Steam
// Deck) and its saved settings, one small JSON file read at start and written on each change.
package com.lukstrike.luksmusic.desktop.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File

object AppPaths {
    /** $XDG_DATA_HOME/luksMusic, else ~/.local/share/luksMusic ([env] and [home] are parameters for the tests). */
    fun dataDir(env: (String) -> String? = System::getenv, home: String = System.getProperty("user.home")): File {
        val xdg = env("XDG_DATA_HOME")?.takeIf { it.isNotBlank() && File(it).isAbsolute }
        return if (xdg != null) File(xdg, "luksMusic") else File(home, ".local/share/luksMusic")
    }
}

/** Everything the app remembers between runs. Unknown or missing fields fall back to these defaults. */
@Serializable
data class DesktopSettings(
    val volume: Float = 0.8f,
    /** Sound the notes of the MIDI keyboard (a controller has no speakers; a digital piano does). */
    val midiSound: Boolean = true,
    val drillHand: String = "right",
    val drillNotes: String = "one",
    val drillOrder: String = "sequential",
    val drillSegmentSize: Int = 4,
    val drillAutoAdvance: Boolean = true,
    /** Where each score was being read in order, by "scoreId/hand/notes". */
    val drillPositions: Map<String, Int> = emptyMap(),
    val studyMode: String = "GUIDED",
    val studyView: String = "falling",
    val metronome: Boolean = false,
    val fullscreen: Boolean = true,
)

class SettingsStore(private val file: File) {
    @Volatile var value: DesktopSettings = load()
        private set

    fun update(change: (DesktopSettings) -> DesktopSettings) {
        val next = synchronized(this) { change(value).also { value = it } }
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, file.name + ".tmp")
            tmp.writeText(json.encodeToString(DesktopSettings.serializer(), next))
            if (!tmp.renameTo(file)) { file.delete(); tmp.renameTo(file) }
        }
    }

    private fun load(): DesktopSettings =
        runCatching { json.decodeFromString(DesktopSettings.serializer(), file.readText()) }.getOrDefault(DesktopSettings())

    companion object {
        val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; prettyPrint = true }
    }
}
