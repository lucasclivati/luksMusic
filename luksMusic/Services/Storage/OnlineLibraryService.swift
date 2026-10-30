// OnlineLibraryService.swift
// luksMusic
//
// Scores published on the luksMusic web player (luksmusic.web.app). Reads its catalog, keeps the scores this
// account may open (the web's rules: public, the author, or an e-mail invite) and loads a score's engraved
// pages and note data on demand. Nothing from the catalog is bundled in the app.

import Foundation
import JavaScriptCore
import Observation

/// One score of the web catalog.
struct OnlineScore: Identifiable, Hashable {
    let id: String
    let title: String
    let credits: String
    let bpm: Int
    let beatsPerMeasure: Int
    let pageURLs: [URL]
    let dataURL: URL
    let defaultPrivacy: String
    var isPrivate: Bool = false
}

/// What the page viewer and the player need for one score.
struct OnlineScoreContent {
    /// MEASURE_LAYOUT: where each played measure sits on the pages
    let layout: [[String: Any]]
    /// NOTE_COLUMNS: notehead x (percent of the page) of every onset, by measure number
    let columns: [String: Any]
    /// SCORE_DATA converted to the app's model, for playback and the keyboard
    let measures: [Measure]
}

@MainActor
@Observable
final class OnlineLibraryService {

    static let shared = OnlineLibraryService()
    static let siteURL = URL(string: "https://luksmusic.web.app/")!

    /// The web player's author, who also sees private scores (same account as the Firestore rules).
    private static let authorEmail = "lukscli@gmail.com"

    var scores: [OnlineScore] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let authService = AuthService.shared

    private init() {}

    /// Reloads the catalog and keeps the scores this account can open.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let globals = try await Self.evaluate(scriptAt: URL(string: "scores/catalog.js", relativeTo: Self.siteURL)!, names: ["SCORE_CATALOG"])
            let entries = globals["SCORE_CATALOG"] as? [[String: Any]] ?? []
            var visible: [OnlineScore] = []
            for var score in entries.compactMap(Self.score(from:)) {
                let privacy = (await privacySetting(for: score.id)) ?? score.defaultPrivacy
                score.isPrivate = privacy != "public"
                if !score.isPrivate {
                    visible.append(score)
                } else if await isAllowedPrivate(score) {
                    visible.append(score)
                }
            }
            scores = visible
        } catch {
            errorMessage = "Não foi possível carregar a biblioteca online: \(error.localizedDescription)"
        }
    }

    /// Downloads a score's layout, note columns and notes.
    func loadContent(for score: OnlineScore) async throws -> OnlineScoreContent {
        let globals = try await Self.evaluate(scriptAt: score.dataURL, names: ["SCORE_DATA", "MEASURE_LAYOUT", "NOTE_COLUMNS"])
        guard let data = globals["SCORE_DATA"] as? [[String: Any]],
              let layout = globals["MEASURE_LAYOUT"] as? [[String: Any]],
              let columns = globals["NOTE_COLUMNS"] as? [String: Any] else {
            throw NSError(domain: "luksMusic", code: 422, userInfo: [NSLocalizedDescriptionKey: "Os dados desta partitura estão incompletos."])
        }
        return OnlineScoreContent(layout: layout, columns: columns, measures: data.map(Self.measure(from:)))
    }

    // MARK: - Access

    /// The visibility the author chose on the web (`scoreSettings/{id}`), or nil when they never changed it.
    private func privacySetting(for scoreId: String) async -> String? {
        guard let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/scoreSettings/\(scoreId)?key=\(FirebaseConfig.apiKey)"),
              let result = try? await URLSession.shared.data(from: url),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let fields = json["fields"] as? [String: Any],
              let privacy = (fields["privacy"] as? [String: Any])?["stringValue"] as? String else { return nil }
        return privacy
    }

    /// Private scores open for the author and for e-mails the author invited (`scoreShares/{id}/members/{email}`).
    private func isAllowedPrivate(_ score: OnlineScore) async -> Bool {
        guard let user = authService.currentUser, user.authProvider != .guest, !user.email.isEmpty else { return false }
        let email = user.email.lowercased()
        if email == Self.authorEmail {
            return true
        }
        guard let idToken = try? await authService.freshIdToken(),
              let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/scoreShares/\(score.id)/members/\(encodedEmail)") else { return false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        guard let result = try? await URLSession.shared.data(for: request) else { return false }
        return (result.1 as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Site Data Scripts

    /// Runs one of the site's data scripts (they assign `window.NAME = ...`) and returns those globals as JSON values.
    private static func evaluate(scriptAt url: URL, names: [String]) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let source = String(data: data, encoding: .utf8),
              let context = JSContext() else {
            throw NSError(domain: "luksMusic", code: 404, userInfo: [NSLocalizedDescriptionKey: "Arquivo não encontrado no site."])
        }
        context.evaluateScript("var window = this;")
        context.evaluateScript(source)
        if let exception = context.exception {
            throw NSError(domain: "luksMusic", code: 422, userInfo: [NSLocalizedDescriptionKey: exception.toString() ?? "Erro no script"])
        }
        var globals: [String: Any] = [:]
        for name in names {
            guard let json = context.evaluateScript("JSON.stringify(window.\(name))")?.toString(), json != "undefined",
                  let value = try? JSONSerialization.jsonObject(with: Data(json.utf8)) else { continue }
            globals[name] = value
        }
        return globals
    }

    private static func score(from entry: [String: Any]) -> OnlineScore? {
        guard let id = entry["id"] as? String,
              let pages = entry["pages"] as? [String],
              let data = entry["data"] as? String,
              let dataURL = URL(string: data, relativeTo: siteURL) else { return nil }
        return OnlineScore(
            id: id,
            title: entry["sidebarTitle"] as? String ?? entry["title"] as? String ?? id,
            credits: entry["credits"] as? String ?? "",
            bpm: entry["bpm"] as? Int ?? 80,
            beatsPerMeasure: entry["beatsPerMeasure"] as? Int ?? 4,
            pageURLs: pages.compactMap { URL(string: $0, relativeTo: siteURL)?.absoluteURL },
            dataURL: dataURL.absoluteURL,
            defaultPrivacy: entry["defaultPrivacy"] as? String ?? "public"
        )
    }

    // MARK: - SCORE_DATA → Model

    /// One measure of SCORE_DATA: `{number, treble: [...], bass: [...]}`, each event a chord of MIDI notes at a beat.
    private static func measure(from entry: [String: Any]) -> Measure {
        var notes: [Note] = []
        for (key, staff) in [("treble", Staff.treble), ("bass", Staff.bass)] {
            for event in entry[key] as? [[String: Any]] ?? [] {
                guard let beat = (event["beat"] as? NSNumber)?.doubleValue else { continue }
                let (duration, isTriplet) = noteValue(of: event)
                let lyric = event["lyric"] as? String
                for (i, midi) in (event["chord"] as? [Int] ?? []).enumerated() {
                    notes.append(Note(
                        pitch: pitch(midi: midi),
                        duration: duration,
                        staff: staff,
                        lyric: i == 0 ? lyric : nil,
                        isTriplet: isTriplet,
                        position: NotePosition(beat: beat)
                    ))
                }
            }
        }
        return Measure(number: entry["number"] as? Int ?? 0, notes: notes)
    }

    /// Older data names the value (`dur`, `triplet`); newer data gives its length in beats (`len`).
    private static func noteValue(of event: [String: Any]) -> (NoteDuration, Bool) {
        let triplet = event["triplet"] as? Bool ?? false
        switch event["dur"] as? String {
        case "whole": return (.whole, triplet)
        case "dottedHalf": return (.dottedHalf, triplet)
        case "half": return (.half, triplet)
        case "dottedQuarter": return (.dottedQuarter, triplet)
        case "quarter": return (.quarter, triplet)
        case "dottedEighth": return (.dottedEighth, triplet)
        case "8th": return (.eighth, triplet)
        case "16th": return (.sixteenth, triplet)
        case "32nd": return (.thirtySecond, triplet)
        default: break
        }
        let length = (event["len"] as? NSNumber)?.doubleValue ?? 1.0
        var best: (NoteDuration, Bool) = (.quarter, false)
        var bestError = Double.infinity
        for duration in NoteDuration.allCases {
            for isTriplet in [false, true] {
                let error = abs(duration.beats * (isTriplet ? 2.0 / 3.0 : 1.0) - length)
                if error < bestError - 1e-9 {
                    bestError = error
                    best = (duration, isTriplet)
                }
            }
        }
        return best
    }

    private static func pitch(midi: Int) -> Pitch {
        let names: [(NoteName, Accidental)] = [
            (.C, .natural), (.C, .sharp), (.D, .natural), (.E, .flat), (.E, .natural), (.F, .natural),
            (.F, .sharp), (.G, .natural), (.A, .flat), (.A, .natural), (.B, .flat), (.B, .natural)
        ]
        let (name, accidental) = names[((midi % 12) + 12) % 12]
        return Pitch(noteName: name, octave: midi / 12 - 1, accidental: accidental)
    }
}
