// ScoreLibrary.kt — the scores on the Deck: the samples bundled with the app (luksMusic/SampleScores, shared with
// iOS and Android, read from the app's resources on each start and never written) and the scores imported from
// .musicxml/.xml/.mxl files. Each import is a JSON file in <data>/scores/ with its MusicXML beside it, the layout of
// the Android app's ScoreRepository.
package com.lukstrike.luksmusic.desktop.data

import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.model.ScoreSource
import com.lukstrike.luksmusic.core.musicxml.MusicXMLParser
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.json.Json
import java.io.File

class ScoreLibrary(
    dataDir: File,
    /** Reads a bundled sample by file name; null when missing. */
    private val sampleSource: SampleSource = ResourceSamples,
) {
    private val dir = File(dataDir, "scores")

    private val _scores = MutableStateFlow<List<Score>>(emptyList())
    /** Samples first (in their bundled order), then the imports, newest first. */
    val scores: StateFlow<List<Score>> = _scores

    fun load() {
        val samples = sampleSource.names().mapNotNull { name ->
            val bytes = sampleSource.read(name) ?: return@mapNotNull null
            runCatching {
                MusicXMLParser.parse(bytes).score.let { parsed ->
                    // The files' own titles are plain ("Fur Elise"); the apps show the same names (SampleSeeder)
                    val (title, composer) = sampleNames[name.substringBeforeLast('.')] ?: (parsed.title to parsed.composer)
                    parsed.copy(id = sampleId(name), sampleId = name, source = ScoreSource.IMPORTED, title = title, composer = composer)
                }
            }.getOrNull()
        }
        val imports = dir.listFiles { f -> f.extension == "json" }.orEmpty().mapNotNull { file ->
            runCatching { json.decodeFromString(Score.serializer(), file.readText()) }.getOrNull()
        }.sortedByDescending { it.dateCreated }
        _scores.value = samples + imports
    }

    fun get(id: String): Score? = _scores.value.firstOrNull { it.id == id }

    /**
     * Reads a MusicXML file (plain or compressed) and adds it to the library. Throws when it is not MusicXML. A file
     * without a title is named after the file.
     */
    fun import(file: File): Score = import(file.readBytes(), file.nameWithoutExtension)

    fun import(bytes: ByteArray, fileName: String): Score {
        val parsed = MusicXMLParser.parse(bytes)
        val title = parsed.score.title.takeUnless { it.isBlank() || it == "Imported Score" } ?: fileName
        val score = parsed.score.copy(title = title, source = ScoreSource.IMPORTED, hasMusicXml = true, dateCreated = System.currentTimeMillis())
        dir.mkdirs()
        File(dir, "${score.id}.musicxml").writeText(parsed.musicXml)
        File(dir, "${score.id}.json").writeText(json.encodeToString(Score.serializer(), score))
        _scores.value = _scores.value.filter { it.isSample } + score + _scores.value.filter { !it.isSample }
        return score
    }

    /** Removes an imported score; the samples stay. */
    fun delete(id: String) {
        val score = get(id) ?: return
        if (score.isSample) return
        File(dir, "$id.json").delete()
        File(dir, "$id.musicxml").delete()
        _scores.value = _scores.value.filterNot { it.id == id }
    }

    companion object {
        val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }
        val importExtensions = setOf("musicxml", "xml", "mxl")

        fun sampleId(fileName: String) = "sample:" + fileName.substringBeforeLast('.')

        /** Titles and composers of the bundled pieces, the same as the iOS and Android apps. */
        private val sampleNames = mapOf(
            "fur-elise" to ("Für Elise (Bagatelle No. 25)" to "Ludwig van Beethoven"),
            "minuet-in-g" to ("Minuet in G Major (BWV Anh. 114)" to "Christian Petzold / J.S. Bach"),
            "gymnopedie-1" to ("Gymnopédie No. 1" to "Erik Satie"),
            "moonlight-sonata-1" to ("Moonlight Sonata (Op. 27 No. 2)" to "Ludwig van Beethoven"),
        )
    }
}

/** Where the bundled samples come from. */
interface SampleSource {
    fun names(): List<String>
    fun read(name: String): ByteArray?
}

/** The samples packed into the app (build.gradle.kts copies luksMusic/SampleScores to samples/ with an index). */
object ResourceSamples : SampleSource {
    override fun names(): List<String> =
        read("index.txt")?.decodeToString()?.lines()?.map { it.trim() }?.filter { it.isNotEmpty() }.orEmpty()

    override fun read(name: String): ByteArray? =
        ScoreLibrary::class.java.getResourceAsStream("/samples/$name")?.use { it.readBytes() }
}
