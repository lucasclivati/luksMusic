// ScoreWebView.kt — the engraved score, drawn by OpenSheetMusicDisplay (score-viewer.html, shared with iOS in
// luksMusic/ScoreViewer) inside a WebView (port of Views/Score/ScoreWebView.swift). The cursor follows the player,
// taps on the score seek to the tapped note. Used by the score player and the Modo Estudo strip.
//
// The page talks to iOS through `window.webkit.messageHandlers.luks.postMessage(...)` and is driven with
// `luks.update({...})`. The page is not changed for Android: a script injected before the page's own defines that
// iOS bridge on top of an Android web message listener, and the state goes through the same `luks.update`.
//
// PUBLIC API — the practice screen uses this composable; keep its signature stable (new params with defaults are fine).
package com.lukstrike.luksmusic.feature.player

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color as AndroidColor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewAssetLoader
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.lukstrike.luksmusic.core.model.ClefChoice
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import kotlinx.serialization.json.Json

@Composable
fun ScoreWebView(
    musicXml: String,
    measureIndex: Int,
    cursorBeat: Double,
    modifier: Modifier = Modifier,
    title: String = "",
    composer: String = "",
    zoom: Double = 1.0,
    transposition: Int = 0,
    rightClef: ClefChoice = ClefChoice.SCORE,
    leftClef: ClefChoice = ClefChoice.SCORE,
    automaticUsesAlto: Boolean = true,
    /** One long line scrolled sideways (practice strip) instead of pages. */
    horizontal: Boolean = false,
    /** Scales the single line to fill the height (practice strip) instead of using [zoom]. */
    fitsHeight: Boolean = false,
    /** Paper on the player's dark background; the practice strip stays white. */
    isDark: Boolean = false,
    topInset: Dp = 64.dp,
    bottomInset: Dp = 160.dp,
    /** (measureIndex, beat) of the note tapped. */
    onSeek: (Int, Double) -> Unit = { _, _ -> },
) {
    val currentOnSeek by rememberUpdatedState(onSeek)
    // One bridge per place in the composition: it outlives recompositions, so the page loads once
    val bridge = remember { ScoreViewerBridge { measure, beat -> currentOnSeek(measure, beat) } }

    AndroidView(
        modifier = modifier,
        factory = { context -> bridge.createWebView(context, isDark) },
        update = {
            bridge.apply(
                xml = musicXml,
                state = buildJsonObject {
                    put("title", title)
                    put("composer", composer)
                    put("measure", measureIndex)
                    put("beat", cursorBeat)
                    put("zoom", zoom)
                    put("transpose", transposition)
                    putJsonObject("clefs") {
                        put("right", rightClef.raw)
                        put("left", leftClef.raw)
                        put("alto", automaticUsesAlto)
                    }
                    put("mode", if (horizontal) "singleLine" else "portraitView")
                    put("fit", fitsHeight)
                    put("theme", if (isDark) "dark" else "light")
                    // CSS pixels are density-independent, like dp
                    put("topInset", topInset.value.toDouble())
                    put("bottomInset", bottomInset.value.toDouble())
                },
            )
        },
        onRelease = { bridge.release() },
    )
}

/** The dark player's background (score-viewer.html's `html.dark`, PlayerTheme.background). */
private val DarkBackground = PlayerTheme.background.toArgb()

/**
 * Owns the WebView and its state: loads the page once, sends `luks.update` only when something changed (the
 * MusicXML only when it changed, as it can be large), and turns the page's messages into seeks.
 */
private class ScoreViewerBridge(private val onSeek: (Int, Double) -> Unit) {

    private var webView: WebView? = null
    private var pageLoaded = false
    private var pendingXml: String? = null
    private var pendingState: JsonObject? = null
    private var sentXml: String? = null
    private var sentState: JsonObject? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @SuppressLint("SetJavaScriptEnabled")
    fun createWebView(context: Context, isDark: Boolean): WebView {
        val assetLoader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(context))
            .build()
        val webView = WebView(context).apply {
            // Stays hidden until the page has its state, so the dark player never flashes white
            alpha = 0f
            setBackgroundColor(if (isDark) DarkBackground else AndroidColor.WHITE)
            settings.javaScriptEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.setSupportZoom(false)
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_IF_CONTENT_SCROLLS
            // The engraving is thousands of unlabelled shapes: nothing for TalkBack
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                    assetLoader.shouldInterceptRequest(request.url)

                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                    request.url.host != ASSET_HOST // the page never navigates away

                override fun onPageFinished(view: WebView, url: String) {
                    if (!documentStartShim) view.evaluateJavascript(bridgeShim(isDark), null)
                    pageLoaded = true
                    flush()
                }
            }
        }
        installBridge(webView, isDark)
        this.webView = webView
        webView.loadUrl(PAGE_URL)
        return webView
    }

    /** Whether the iOS bridge is defined before the page's scripts run (WebView 87+ almost everywhere). */
    private var documentStartShim = false

    private fun installBridge(webView: WebView, isDark: Boolean) {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            WebViewCompat.addWebMessageListener(webView, ANDROID_OBJECT, setOf(ORIGIN)) {
                    _: WebView, message: WebMessageCompat, _: Uri, isMainFrame: Boolean, _: JavaScriptReplyProxy ->
                if (isMainFrame) message.data?.let(::onMessage)
            }
        } else {
            // Old WebView: a plain JavaScript interface (its calls arrive on a background thread)
            webView.addJavascriptInterface(object {
                @JavascriptInterface
                fun postMessage(json: String) {
                    mainHandler.post { onMessage(json) }
                }
            }, ANDROID_OBJECT)
        }
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(webView, bridgeShim(isDark), setOf(ORIGIN))
            documentStartShim = true
        }
    }

    fun apply(xml: String, state: JsonObject) {
        pendingXml = xml
        pendingState = state
        if (pageLoaded) flush()
    }

    /** Sends the state to the page, skipping unchanged updates; the MusicXML only goes when it changes. */
    private fun flush() {
        val webView = webView ?: return
        val state = pendingState ?: return
        val xml = pendingXml
        val xmlChanged = xml != null && xml != sentXml
        if (!xmlChanged && state == sentState) return
        val payload = if (xmlChanged) JsonObject(state + ("xml" to JsonPrimitive(xml))) else state
        webView.evaluateJavascript("luks.update(${Json.encodeToString(JsonObject.serializer(), payload)});") {
            // The first state is applied: show the page (its colors are right by now)
            if (webView.alpha < 1f) webView.animate().alpha(1f).setDuration(180).start()
        }
        sentState = state
        if (xmlChanged) sentXml = xml
    }

    private fun onMessage(json: String) {
        val body = runCatching { Json.parseToJsonElement(json).jsonObject }.getOrNull() ?: return
        if (body["type"]?.jsonPrimitive?.content != "seek") return
        val measure = runCatching { body["measure"]!!.jsonPrimitive.int }.getOrNull() ?: return
        val beat = runCatching { body["beat"]!!.jsonPrimitive.double }.getOrNull() ?: return
        onSeek(measure, beat)
    }

    fun release() {
        val webView = webView ?: return
        this.webView = null
        pageLoaded = false
        sentXml = null
        sentState = null
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            WebViewCompat.removeWebMessageListener(webView, ANDROID_OBJECT)
        }
        webView.stopLoading()
        webView.destroy()
    }

    companion object {
        private const val ASSET_HOST = "appassets.androidplatform.net"
        private const val ORIGIN = "https://$ASSET_HOST"
        private const val PAGE_URL = "$ORIGIN/assets/score-viewer.html"
        /** The object Android injects into the page; the shim below wraps it as iOS's message handler. */
        private const val ANDROID_OBJECT = "luksAndroid"

        /**
         * iOS's `window.webkit.messageHandlers.luks` on top of the Android object (messages go as JSON text). On the
         * dark player the page starts dark too, before `luks.update` sets its theme.
         */
        private fun bridgeShim(isDark: Boolean): String = """
            (function () {
              if (!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.luks)) {
                window.webkit = window.webkit || {};
                window.webkit.messageHandlers = window.webkit.messageHandlers || {};
                window.webkit.messageHandlers.luks = {
                  postMessage: function (message) {
                    var target = window.$ANDROID_OBJECT;
                    if (target) target.postMessage(JSON.stringify(message));
                  }
                };
              }
              ${if (isDark) DARK_START else ""}
            })();
        """.trimIndent()

        private const val DARK_START = """
              var dark = function () { document.documentElement.classList.add('dark'); };
              if (document.documentElement) dark(); else document.addEventListener('DOMContentLoaded', dark);
        """
    }
}
