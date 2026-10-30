// ScoreWebView.swift
// luksMusic
//
// Engraved score rendered by OpenSheetMusicDisplay (bundled in ScoreViewer/) inside a WKWebView.
// OSMD's note-by-note cursor follows the native player, and taps on the score seek to the tapped note.

import SwiftUI
import WebKit

struct ScoreWebView: UIViewRepresentable {
    let musicXML: String
    let measureIndex: Int
    let cursorBeat: Double
    var zoom: Double = 1.0
    var transposition: Int = 0
    var horizontal: Bool = false
    var topInset: CGFloat = 64
    var bottomInset: CGFloat = 160
    var onSeek: (Int, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(WeakScriptMessageHandler(context.coordinator), name: "luks")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "score-viewer", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSeek = onSeek
        context.coordinator.apply([
            "xml": musicXML,
            "measure": measureIndex,
            "beat": cursorBeat,
            "zoom": zoom,
            "transpose": transposition,
            "mode": horizontal ? "singleLine" : "portraitView",
            "topInset": Double(topInset),
            "bottomInset": Double(bottomInset)
        ])
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "luks")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onSeek: ((Int, Double) -> Void)?

        private var pageLoaded = false
        private var pending: [String: Any] = [:]
        private var sentXML: String?
        private var sentStateJSON: String?

        func apply(_ state: [String: Any]) {
            pending = state
            if pageLoaded {
                flush()
            }
        }

        /// Sends the state to the page, skipping unchanged updates; the MusicXML only goes when it changes.
        private func flush() {
            guard let webView else { return }
            var state = pending
            let xml = state.removeValue(forKey: "xml") as? String
            guard let stateJSON = Self.json(state) else { return }
            let xmlChanged = xml != nil && xml != sentXML
            if !xmlChanged && stateJSON == sentStateJSON { return }
            if xmlChanged {
                state["xml"] = xml
            }
            guard let payload = Self.json(state) else { return }
            webView.evaluateJavaScript("luks.update(\(payload));", completionHandler: nil)
            sentStateJSON = stateJSON
            if xmlChanged {
                sentXML = xml
            }
        }

        private static func json(_ object: [String: Any]) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true
            flush()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], body["type"] as? String == "seek",
                  let measure = body["measure"] as? Int,
                  let beat = body["beat"] as? Double else { return }
            onSeek?(measure, beat)
        }
    }
}

/// Forwards script messages without WKUserContentController holding the coordinator strongly.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
