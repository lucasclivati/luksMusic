// SampleSeeder.kt — puts the bundled public-domain pieces (luksMusic/SampleScores, shared with iOS and packaged as
// assets) in a new library: port of ScoreStorageService.preloadSampleScoresIfNeeded. Each score keeps its sample's
// MusicXML, which the score viewer draws as is.
package com.lukstrike.luksmusic.feature.library

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import com.lukstrike.luksmusic.AppContainer
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.ScoreSource
import com.lukstrike.luksmusic.core.musicxml.MusicXMLParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

class SampleSeeder(private val container: AppContainer) {

    /** True until this launch checked (and if needed seeded) the library, so the library does not flash its empty
     *  state before the samples arrive. */
    val isSeeding: StateFlow<Boolean> get() = seeding

    /**
     * A public-domain piano piece bundled as MusicXML (`<file>.musicxml` in the assets): a CC0 edition from
     * MuseScore taken from the PDMX dataset, with its repeats written out so it reads in the order it is played.
     */
    private data class SamplePiece(
        val file: String,
        val title: String,
        val composer: String,
        val difficulty: Difficulty,
        val isFavorite: Boolean,
    )

    /**
     * Seeds the samples into an empty library, once per install. iOS seeds whenever the library is empty; here the
     * pieces someone deleted on purpose stay deleted (and scores restored by cloud sync after the first launch are
     * not doubled with samples).
     */
    suspend fun seedIfNeeded() = lock.withLock {
        try {
            if (container.settings.get(SEEDED_KEY, false)) return@withLock
            seed(container.appContext)
        } finally {
            seeding.value = false
        }
    }

    private suspend fun seed(context: Context) {
        // The library is read from disk in the background; seeding before it is loaded would see it empty
        container.scores.isLoaded.first { it }
        if (container.scores.scores.value.isNotEmpty()) {
            container.settings.set(SEEDED_KEY, true)
            return
        }

        val now = System.currentTimeMillis()
        samplePieces.forEachIndexed { index, piece ->
            val loaded = loadSample(context, piece) ?: return@forEachIndexed
            // Listed newest first in the order above (iOS: 100 s apart)
            val created = now - 100_000L * (index + 1)
            container.scores.save(loaded.first.copy(dateCreated = created, lastModified = created), loaded.second)
        }
        container.settings.set(SEEDED_KEY, true)
    }

    /** The bundled piece as a score and its MusicXML, or null when its file is missing or unreadable. */
    private suspend fun loadSample(context: Context, piece: SamplePiece) = withContext(Dispatchers.Default) {
        runCatching {
            val bytes = withContext(Dispatchers.IO) {
                context.assets.open("${piece.file}.musicxml").use { it.readBytes() }
            }
            val parsed = MusicXMLParser.parse(bytes)
            parsed.score.copy(
                title = piece.title,
                composer = piece.composer,
                difficulty = piece.difficulty,
                isFavorite = piece.isFavorite,
                source = ScoreSource.MANUAL,
                sampleId = piece.file,
            ) to parsed.musicXml
        }.getOrNull()
    }

    companion object {
        private val SEEDED_KEY = booleanPreferencesKey("library.samplesSeeded")
        private val lock = Mutex()
        private val seeding = MutableStateFlow(true)
        private val samplePieces = listOf(
            SamplePiece("fur-elise", "Für Elise (Bagatelle No. 25)", "Ludwig van Beethoven", Difficulty.INTERMEDIATE, isFavorite = true),
            SamplePiece("minuet-in-g", "Minuet in G Major (BWV Anh. 114)", "Christian Petzold / J.S. Bach", Difficulty.BEGINNER, isFavorite = true),
            SamplePiece("gymnopedie-1", "Gymnopédie No. 1", "Erik Satie", Difficulty.INTERMEDIATE, isFavorite = false),
            SamplePiece("moonlight-sonata-1", "Moonlight Sonata (Op. 27 No. 2)", "Ludwig van Beethoven", Difficulty.ADVANCED, isFavorite = true),
        )
    }
}
