// ScoreStorageService.swift
// luksMusic
//
// Service managing score storage, sample pieces preloading, and file imports/exports.

import Foundation
import SwiftData
import Observation

/// Service managing persistence and file I/O for piano scores.
@MainActor
@Observable
final class ScoreStorageService {

    static let shared = ScoreStorageService()

    var isLoading: Bool = false
    var errorMessage: String? = nil

    private init() {}

    // MARK: - Preload Default Piano Pieces

    /// A public-domain piano piece bundled as MusicXML (`SampleScores/<file>.musicxml`): a CC0 edition from
    /// MuseScore taken from the PDMX dataset, with its repeats written out so it reads in the order it is played.
    private struct SamplePiece {
        let file: String
        let title: String
        let composer: String
        let difficulty: Difficulty
        let isFavorite: Bool
    }

    private static let samplePieces = [
        SamplePiece(file: "fur-elise", title: "Für Elise (Bagatelle No. 25)", composer: "Ludwig van Beethoven",
                    difficulty: .intermediate, isFavorite: true),
        SamplePiece(file: "minuet-in-g", title: "Minuet in G Major (BWV Anh. 114)", composer: "Christian Petzold / J.S. Bach",
                    difficulty: .beginner, isFavorite: true),
        SamplePiece(file: "gymnopedie-1", title: "Gymnopédie No. 1", composer: "Erik Satie",
                    difficulty: .intermediate, isFavorite: false),
        SamplePiece(file: "moonlight-sonata-1", title: "Moonlight Sonata (Op. 27 No. 2)", composer: "Ludwig van Beethoven",
                    difficulty: .advanced, isFavorite: true),
    ]

    /// Preloads public-domain piano pieces into SwiftData if the library is empty.
    func preloadSampleScoresIfNeeded(modelContext: ModelContext) {
        removeLegacyDarkDream(modelContext: modelContext)
        replaceSampleSketches(modelContext: modelContext)

        let descriptor = FetchDescriptor<Score>()
        let existingScores = (try? modelContext.fetch(descriptor)) ?? []
        guard existingScores.isEmpty else { return }

        let now = Date()
        for (index, piece) in Self.samplePieces.enumerated() {
            guard let score = Self.loadSample(piece) else { continue }
            score.dateCreated = now.addingTimeInterval(-100 * Double(index + 1))
            modelContext.insert(score)
        }

        try? modelContext.save()
    }

    /// The bundled piece as a score, or nil when its file is missing or unreadable.
    private static func loadSample(_ piece: SamplePiece) -> Score? {
        guard let url = Bundle.main.url(forResource: piece.file, withExtension: "musicxml"),
              let score = try? MusicXMLParser.parse(url: url) else { return nil }
        score.title = piece.title
        score.composer = piece.composer
        score.difficulty = piece.difficulty
        score.isFavorite = piece.isFavorite
        score.source = .manual
        return score
    }

    /// App builds up to 20 seeded hand-made sketches of these pieces, one to four measures long. The full editions
    /// take their place once, in the same scores, so favorites and practice history stay.
    private func replaceSampleSketches(modelContext: ModelContext) {
        let key = "luksMusic_fullSamplePieces"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let scores = (try? modelContext.fetch(FetchDescriptor<Score>())) ?? []
        for piece in Self.samplePieces {
            guard let sketch = scores.first(where: { $0.title == piece.title && $0.musicXMLData == nil && $0.measureCount <= 4 }),
                  let full = Self.loadSample(piece) else { continue }
            sketch.composer = full.composer
            sketch.difficulty = full.difficulty
            sketch.tempo = full.tempo
            sketch.keySignatureValue = full.keySignatureValue
            sketch.timeSignatureTop = full.timeSignatureTop
            sketch.timeSignatureBottom = full.timeSignatureBottom
            sketch.estimatedDuration = full.estimatedDuration
            // Setting the measures drops the file (it marks an edit), so the file goes in after them
            sketch.measures = full.measures
            sketch.musicXMLData = full.musicXMLData
        }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Builds before 1.0 seeded a hand-made transcription of Dark Dream; the song now lives in the online library
    /// with its original MuseScore pages (private to its author), so the old copy is removed once.
    private func removeLegacyDarkDream(modelContext: ModelContext) {
        let key = "luksMusic_removedLegacyDarkDream"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let scores = (try? modelContext.fetch(FetchDescriptor<Score>())) ?? []
        for score in scores where score.title.contains("Dark Dream") && score.composer.contains("Curley Gao") {
            modelContext.delete(score)
        }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - File Import

    /// Imports a score from a MusicXML file (.musicxml, .xml).
    func importScore(from url: URL, modelContext: ModelContext) async throws -> Score {
        isLoading = true
        defer { isLoading = false }

        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "musicxml" || fileExtension == "xml" else {
            throw MusicXMLParserError.parsingFailed("Unsupported file format: .\(fileExtension)")
        }
        let data = try Data(contentsOf: url)
        let score = try MusicXMLParser.parse(data: data)

        modelContext.insert(score)
        try modelContext.save()
        return score
    }

    // MARK: - File Export

    /// Exports a score as MusicXML file in temporary directory: the file it was read from when its notes were not
    /// edited, else the edited measures.
    func exportScoreAsMusicXML(_ score: Score) throws -> URL {
        let sanitizedTitle = score.title.replacingOccurrences(of: " ", with: "_")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedTitle).musicxml")

        if let original = score.musicXMLData {
            try original.write(to: tempURL, options: .atomic)
        } else {
            try MusicXMLExporter.exportToFile(score, to: tempURL)
        }
        return tempURL
    }
}
