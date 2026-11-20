// ScoreRepository.kt — the score library on the device (the iOS app keeps it in SwiftData). Each score is a JSON
// file in files/scores/, with its original MusicXML beside it, so the list loads fast and the viewer gets the file
// exactly as it was read.
package com.lukstrike.luksmusic.data

import android.content.Context
import com.lukstrike.luksmusic.core.model.Score
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.File

class ScoreRepository(context: Context) {

    private val dir = File(context.filesDir, "scores").apply { mkdirs() }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mutex = Mutex()

    private val _scores = MutableStateFlow<List<Score>>(emptyList())
    /** Every score, most recently modified first. */
    val scores: StateFlow<List<Score>> = _scores

    private val _isLoaded = MutableStateFlow(false)
    val isLoaded: StateFlow<Boolean> = _isLoaded

    init {
        scope.launch {
            val loaded = dir.listFiles { f -> f.extension == "json" }.orEmpty().mapNotNull { file ->
                runCatching { json.decodeFromString(Score.serializer(), file.readText()) }.getOrNull()
            }
            _scores.value = loaded.sortedByDescending { it.lastModified }
            _isLoaded.value = true
        }
    }

    fun get(id: String): Score? = _scores.value.firstOrNull { it.id == id }

    /** Saves [score]. A non-null [musicXml] is stored beside it; editing the notes should pass `hasMusicXml = false`. */
    suspend fun save(score: Score, musicXml: String? = null) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val stored = if (musicXml != null) score.copy(hasMusicXml = true) else score
            if (musicXml != null) xmlFile(score.id).writeText(musicXml)
            if (!stored.hasMusicXml) xmlFile(score.id).delete()
            val tmp = File(dir, "${score.id}.json.tmp")
            tmp.writeText(json.encodeToString(Score.serializer(), stored))
            tmp.renameTo(jsonFile(score.id)) || run { jsonFile(score.id).delete(); tmp.renameTo(jsonFile(score.id)) }
            _scores.update { list -> (list.filterNot { it.id == score.id } + stored).sortedByDescending { it.lastModified } }
        }
    }

    /** Applies [change] to the stored score, if any. */
    suspend fun update(id: String, change: (Score) -> Score) {
        val current = get(id) ?: return
        save(change(current))
    }

    suspend fun delete(id: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            jsonFile(id).delete()
            xmlFile(id).delete()
            _scores.update { list -> list.filterNot { it.id == id } }
        }
    }

    /** The MusicXML the score was read from, or null when it was made or edited in the app. */
    suspend fun musicXml(id: String): String? = withContext(Dispatchers.IO) {
        xmlFile(id).takeIf { it.exists() }?.readText()
    }

    private fun jsonFile(id: String) = File(dir, "$id.json")
    private fun xmlFile(id: String) = File(dir, "$id.musicxml")

    companion object {
        val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }
    }
}
