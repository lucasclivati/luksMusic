// SiteScriptEvaluator.kt — runs one of luksmusic.web.app's data scripts and returns the globals it sets.
//
// The site's catalog (scores/catalog.js) and note data (SCORE_DATA) are JavaScript, not JSON: they assign
// `window.NAME = [...]` and build parts of it with code (`[1, 2].map(n => ...)`, `Array.from(...)`), so a JSON
// parser cannot read them. iOS evaluates them with JavaScriptCore. Android has no JavaScript engine in the
// framework apart from the WebView, so a headless WebView runs them: the same V8 engine as Chrome, always present,
// updated by the Play Store, and nothing to bundle. It is sandboxed: no network, no file access, no bridge to the
// app; it only hands back `JSON.stringify` of the requested globals, which kotlinx.serialization then reads.
package com.lukstrike.luksmusic.feature.library

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlin.coroutines.resume

object SiteScriptEvaluator {

    class ScriptException : Exception("The site's script could not be run")

    /**
     * Runs [script] and returns the globals [names] it set (`window.NAME`) as JSON values; a name the script did not
     * set is left out. Throws [ScriptException] when the script fails.
     */
    @SuppressLint("SetJavaScriptEnabled")
    suspend fun evaluate(context: Context, script: String, names: List<String>): JsonObject = withContext(Dispatchers.Main) {
        val webView = WebView(context.applicationContext)
        try {
            webView.settings.apply {
                javaScriptEnabled = true
                blockNetworkLoads = true
                allowFileAccess = false
                allowContentAccess = false
            }
            withTimeoutOrNull(30_000) {
                // A blank page first, so the script runs in a page of its own
                suspendCancellableCoroutine { continuation ->
                    webView.webViewClient = object : WebViewClient() {
                        override fun onPageFinished(view: WebView?, url: String?) {
                            if (continuation.isActive) continuation.resume(Unit)
                        }
                    }
                    webView.loadDataWithBaseURL(null, "<html><body></body></html>", "text/html", "utf-8", null)
                }
                // Wrapped in a function so a failure comes back as null instead of an exception nobody sees; the
                // script's `window.NAME =` assignments still reach the page's window.
                val reads = names.joinToString(",") { "\"$it\": (typeof window.$it === 'undefined' ? undefined : window.$it)" }
                val wrapped = "(function(){try{\n$script\n;return JSON.stringify({$reads});}catch(e){return null;}})()"
                val result = suspendCancellableCoroutine { continuation ->
                    webView.evaluateJavascript(wrapped) { if (continuation.isActive) continuation.resume(it) }
                }
                // evaluateJavascript hands back the value as JSON: here a JSON string holding the stringified globals
                val text = (Json.parseToJsonElement(result ?: "null") as? JsonPrimitive)?.takeIf { it !is JsonNull }?.contentOrNull
                    ?: throw ScriptException()
                Json.parseToJsonElement(text) as? JsonObject ?: throw ScriptException()
            } ?: throw ScriptException()
        } finally {
            webView.stopLoading()
            webView.destroy()
        }
    }
}
