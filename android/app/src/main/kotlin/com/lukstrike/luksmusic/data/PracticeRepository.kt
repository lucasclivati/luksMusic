// PracticeRepository.kt — the practice history (Progresso tab), one JSON file.
package com.lukstrike.luksmusic.data

import android.content.Context
import com.lukstrike.luksmusic.core.model.PracticeSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import java.io.File

class PracticeRepository(context: Context) {

    private val file = File(context.filesDir, "practice-sessions.json")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mutex = Mutex()
    private val serializer = ListSerializer(PracticeSession.serializer())

    private val _sessions = MutableStateFlow<List<PracticeSession>>(emptyList())
    /** Most recent first. */
    val sessions: StateFlow<List<PracticeSession>> = _sessions

    init {
        scope.launch {
            _sessions.value = runCatching { ScoreRepository.json.decodeFromString(serializer, file.readText()) }
                .getOrDefault(emptyList()).sortedByDescending { it.startTime }
        }
    }

    /** Adds or replaces [session] (same id). */
    suspend fun save(session: PracticeSession) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val list = (_sessions.value.filterNot { it.id == session.id } + session).sortedByDescending { it.startTime }
            file.writeText(ScoreRepository.json.encodeToString(serializer, list))
            _sessions.value = list
        }
    }

    suspend fun deleteAll() = withContext(Dispatchers.IO) {
        mutex.withLock { file.delete(); _sessions.value = emptyList() }
    }
}
