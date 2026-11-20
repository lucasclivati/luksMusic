// OnlineLibraryService.kt — port of luksMusic/Services/Storage/OnlineLibraryService.swift: the catalog of the
// luksMusic web player (luksmusic.web.app). Reads it, keeps the scores this account may open (the web's rules:
// public, the author, or an e-mail invite) and downloads a score on request into the library, where it is a score
// like any imported one: engraved, played and practiced on the phone, offline from then on. Nothing from the
// catalog is bundled in the app.
package com.lukstrike.luksmusic.feature.library

import android.content.Context
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.account.AuthProvider
import com.lukstrike.luksmusic.account.FirebaseConfig
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.Score
import com.lukstrike.luksmusic.core.musicxml.CatalogScoreData
import com.lukstrike.luksmusic.core.musicxml.MusicXMLParser
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** One score of the web catalog. */
data class OnlineScore(
    val id: String,
    /** The site's sidebar title: "Dark Dream – Curley Gao" */
    val title: String,
    val credits: String,
    val bpm: Int,
    val beatsPerMeasure: Int,
    /** The MusicXML (.mxl) among the score's downloads, when the catalog lists one */
    val musicXmlUrl: HttpUrl?,
    /** The web player's note data (SCORE_DATA), read when there is no MusicXML */
    val dataUrl: HttpUrl?,
    /** The difficulty named in the catalog's tags ("Advanced"), when there is one */
    val difficulty: Difficulty?,
    val defaultPrivacy: String,
    val isPrivate: Boolean = false,
) {
    /** The title without the composer: "Dark Dream" */
    val pieceTitle: String get() = title.split(" – ")[0]

    /** The composer after the title, or "" when the title names none: "Curley Gao" */
    val composer: String get() = title.split(" – ").drop(1).joinToString(" – ")
}

/** A catalog score being downloaded. */
data class CatalogDownload(
    /** Part of the file received, null while its size is unknown */
    val fraction: Float? = null,
)

/** What went wrong reading the site. */
class OnlineLibraryException(val reason: Reason) : Exception(reason.name) {
    enum class Reason { CONNECTION, NOT_FOUND, UNREADABLE }

    val text: LibraryText
        get() = LibraryText(
            when (reason) {
                Reason.CONNECTION -> R.string.library_catalog_error_connection
                Reason.NOT_FOUND -> R.string.library_catalog_error_not_found
                Reason.UNREADABLE -> R.string.library_catalog_error_unreadable
            }
        )
}

class OnlineLibraryService private constructor(private val context: Context) {

    private val container get() = context.appContainer
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val http = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val _scores = MutableStateFlow<List<OnlineScore>>(emptyList())
    val scores: StateFlow<List<OnlineScore>> = _scores

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<LibraryText?>(null)
    val errorMessage: StateFlow<LibraryText?> = _errorMessage

    /** Catalog scores being downloaded, by catalog id */
    private val _downloads = MutableStateFlow<Map<String, CatalogDownload>>(emptyMap())
    val downloads: StateFlow<Map<String, CatalogDownload>> = _downloads

    /** The account `scores` was checked for, so another account never sees the previous one's private scores */
    private var loadedAccount: String? = null

    /** The download of each catalog score in progress, so a second request waits for it instead of saving a copy */
    private val downloadTasks = mutableMapOf<String, CompletableDeferred<Unit>>()

    /** Who the private scores are checked for: the signed-in e-mail, or "guest". */
    val account: String
        get() {
            val user = container.auth.currentUser.value
            if (user == null || user.authProvider == AuthProvider.GUEST || user.email.isEmpty()) return GUEST
            return user.email.lowercase()
        }

    /** Loads the catalog the first time and again whenever the account changes (sign-in, sign-out, deletion). */
    suspend fun refreshIfNeeded() {
        if (_scores.value.isNotEmpty() && loadedAccount == account) return
        if (loadedAccount != account) _scores.update { list -> list.filterNot { it.isPrivate } }
        refresh()
    }

    /** Reloads the catalog and keeps the scores this account can open. */
    suspend fun refresh() = withContext(Dispatchers.Main.immediate) {
        val account = account
        _isLoading.value = true
        _errorMessage.value = null
        try {
            val script = fetch(SITE_URL.resolve("scores/catalog.js")!!).toString(Charsets.UTF_8)
            val globals = runScript(script, "SCORE_CATALOG")
            val entries = (globals["SCORE_CATALOG"] as? JsonArray).orEmpty().mapNotNull { it as? JsonObject }
            val candidates = entries.mapNotNull(::score)
            // Check every score at once, keeping the catalog's order
            val allowed = coroutineScope { candidates.map { async { checked(it) } }.awaitAll() }.filterNotNull()
            // The account changed while checking: the reload started for the new one keeps its own list
            if (account != this@OnlineLibraryService.account) return@withContext
            _scores.value = allowed
            loadedAccount = account
        } catch (e: OnlineLibraryException) {
            _errorMessage.value = LibraryText(R.string.library_catalog_load_failed, e.text)
        } finally {
            _isLoading.value = false
        }
    }

    // region Downloading

    /** The phone's copy of a catalog score, or null when it was not downloaded yet. */
    fun localCopy(entry: OnlineScore): Score? = container.scores.scores.value.firstOrNull { it.catalogId == entry.id }

    /** The phone's copy of a catalog score, downloaded and saved in the library first when it is not there yet. The
     *  download goes on when the screen that asked for it closes. Throws [OnlineLibraryException]. */
    suspend fun download(entry: OnlineScore): Score = withContext(Dispatchers.Main.immediate) {
        localCopy(entry)?.let { return@withContext it }
        val running = downloadTasks[entry.id] ?: CompletableDeferred<Unit>().also { task ->
            downloadTasks[entry.id] = task
            _downloads.update { it + (entry.id to CatalogDownload()) }
            scope.launch {
                try {
                    save(entry)
                    task.complete(Unit)
                } catch (e: Throwable) {
                    task.completeExceptionally(e)
                } finally {
                    downloadTasks.remove(entry.id)
                    _downloads.update { it - entry.id }
                }
            }
        }
        running.await()
        localCopy(entry) ?: throw OnlineLibraryException(OnlineLibraryException.Reason.UNREADABLE)
    }

    /** Downloads a catalog score and saves it in the library: read from its MusicXML when the catalog lists one,
     *  else built from the web player's note data. */
    private suspend fun save(entry: OnlineScore) {
        val progress: (Float) -> Unit = { fraction ->
            _downloads.update { map -> if (entry.id in map) map + (entry.id to CatalogDownload(fraction)) else map }
        }
        val score: Score
        var musicXml: String? = null
        val musicXmlUrl = entry.musicXmlUrl
        val dataUrl = entry.dataUrl
        if (musicXmlUrl != null) {
            val data = fetch(musicXmlUrl, progress)
            val parsed = withContext(Dispatchers.Default) {
                try {
                    MusicXMLParser.parse(data)
                } catch (e: Exception) {
                    throw OnlineLibraryException(OnlineLibraryException.Reason.UNREADABLE)
                }
            }
            score = parsed.score
            musicXml = parsed.musicXml
        } else if (dataUrl != null) {
            val script = fetch(dataUrl, progress).toString(Charsets.UTF_8)
            val data = runScript(script, "SCORE_DATA")["SCORE_DATA"] as? JsonArray
            if (data.isNullOrEmpty()) throw OnlineLibraryException(OnlineLibraryException.Reason.UNREADABLE)
            score = withContext(Dispatchers.Default) {
                CatalogScoreData.playableScore(data, entry.pieceTitle, entry.composer, entry.difficulty, entry.bpm, entry.beatsPerMeasure)
            }
        } else {
            throw OnlineLibraryException(OnlineLibraryException.Reason.NOT_FOUND)
        }
        // The catalog's names, as on its card, over whatever the file calls itself
        val named = score.copy(
            title = entry.pieceTitle,
            composer = entry.composer,
            difficulty = entry.difficulty ?: score.difficulty,
            catalogId = entry.id,
        )
        container.scores.save(named, musicXml)
    }

    // endregion

    // region Access

    /** The score with its current visibility, or null when this account may not open it. */
    private suspend fun checked(candidate: OnlineScore): OnlineScore? {
        val privacy = privacySetting(candidate.id) ?: candidate.defaultPrivacy
        val score = candidate.copy(isPrivate = privacy != "public")
        if (score.isPrivate && !isAllowedPrivate(score)) return null
        return score
    }

    /** The visibility the author chose on the web (`scoreSettings/{id}`), or null when they never changed it. */
    private suspend fun privacySetting(scoreId: String): String? = runCatching {
        val url = FirebaseConfig.FIRESTORE_DOCUMENTS_URL.toHttpUrl().newBuilder()
            .addPathSegment("scoreSettings").addPathSegment(scoreId)
            .addQueryParameter("key", FirebaseConfig.API_KEY)
            .build()
        val body = execute(Request.Builder().url(url).build()) { response ->
            if (response.code == 200) response.body?.string() else null
        } ?: return@runCatching null
        val fields = Json.parseToJsonElement(body).jsonObject["fields"] as? JsonObject
        ((fields?.get("privacy") as? JsonObject)?.get("stringValue") as? JsonPrimitive)?.contentOrNull
    }.getOrNull()

    /** Private scores open for the author and for e-mails the author invited (`scoreShares/{id}/members/{email}`). */
    private suspend fun isAllowedPrivate(score: OnlineScore): Boolean {
        val user = container.auth.currentUser.value
        if (user == null || user.authProvider == AuthProvider.GUEST || user.email.isEmpty()) return false
        val email = user.email.lowercase()
        if (email == AUTHOR_EMAIL) return true
        return runCatching {
            val idToken = container.auth.freshIdToken()
            val url = FirebaseConfig.FIRESTORE_DOCUMENTS_URL.toHttpUrl().newBuilder()
                .addPathSegment("scoreShares").addPathSegment(score.id)
                .addPathSegment("members").addPathSegment(email)
                .build()
            val request = Request.Builder().url(url).header("Authorization", "Bearer $idToken").build()
            execute(request) { it.code == 200 }
        }.getOrDefault(false)
    }

    // endregion

    // region Site files

    /** Downloads a file of the site off the main thread, reporting the part received when the server gives its size. */
    private suspend fun fetch(url: HttpUrl, progress: (Float) -> Unit = {}): ByteArray = withContext(Dispatchers.IO) {
        try {
            execute(Request.Builder().url(url).build()) { response ->
                if (response.code != 200) throw OnlineLibraryException(OnlineLibraryException.Reason.NOT_FOUND)
                val body = response.body ?: throw OnlineLibraryException(OnlineLibraryException.Reason.NOT_FOUND)
                val expected = body.contentLength()
                val out = ByteArrayOutputStream(if (expected > 0) expected.toInt() else 64 * 1024)
                val buffer = ByteArray(8192)
                var lastReported = 0L
                body.byteStream().use { input ->
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        out.write(buffer, 0, n)
                        if (expected > 0 && out.size() - lastReported >= 8192) {
                            lastReported = out.size().toLong()
                            // A compressed transfer can count fewer bytes than arrive
                            val fraction = minOf(1f, out.size().toFloat() / expected)
                            scope.launch { progress(fraction) }
                        }
                    }
                }
                out.toByteArray()
            }
        } catch (e: OnlineLibraryException) {
            throw e
        } catch (e: IOException) {
            throw OnlineLibraryException(OnlineLibraryException.Reason.CONNECTION)
        }
    }

    /** Runs one of the site's data scripts (they assign `window.NAME = ...`) and returns that global as JSON. */
    private suspend fun runScript(script: String, name: String): JsonObject = try {
        SiteScriptEvaluator.evaluate(context, script, listOf(name))
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        // The script failed, its data was not JSON, or the WebView itself is missing or being updated
        throw OnlineLibraryException(OnlineLibraryException.Reason.UNREADABLE)
    }

    /** Runs [request] on OkHttp's threads, cancelled with the coroutine, and reads the response with [read]. */
    private suspend fun <T> execute(request: Request, read: (Response) -> T): T = suspendCancellableCoroutine { continuation ->
        val call = http.newCall(request)
        // Cancelling the call also stops a body being read: its stream then throws
        continuation.invokeOnCancellation { call.cancel() }
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (continuation.isActive) continuation.resumeWithException(e)
            }

            override fun onResponse(call: Call, response: Response) {
                val result = runCatching { response.use(read) }
                if (continuation.isActive) {
                    result.fold(continuation::resume, continuation::resumeWithException)
                }
            }
        })
    }

    // endregion

    companion object {
        val SITE_URL: HttpUrl = "https://luksmusic.web.app/".toHttpUrl()

        /** The web player's author, who also sees private scores (same account as the Firestore rules). */
        private const val AUTHOR_EMAIL = "lukscli@gmail.com"
        private const val GUEST = "guest"

        @Volatile private var instance: OnlineLibraryService? = null

        /** The one catalog of the app (the iOS `.shared`), so downloads and the list outlive any screen. */
        fun get(context: Context): OnlineLibraryService =
            instance ?: synchronized(this) {
                instance ?: OnlineLibraryService(context.applicationContext).also { instance = it }
            }

        private fun JsonObject.string(key: String): String? = (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
        private fun JsonObject.int(key: String): Int? = (this[key] as? JsonPrimitive)?.takeIf { !it.isString }?.intOrNull

        /** One catalog entry, or null when it has no id or nothing the phone can read. */
        private fun score(entry: JsonObject): OnlineScore? {
            val id = entry.string("id") ?: return null
            val files = (entry["downloads"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonObject)?.string("href") }
            val musicXml = files.firstOrNull { href -> listOf(".mxl", ".musicxml", ".xml").any { href.lowercase().endsWith(it) } }
            val musicXmlUrl = musicXml?.let(SITE_URL::resolve)
            val dataUrl = entry.string("data")?.let(SITE_URL::resolve)
            if (musicXmlUrl == null && dataUrl == null) return null
            val tags = (entry["tags"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
            return OnlineScore(
                id = id,
                title = entry.string("sidebarTitle") ?: entry.string("title") ?: id,
                credits = entry.string("credits") ?: "",
                bpm = entry.int("bpm") ?: 80,
                beatsPerMeasure = entry.int("beatsPerMeasure") ?: 4,
                musicXmlUrl = musicXmlUrl,
                dataUrl = dataUrl,
                // The catalog names difficulties as the library stores them ("Advanced")
                difficulty = tags.firstNotNullOfOrNull { tag -> difficultyByRaw[tag] },
                defaultPrivacy = entry.string("defaultPrivacy") ?: "public",
            )
        }

        private val difficultyByRaw = mapOf(
            "Beginner" to Difficulty.BEGINNER, "Intermediate" to Difficulty.INTERMEDIATE,
            "Advanced" to Difficulty.ADVANCED, "Expert" to Difficulty.EXPERT,
        )
    }
}
