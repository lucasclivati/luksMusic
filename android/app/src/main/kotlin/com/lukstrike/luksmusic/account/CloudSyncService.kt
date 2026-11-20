// CloudSyncService.kt — uploads the score library to Firestore over REST (iOS Services/Storage/CloudSyncService.swift)
// and deletes it when the account is deleted. Documents live at users/{uid}/scores/{scoreId} with the same fields the
// iOS app writes, so both apps share one backup. As on iOS, only the score's summary is uploaded (no notes, no
// MusicXML). Reach it with `appContainer().auth.cloudSync`.
package com.lukstrike.luksmusic.account

import android.content.Context
import androidx.datastore.preferences.core.longPreferencesKey
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.model.Difficulty
import com.lukstrike.luksmusic.core.model.Score
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import okhttp3.HttpUrl.Companion.toHttpUrl
import kotlin.coroutines.cancellation.CancellationException

class CloudSyncService internal constructor(private val context: Context, private val auth: AuthRepository) {

    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing

    private val _lastSyncDate = MutableStateFlow<Long?>(null)
    /** Epoch ms of the last successful sync, kept across launches. */
    val lastSyncDate: StateFlow<Long?> = _lastSyncDate

    private val _syncError = MutableStateFlow<AccountMessage?>(null)
    val syncError: StateFlow<AccountMessage?> = _syncError

    private val _uploadedCount = MutableStateFlow(0)
    val uploadedCount: StateFlow<Int> = _uploadedCount

    private val settings get() = context.appContainer.settings
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    init {
        scope.launch { _lastSyncDate.value = settings.get(LAST_SYNC_KEY, 0L).takeIf { it > 0 } }
    }

    // region Synchronize local scores with Firebase

    /** Uploads every score in [scores] to the signed-in user's Firestore library. */
    suspend fun syncLibrary(scores: List<Score>) {
        val user = auth.currentUser.value
        if (user == null || user.authProvider == AuthProvider.GUEST) {
            _syncError.value = AccountMessage.Res(R.string.account_sync_error_sign_in)
            return
        }
        if (_isSyncing.value) return

        _isSyncing.value = true
        _syncError.value = null
        try {
            val idToken = auth.freshIdToken()
            var count = 0
            // The bundled sample pieces come with every install: nothing to keep in the cloud
            for (score in scores.filterNot { it.isSample }) {
                uploadScore(score, user.uid, idToken)
                count += 1
            }
            _uploadedCount.value = count
            val now = System.currentTimeMillis()
            _lastSyncDate.value = now
            settings.set(LAST_SYNC_KEY, now)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            _syncError.value = AccountMessage.res(R.string.account_sync_error, AccountMessage.describe(e))
        } finally {
            _isSyncing.value = false
        }
    }

    private suspend fun uploadScore(score: Score, userId: String, idToken: String) {
        val url = "${FirebaseConfig.FIRESTORE_DOCUMENTS_URL}/users/$userId/scores/${score.id}".toHttpUrl()
            .newBuilder().addQueryParameter("key", FirebaseConfig.API_KEY).build()
        // PATCH without an update mask replaces the whole document, as on iOS
        val fields = FirebaseRest.toJson(
            mapOf(
                "fields" to mapOf(
                    "title" to mapOf("stringValue" to score.title),
                    "composer" to mapOf("stringValue" to score.composer),
                    "difficulty" to mapOf("stringValue" to score.difficulty.rawValue),
                    "tempo" to mapOf("integerValue" to score.tempo.toString()),
                    "userId" to mapOf("stringValue" to userId),
                    "measuresCount" to mapOf("integerValue" to score.measureCount.toString()),
                )
            )
        ) as JsonObject
        val response = FirebaseRest.firestore(url, "PATCH", idToken, fields)
        if (!response.isSuccessful) throw AccountException(FirebaseRest.failureText(response))
    }

    // endregion
    // region Account deletion

    /** Deletes every score the user synced to Firestore, then the user document itself. */
    suspend fun deleteRemoteData(userId: String, idToken: String) {
        val documentsUrl = FirebaseConfig.FIRESTORE_DOCUMENTS_URL
        var pageToken: String? = null
        do {
            val listUrl = "$documentsUrl/users/$userId/scores".toHttpUrl().newBuilder()
                .addQueryParameter("pageSize", "300")
                .addQueryParameter("mask.fieldPaths", "title")
                .apply { pageToken?.let { addQueryParameter("pageToken", it) } }
                .build()
            val page = firestoreRequest(listUrl.toString(), "GET", idToken)
            for (document in (page["documents"] as? JsonArray).orEmpty()) {
                val name = (document as? JsonObject)?.string("name") ?: continue
                firestoreRequest("${FirebaseConfig.FIRESTORE_URL}/$name", "DELETE", idToken)
            }
            pageToken = page.string("nextPageToken")
        } while (pageToken != null)

        firestoreRequest("$documentsUrl/users/$userId", "DELETE", idToken)
    }

    fun resetSyncState() {
        _lastSyncDate.value = null
        _uploadedCount.value = 0
        _syncError.value = null
        scope.launch { settings.set(LAST_SYNC_KEY, null) }
    }

    private suspend fun firestoreRequest(url: String, method: String, idToken: String): JsonObject {
        val response = FirebaseRest.firestore(url.toHttpUrl(), method, idToken)
        if (!response.isSuccessful) {
            throw AccountException(
                AccountMessage.res(R.string.account_delete_cloud_error, FirebaseRest.failureText(response))
            )
        }
        return response.json
    }

    // endregion

    private companion object {
        val LAST_SYNC_KEY = longPreferencesKey("cloudSync.lastSync")
    }
}

/** The value iOS stores and uploads ("Beginner", "Intermediate", …), the enum's serial name. */
private val Difficulty.rawValue: String get() = Difficulty.serializer().descriptor.getElementName(ordinal)
