// OnlineLibraryService.swift
// luksMusic
//
// The catalog of the luksMusic web player (luksmusic.web.app). Reads it, keeps the scores this account may open
// (the web's rules: public, the author, or an e-mail invite) and downloads a score on request into the library,
// where it is a score like any imported one: engraved, played and practiced on the phone, offline from then on.
// Nothing from the catalog is bundled in the app.

import Foundation
import JavaScriptCore
import Observation
import SwiftData

/// One score of the web catalog.
struct OnlineScore: Identifiable, Hashable {
    let id: String
    /// The site's sidebar title: "Dark Dream – Curley Gao"
    let title: String
    let credits: String
    let bpm: Int
    let beatsPerMeasure: Int
    /// The MusicXML (.mxl) among the score's downloads, when the catalog lists one
    let musicXMLURL: URL?
    /// The web player's note data (SCORE_DATA), read when there is no MusicXML
    let dataURL: URL?
    /// The difficulty named in the catalog's tags ("Advanced"), when there is one
    let difficulty: Difficulty?
    let defaultPrivacy: String
    var isPrivate: Bool = false

    /// The title without the composer: "Dark Dream"
    var pieceTitle: String {
        title.components(separatedBy: " – ")[0]
    }

    /// The composer after the title, or "" when the title names none: "Curley Gao"
    var composer: String {
        title.components(separatedBy: " – ").dropFirst().joined(separator: " – ")
    }
}

/// A catalog score being downloaded.
struct CatalogDownload: Equatable {
    /// Part of the file received, nil while its size is unknown
    var fraction: Double?
}

/// What went wrong reading the site.
enum OnlineLibraryError: LocalizedError {
    case connection
    case notFound
    case unreadable

    var errorDescription: String? {
        switch self {
        case .connection: return "Não foi possível conectar ao luksmusic.web.app. Verifique a internet e tente de novo."
        case .notFound: return "O arquivo não foi encontrado no site."
        case .unreadable: return "O arquivo da partitura não pôde ser lido."
        }
    }
}

@MainActor
@Observable
final class OnlineLibraryService {

    static let shared = OnlineLibraryService()
    nonisolated static let siteURL = URL(string: "https://luksmusic.web.app/")!

    /// The web player's author, who also sees private scores (same account as the Firestore rules).
    private static let authorEmail = "lukscli@gmail.com"

    var scores: [OnlineScore] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    /// Catalog scores being downloaded, by catalog id
    private(set) var downloads: [String: CatalogDownload] = [:]

    private let authService = AuthService.shared

    /// The account `scores` was checked for, so another account never sees the previous one's private scores
    private var loadedAccount: String?

    /// The download of each catalog score in progress, so a second request waits for it instead of saving a copy
    @ObservationIgnored private var downloadTasks: [String: Task<Void, Error>] = [:]

    private init() {}

    /// Who the private scores are checked for: the signed-in e-mail, or "guest".
    var account: String {
        guard let user = authService.currentUser, user.authProvider != .guest, !user.email.isEmpty else { return "guest" }
        return user.email.lowercased()
    }

    /// Loads the catalog the first time and again whenever the account changes (sign-in, sign-out, deletion).
    func refreshIfNeeded() async {
        guard scores.isEmpty || loadedAccount != account else { return }
        if loadedAccount != account {
            scores.removeAll { $0.isPrivate }
        }
        await refresh()
    }

    /// Reloads the catalog and keeps the scores this account can open.
    func refresh() async {
        let account = self.account
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let script = try await Self.fetch(URL(string: "scores/catalog.js", relativeTo: Self.siteURL)!)
            let globals = try Self.evaluate(script, names: ["SCORE_CATALOG"])
            let entries = globals["SCORE_CATALOG"] as? [[String: Any]] ?? []
            let candidates = entries.compactMap(Self.score(from:))
            // Check every score at once, keeping the catalog's order
            var allowed: [Int: OnlineScore] = [:]
            await withTaskGroup(of: (Int, OnlineScore?).self) { group in
                for (index, candidate) in candidates.enumerated() {
                    group.addTask { (index, await self.checked(candidate)) }
                }
                for await (index, score) in group {
                    allowed[index] = score
                }
            }
            // The account changed while checking: the reload started for the new one keeps its own list
            guard account == self.account else { return }
            scores = allowed.keys.sorted().compactMap { allowed[$0] }
            loadedAccount = account
        } catch {
            errorMessage = "Não foi possível carregar o catálogo: \(error.localizedDescription)"
        }
    }

    // MARK: - Downloading

    /// The phone's copy of a catalog score, or nil when it was not downloaded yet.
    func localCopy(of entry: OnlineScore, in context: ModelContext) -> Score? {
        let scores = (try? context.fetch(FetchDescriptor<Score>())) ?? []
        return scores.first { $0.catalogId == entry.id }
    }

    /// The phone's copy of a catalog score, downloaded and saved in the library first when it is not there yet.
    func download(_ entry: OnlineScore, into context: ModelContext) async throws -> Score {
        if let local = localCopy(of: entry, in: context) {
            return local
        }
        if let running = downloadTasks[entry.id] {
            try await running.value
        } else {
            let task = Task { try await self.save(entry, into: context) }
            downloadTasks[entry.id] = task
            downloads[entry.id] = CatalogDownload()
            defer {
                downloadTasks[entry.id] = nil
                downloads[entry.id] = nil
            }
            try await task.value
        }
        guard let local = localCopy(of: entry, in: context) else { throw OnlineLibraryError.unreadable }
        return local
    }

    /// Downloads a catalog score and saves it in the library: read from its MusicXML when the catalog lists one,
    /// else built from the web player's note data.
    private func save(_ entry: OnlineScore, into context: ModelContext) async throws {
        let id = entry.id
        let progress: @MainActor @Sendable (Double) -> Void = { self.downloads[id]?.fraction = $0 }
        let score: Score
        if let url = entry.musicXMLURL {
            let data = try await Self.fetch(url, progress: progress)
            do {
                score = try MusicXMLParser.parse(data: data)
            } catch {
                throw OnlineLibraryError.unreadable
            }
        } else if let url = entry.dataURL {
            let script = try await Self.fetch(url, progress: progress)
            guard let data = try Self.evaluate(script, names: ["SCORE_DATA"])["SCORE_DATA"] as? [[String: Any]],
                  !data.isEmpty else {
                throw OnlineLibraryError.unreadable
            }
            score = Self.playableScore(from: data.map(Self.measure(from:)), of: entry)
        } else {
            throw OnlineLibraryError.notFound
        }
        // The catalog's names, as on its card, over whatever the file calls itself
        score.title = entry.pieceTitle
        score.composer = entry.composer
        if let difficulty = entry.difficulty {
            score.difficulty = difficulty
        }
        score.catalogId = entry.id
        context.insert(score)
        try context.save()
    }

    // MARK: - Access

    /// The score with its current visibility, or nil when this account may not open it.
    private func checked(_ candidate: OnlineScore) async -> OnlineScore? {
        var score = candidate
        let privacy = (await privacySetting(for: score.id)) ?? score.defaultPrivacy
        score.isPrivate = privacy != "public"
        if score.isPrivate, !(await isAllowedPrivate(score)) {
            return nil
        }
        return score
    }

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

    // MARK: - Site Files

    /// Downloads a file of the site off the main thread, reporting the part received when the server gives its size.
    nonisolated private static func fetch(_ url: URL, progress: @escaping @MainActor @Sendable (Double) -> Void = { _ in }) async throws -> Data {
        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw OnlineLibraryError.notFound }
            let expected = response.expectedContentLength
            var data = Data()
            if expected > 0 {
                data.reserveCapacity(Int(expected))
            }
            for try await byte in bytes {
                data.append(byte)
                if expected > 0, data.count % 8192 == 0 {
                    // A compressed transfer can count fewer bytes than arrive
                    await progress(min(1, Double(data.count) / Double(expected)))
                }
            }
            return data
        } catch let error as OnlineLibraryError {
            throw error
        } catch {
            throw OnlineLibraryError.connection
        }
    }

    /// Runs one of the site's data scripts (they assign `window.NAME = ...`) and returns those globals as JSON values.
    private static func evaluate(_ script: Data, names: [String]) throws -> [String: Any] {
        guard let source = String(data: script, encoding: .utf8), let context = JSContext() else {
            throw OnlineLibraryError.unreadable
        }
        context.evaluateScript("var window = this;")
        context.evaluateScript(source)
        if context.exception != nil {
            throw OnlineLibraryError.unreadable
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
        guard let id = entry["id"] as? String else { return nil }
        let files = (entry["downloads"] as? [[String: Any]] ?? []).compactMap { $0["href"] as? String }
        let musicXML = files.first { href in
            [".mxl", ".musicxml", ".xml"].contains { href.lowercased().hasSuffix($0) }
        }
        let musicXMLURL = musicXML.flatMap { URL(string: $0, relativeTo: siteURL)?.absoluteURL }
        let dataURL = (entry["data"] as? String).flatMap { URL(string: $0, relativeTo: siteURL)?.absoluteURL }
        guard musicXMLURL != nil || dataURL != nil else { return nil }
        return OnlineScore(
            id: id,
            title: entry["sidebarTitle"] as? String ?? entry["title"] as? String ?? id,
            credits: entry["credits"] as? String ?? "",
            bpm: entry["bpm"] as? Int ?? 80,
            beatsPerMeasure: entry["beatsPerMeasure"] as? Int ?? 4,
            musicXMLURL: musicXMLURL,
            dataURL: dataURL,
            difficulty: (entry["tags"] as? [String] ?? []).compactMap(Difficulty.init(rawValue:)).first,
            defaultPrivacy: entry["defaultPrivacy"] as? String ?? "public"
        )
    }

    // MARK: - SCORE_DATA → Model

    /// A score from note data, which only has MIDI numbers: the notes are spelled for the piece's likely key, so the
    /// engraving and the reading drill show the accidentals a printed edition would. The catalog gives the tempo and
    /// the beats of a measure, counted in quarters.
    private static func playableScore(from measures: [Measure], of entry: OnlineScore) -> Score {
        let spelled = ReadingDrill.respelled(measures)
        let tempo = max(20, entry.bpm)
        let beatsPerMeasure = max(1, entry.beatsPerMeasure)
        let totalBeats = measures.reduce(0.0) { $0 + $1.beats(timeSignatureTop: beatsPerMeasure) }
        return Score(
            title: entry.pieceTitle,
            composer: entry.composer,
            difficulty: entry.difficulty ?? .advanced,
            source: .imported,
            tempo: tempo,
            keySignatureValue: spelled.keySignature,
            timeSignatureTop: beatsPerMeasure,
            timeSignatureBottom: 4,
            estimatedDuration: totalBeats * 60.0 / Double(tempo),
            measures: spelled.measures
        )
    }

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
                        pitch: ReadingDrill.spelledPitch(midi: midi, keySignature: 0),
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
}
