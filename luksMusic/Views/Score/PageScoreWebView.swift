// PageScoreWebView.swift
// luksMusic
//
// A score's original engraved pages (from luksmusic.web.app) in a WKWebView, with the cursor on the notehead
// of the onset the native player reports. Taps on a note seek to it.

import SwiftUI
import WebKit

struct PageScoreWebView: UIViewRepresentable {
    let pageURLs: [URL]
    let content: OnlineScoreContent
    let beatsPerMeasure: Int
    let measureIndex: Int
    let cursorBeat: Double
    var topInset: CGFloat = 64
    var bottomInset: CGFloat = 160
    var onSeek: (Int, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(PageMessageForwarder(context.coordinator), name: "luks")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "page-viewer", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSeek = onSeek
        // Pages, layout and note columns go once; the position and insets on every change
        coordinator.score = [
            "pages": pageURLs.map(\.absoluteString),
            "layout": content.layout,
            "columns": content.columns,
            "beatsPerMeasure": beatsPerMeasure
        ]
        coordinator.position = [
            "measure": measureIndex,
            "beat": cursorBeat,
            "topInset": Double(topInset),
            "bottomInset": Double(bottomInset)
        ]
        coordinator.flush()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "luks")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onSeek: ((Int, Double) -> Void)?
        var score: [String: Any] = [:]
        var position: [String: Any] = [:]

        private var pageLoaded = false
        private var scoreSent = false
        private var sentPosition: String?

        func flush() {
            guard pageLoaded, let webView else { return }
            var update = position
            guard let positionJSON = Self.json(position) else { return }
            if !scoreSent {
                update.merge(score) { current, _ in current }
            } else if positionJSON == sentPosition {
                return
            }
            guard let payload = Self.json(update) else { return }
            webView.evaluateJavaScript("luks.update(\(payload));", completionHandler: nil)
            scoreSent = true
            sentPosition = positionJSON
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
private final class PageMessageForwarder: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
