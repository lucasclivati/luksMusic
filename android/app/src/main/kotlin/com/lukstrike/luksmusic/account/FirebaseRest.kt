// FirebaseRest.kt — the small HTTP layer the account services share: Firebase Auth (Identity Toolkit, Secure Token)
// and Firestore over REST with OkHttp, as the iOS app does with URLSession. Tokens never reach a log.
package com.lukstrike.luksmusic.account

import com.lukstrike.luksmusic.R
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.Call
import okhttp3.Callback
import okhttp3.FormBody
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** An HTTP answer: status and the parsed JSON body (empty when there was none or it was not JSON). */
internal class RestResponse(val code: Int, val body: String, val json: JsonObject) {
    val isSuccessful: Boolean get() = code in 200..299
    /** Firebase's `error.message` (an error code such as `EMAIL_EXISTS`). */
    val errorMessage: String? get() = (json["error"] as? JsonObject)?.string("message")
}

internal object FirebaseRest {

    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val jsonType = "application/json; charset=utf-8".toMediaType()

    fun identityToolkitUrl(path: String): HttpUrl =
        "${FirebaseConfig.IDENTITY_TOOLKIT_URL}/$path".toHttpUrl().newBuilder()
            .addQueryParameter("key", FirebaseConfig.API_KEY).build()

    /** POSTs [body] as JSON to Identity Toolkit and returns the JSON answer; throws with Firebase's error otherwise. */
    suspend fun postIdentityToolkit(path: String, body: Map<String, Any>): JsonObject {
        val response = postJson(identityToolkitUrl(path), body)
        if (!response.isSuccessful) throw AccountException(firebaseErrorMessage(response.errorMessage))
        return response.json
    }

    suspend fun postJson(url: HttpUrl, body: Map<String, Any>): RestResponse =
        execute(Request.Builder().url(url).post(toJson(body).toString().toRequestBody(jsonType)).build())

    suspend fun postForm(url: HttpUrl, fields: Map<String, String>): RestResponse {
        val form = FormBody.Builder().apply { fields.forEach { (k, v) -> add(k, v) } }.build()
        return execute(Request.Builder().url(url).post(form).build())
    }

    /** A Firestore call signed with the user's ID token. */
    suspend fun firestore(url: HttpUrl, method: String, idToken: String, body: JsonObject? = null): RestResponse {
        val requestBody = body?.toString()?.toRequestBody(jsonType)
        return execute(
            Request.Builder().url(url)
                .header("Authorization", "Bearer $idToken")
                .method(method, requestBody)
                .build()
        )
    }

    suspend fun execute(request: Request): RestResponse {
        val response = client.newCall(request).await()
        return response.use {
            val text = it.body?.string().orEmpty()
            val json = runCatching { Json.parseToJsonElement(text).jsonObject }.getOrDefault(JsonObject(emptyMap()))
            RestResponse(it.code, text, json)
        }
    }

    /** Converts maps, lists, strings, numbers and booleans to JSON. */
    fun toJson(value: Any?): JsonElement = when (value) {
        null -> kotlinx.serialization.json.JsonNull
        is JsonElement -> value
        is String -> JsonPrimitive(value)
        is Number -> JsonPrimitive(value)
        is Boolean -> JsonPrimitive(value)
        is Map<*, *> -> JsonObject(value.entries.associate { (k, v) -> k.toString() to toJson(v) })
        is List<*> -> kotlinx.serialization.json.JsonArray(value.map(::toJson))
        else -> JsonPrimitive(value.toString())
    }

    /** The text of a failed answer, for the "…: %s" messages (iOS shows the raw body here). */
    fun failureText(response: RestResponse): AccountMessage =
        response.errorMessage?.let(::firebaseErrorMessage)
            ?: response.body.takeIf { it.isNotBlank() }?.let { AccountMessage.Raw(it) }
            ?: AccountMessage.Res(R.string.account_error_unknown)
}

internal fun JsonObject.string(key: String): String? = (this[key] as? JsonPrimitive)?.contentOrNull

internal fun JsonElement.stringOrNull(): String? = runCatching { jsonPrimitive.contentOrNull }.getOrNull()

/** Runs the call without blocking a thread and cancels it with the coroutine. */
private suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
    continuation.invokeOnCancellation { runCatching { cancel() } }
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) {
            continuation.resume(response) { _, value, _ -> value.close() }
        }
        override fun onFailure(call: Call, e: IOException) {
            if (!continuation.isCancelled) continuation.resumeWithException(e)
        }
    })
}
