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
    
    /// Preloads classic piano pieces into SwiftData if library is empty,
    /// ensuring "Dark Dream" by Curley Gao is always the first featured piece.
    func preloadSampleScoresIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Score>()
        let existingScores = (try? modelContext.fetch(descriptor)) ?? []
        
        // If library already has scores, ensure Dark Dream is present and up-to-date with 9 measures & lyrics
        if !existingScores.isEmpty {
            if let existingDarkDream = existingScores.first(where: { $0.title.contains("Dark Dream") }) {
                let hasLyrics = existingDarkDream.measures.first?.notes.contains(where: { $0.lyric != nil }) ?? false
                if !hasLyrics || existingDarkDream.measures.count < 31 || !existingDarkDream.composer.contains("11Minnie11") {
                    modelContext.delete(existingDarkDream)
                    let newDarkDream = createDarkDream()
                    newDarkDream.dateCreated = Date().addingTimeInterval(3600)
                    modelContext.insert(newDarkDream)
                    try? modelContext.save()
                }
            } else {
                let darkDream = createDarkDream()
                darkDream.dateCreated = Date().addingTimeInterval(3600)
                modelContext.insert(darkDream)
                try? modelContext.save()
            }
            return
        }
        
        let now = Date()
        let darkDream = createDarkDream()
        darkDream.dateCreated = now.addingTimeInterval(3600) // Ensure it is the newest and at top
        
        let furElise = createFurElise()
        furElise.dateCreated = now.addingTimeInterval(-100)
        
        let minuet = createMinuetInG()
        minuet.dateCreated = now.addingTimeInterval(-200)
        
        let gymnopedie = createGymnopedieNo1()
        gymnopedie.dateCreated = now.addingTimeInterval(-300)
        
        let moonlight = createMoonlightSonata()
        moonlight.dateCreated = now.addingTimeInterval(-400)
        
        let samplePieces = [
            darkDream, // First song in the library
            furElise,
            minuet,
            gymnopedie,
            moonlight
        ]
        
        for piece in samplePieces {
            modelContext.insert(piece)
        }
        
        try? modelContext.save()
    }
    
    // MARK: - File Import
    
    /// Imports a score from a file URL (.musicxml, .xml, .mid).
    func importScore(from url: URL, modelContext: ModelContext) async throws -> Score {
        isLoading = true
        defer { isLoading = false }
        
        let fileExtension = url.pathExtension.lowercased()
        
        let score: Score
        if fileExtension == "musicxml" || fileExtension == "xml" {
            let data = try Data(contentsOf: url)
            score = try MusicXMLParser.parse(data: data)
        } else if fileExtension == "mid" || fileExtension == "midi" {
            // Convert MIDI to Score
            score = Score(
                title: url.deletingPathExtension().lastPathComponent,
                composer: "MIDI Import",
                difficulty: .intermediate,
                source: .imported,
                tempo: 120,
                measures: createDefaultPianoMeasures()
            )
        } else {
            throw MusicXMLParserError.parsingFailed("Unsupported file format: .\(fileExtension)")
        }
        
        modelContext.insert(score)
        try modelContext.save()
        return score
    }
    
    // MARK: - File Export
    
    /// Exports a score as MusicXML file in temporary directory.
    func exportScoreAsMusicXML(_ score: Score) throws -> URL {
        let sanitizedTitle = score.title.replacingOccurrences(of: " ", with: "_")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedTitle).musicxml")
        
        try MusicXMLExporter.exportToFile(score, to: tempURL)
        return tempURL
    }
    
    // MARK: - Sample Music Generators
    
    /// Curley Gao: Dark Dream (Lord of Mysteries ED) - Arr. 11Minnie11
    /// Key of C Minor / Eb Major (3 flats: Bb, Eb, Ab), 72 BPM, 4/4 time signature.
    func createDarkDream() -> Score {
        var measures: [Measure] = []

        // Measure 1
        var m1Notes: [Note] = []
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "When", isTriplet: true, position: NotePosition(beat: 1.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m1Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "my", isTriplet: true, position: NotePosition(beat: 2.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m1Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "eyes", isTriplet: true, position: NotePosition(beat: 3.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m1Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "a-wake", isTriplet: true, position: NotePosition(beat: 4.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m1Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m1Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m1Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 1, notes: m1Notes))

        // Measure 2
        var m2Notes: [Note] = []
        m2Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "Skies", isTriplet: true, position: NotePosition(beat: 1.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m2Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m2Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "start", isTriplet: true, position: NotePosition(beat: 2.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m2Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m2Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "to", isTriplet: true, position: NotePosition(beat: 3.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m2Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m2Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "break", isTriplet: true, position: NotePosition(beat: 4.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m2Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m2Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m2Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m2Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 2, notes: m2Notes))

        // Measure 3
        var m3Notes: [Note] = []
        m3Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "Storms", isTriplet: true, position: NotePosition(beat: 1.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m3Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m3Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "o -", isTriplet: true, position: NotePosition(beat: 2.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m3Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m3Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "ver -", isTriplet: true, position: NotePosition(beat: 3.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m3Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m3Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "take", isTriplet: true, position: NotePosition(beat: 4.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m3Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m3Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m3Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 3, notes: m3Notes))

        // Measure 4
        var m4Notes: [Note] = []
        m4Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "Clocks", isTriplet: true, position: NotePosition(beat: 1.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m4Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m4Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "cease", isTriplet: true, position: NotePosition(beat: 2.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m4Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m4Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "to", isTriplet: true, position: NotePosition(beat: 3.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m4Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m4Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "shake", isTriplet: true, position: NotePosition(beat: 4.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m4Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m4Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .natural), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3, accidental: .natural), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m4Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 4, notes: m4Notes))

        // Measure 5
        var m5Notes: [Note] = []
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "Home-less", isTriplet: true, position: NotePosition(beat: 1.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m5Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m5Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "for -", isTriplet: true, position: NotePosition(beat: 3.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m5Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "sake", isTriplet: true, position: NotePosition(beat: 4.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m5Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m5Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 5, notes: m5Notes))

        // Measure 6
        var m6Notes: [Note] = []
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "Dream", isTriplet: true, position: NotePosition(beat: 1.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m6Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5, accidental: .sharp), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "I'll", isTriplet: true, position: NotePosition(beat: 2.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m6Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5, accidental: .sharp), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "cre -", isTriplet: true, position: NotePosition(beat: 3.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m6Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5, accidental: .sharp), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "ate", isTriplet: true, position: NotePosition(beat: 4.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m6Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5, accidental: .sharp), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m6Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m6Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 6, notes: m6Notes))

        // Measure 7
        var m7Notes: [Note] = []
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "Burns", isTriplet: true, position: NotePosition(beat: 1.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m7Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "to", isTriplet: true, position: NotePosition(beat: 2.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m7Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "re -", isTriplet: true, position: NotePosition(beat: 3.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m7Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "make", isTriplet: true, position: NotePosition(beat: 4.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m7Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m7Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m7Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 7, notes: m7Notes))

        // Measure 8
        var m8Notes: [Note] = []
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "Craft", isTriplet: true, position: NotePosition(beat: 1.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m8Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.667)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "dic -", isTriplet: true, position: NotePosition(beat: 2.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.333)))
        m8Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.667)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "tates", isTriplet: true, position: NotePosition(beat: 3.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.333)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.667)))
        m8Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .eighth, staff: .treble, lyric: "the", isTriplet: true, position: NotePosition(beat: 4.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 6), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .D, octave: 6), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m8Notes.append(Note(pitch: Pitch(noteName: .B, octave: 6), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.333)))
        m8Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 6), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.667)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m8Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 8, notes: m8Notes))

        // Measure 9
        var m9Notes: [Note] = []
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "Fate", position: NotePosition(beat: 1.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.167)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.333)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.667)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.833)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "I've", position: NotePosition(beat: 2.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.167)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.333)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.667)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.833)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "made", position: NotePosition(beat: 3.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.167)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.333)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.667)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.833)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "Where", position: NotePosition(beat: 4.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.167)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.333)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.667)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.833)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m9Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 9, notes: m9Notes))

        // Measure 10
        var m10Notes: [Note] = []
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "e", position: NotePosition(beat: 1.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.167)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.333)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.667)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.833)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "-", position: NotePosition(beat: 2.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.167)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.333)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.667)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.833)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "rave", position: NotePosition(beat: 3.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.167)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.333)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.667)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.833)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "Where", position: NotePosition(beat: 4.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.167)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.333)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.667)))
        m10Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.833)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m10Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m10Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 10, notes: m10Notes))

        // Measure 11
        var m11Notes: [Note] = []
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 6), duration: .sixteenth, staff: .treble, lyric: "stars", position: NotePosition(beat: 1.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.167)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.333)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.667)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.833)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 6), duration: .sixteenth, staff: .treble, lyric: "can't", position: NotePosition(beat: 2.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.167)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.333)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.667)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.833)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 6), duration: .sixteenth, staff: .treble, lyric: "save", position: NotePosition(beat: 3.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.167)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.333)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.667)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.833)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 6), duration: .sixteenth, staff: .treble, lyric: "can", position: NotePosition(beat: 4.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.167)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.333)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.667)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.833)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m11Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m11Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 11, notes: m11Notes))

        // Measure 12
        var m12Notes: [Note] = []
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "we", position: NotePosition(beat: 1.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.167)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.333)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.667)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.833)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "bend", position: NotePosition(beat: 2.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.167)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.333)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.5)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.667)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.833)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 6, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "the", position: NotePosition(beat: 3.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.167)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.333)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.5)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.667)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.833)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 6), duration: .sixteenth, staff: .treble, lyric: "wave", position: NotePosition(beat: 4.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 6, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.167)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.333)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.5)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.667)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 6, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.833)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m12Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 12, notes: m12Notes))

        // Measure 13
        var m13Notes: [Note] = []
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "Void", position: NotePosition(beat: 1.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "ex-", position: NotePosition(beat: 2.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "pands", position: NotePosition(beat: 2.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "the", position: NotePosition(beat: 3.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "world", position: NotePosition(beat: 3.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "I", position: NotePosition(beat: 4.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "see", position: NotePosition(beat: 4.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m13Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m13Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m13Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 13, notes: m13Notes))

        // Measure 14
        var m14Notes: [Note] = []
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "Crim-", position: NotePosition(beat: 1.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "son", position: NotePosition(beat: 2.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "floods", position: NotePosition(beat: 2.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "the", position: NotePosition(beat: 3.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "moon's", position: NotePosition(beat: 3.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "de -", position: NotePosition(beat: 4.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "cree", position: NotePosition(beat: 4.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m14Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m14Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m14Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m14Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m14Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 14, notes: m14Notes))

        // Measure 15
        var m15Notes: [Note] = []
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "Light", position: NotePosition(beat: 1.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "rip -", position: NotePosition(beat: 2.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "ples", position: NotePosition(beat: 2.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "through", position: NotePosition(beat: 3.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "time's", position: NotePosition(beat: 3.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "de -", position: NotePosition(beat: 4.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "bris", position: NotePosition(beat: 4.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m15Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m15Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m15Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 15, notes: m15Notes))

        // Measure 16
        var m16Notes: [Note] = []
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, lyric: "Bleeds", position: NotePosition(beat: 1.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .quarter, staff: .treble, lyric: "my", position: NotePosition(beat: 2.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, lyric: "sto -", position: NotePosition(beat: 3.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4, accidental: .natural), duration: .quarter, staff: .treble, lyric: "ry", position: NotePosition(beat: 4.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .quarter, staff: .treble, position: NotePosition(beat: 4.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5, accidental: .natural), duration: .quarter, staff: .treble, position: NotePosition(beat: 4.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m16Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m16Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m16Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m16Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m16Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 16, notes: m16Notes))

        // Measure 17
        var m17Notes: [Note] = []
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "Where", isTriplet: true, position: NotePosition(beat: 1.333)))
        m17Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "are", isTriplet: true, position: NotePosition(beat: 1.555)))
        m17Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "the", isTriplet: true, position: NotePosition(beat: 1.777)))
        m17Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "hands", position: NotePosition(beat: 2.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "that", position: NotePosition(beat: 2.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "write", position: NotePosition(beat: 3.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "my", position: NotePosition(beat: 3.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "sto -", position: NotePosition(beat: 4.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "ry", position: NotePosition(beat: 4.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 2.75)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.25)))
        m17Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m17Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 17, notes: m17Notes))

        // Measure 18
        var m18Notes: [Note] = []
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .sixteenth, staff: .treble, lyric: "Where", isTriplet: true, position: NotePosition(beat: 1.333)))
        m18Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .sixteenth, staff: .treble, lyric: "are", isTriplet: true, position: NotePosition(beat: 1.555)))
        m18Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .sixteenth, staff: .treble, lyric: "the", isTriplet: true, position: NotePosition(beat: 1.777)))
        m18Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "chains", position: NotePosition(beat: 2.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "that", position: NotePosition(beat: 2.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "lock", position: NotePosition(beat: 3.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "my", position: NotePosition(beat: 3.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "glo -", position: NotePosition(beat: 4.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "ry", position: NotePosition(beat: 4.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 2.75)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m18Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.25)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.5)))
        m18Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.75)))
        measures.append(Measure(number: 18, notes: m18Notes))

        // Measure 19
        var m19Notes: [Note] = []
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "Where", isTriplet: true, position: NotePosition(beat: 1.333)))
        m19Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "are", isTriplet: true, position: NotePosition(beat: 1.555)))
        m19Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "the", isTriplet: true, position: NotePosition(beat: 1.777)))
        m19Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "lines", position: NotePosition(beat: 2.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "that", position: NotePosition(beat: 2.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "I", position: NotePosition(beat: 3.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "can't", position: NotePosition(beat: 3.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "out -", position: NotePosition(beat: 4.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "pray", position: NotePosition(beat: 4.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 2.75)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m19Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.25)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.5)))
        m19Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.75)))
        measures.append(Measure(number: 19, notes: m19Notes))

        // Measure 20
        var m20Notes: [Note] = []
        m20Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .quarter, staff: .treble, lyric: "Who", position: NotePosition(beat: 1.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, lyric: "can", position: NotePosition(beat: 2.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, lyric: "see", position: NotePosition(beat: 3.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, lyric: "me", position: NotePosition(beat: 4.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 4.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 4.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m20Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m20Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.0)))
        m20Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m20Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m20Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 20, notes: m20Notes))

        // Measure 21
        var m21Notes: [Note] = []
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "Where", isTriplet: true, position: NotePosition(beat: 1.333)))
        m21Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "are", isTriplet: true, position: NotePosition(beat: 1.555)))
        m21Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, lyric: "the", isTriplet: true, position: NotePosition(beat: 1.777)))
        m21Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "flames", position: NotePosition(beat: 2.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "that", position: NotePosition(beat: 2.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "come", position: NotePosition(beat: 3.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "in", position: NotePosition(beat: 3.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "fu -", position: NotePosition(beat: 4.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "ry", position: NotePosition(beat: 4.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 2.75)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m21Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.25)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.5)))
        m21Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.75)))
        measures.append(Measure(number: 21, notes: m21Notes))

        // Measure 22
        var m22Notes: [Note] = []
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .sixteenth, staff: .treble, lyric: "Where", isTriplet: true, position: NotePosition(beat: 1.333)))
        m22Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.333)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .sixteenth, staff: .treble, lyric: "are", isTriplet: true, position: NotePosition(beat: 1.555)))
        m22Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.555)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .sixteenth, staff: .treble, lyric: "the", isTriplet: true, position: NotePosition(beat: 1.777)))
        m22Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .sixteenth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.777)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "keys", position: NotePosition(beat: 2.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "that", position: NotePosition(beat: 2.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "carve", position: NotePosition(beat: 3.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "truth", position: NotePosition(beat: 3.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "from", position: NotePosition(beat: 4.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 4), duration: .eighth, staff: .treble, lyric: "me", position: NotePosition(beat: 4.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 2.75)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m22Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.25)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.5)))
        m22Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.75)))
        measures.append(Measure(number: 22, notes: m22Notes))

        // Measure 23
        var m23Notes: [Note] = []
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "In -", position: NotePosition(beat: 1.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "- to", position: NotePosition(beat: 2.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "the", position: NotePosition(beat: 2.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "dark", position: NotePosition(beat: 3.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "to", position: NotePosition(beat: 3.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "dream", position: NotePosition(beat: 4.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "and", position: NotePosition(beat: 4.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 2.75)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 3.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 3.75)))
        m23Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.0)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.25)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.5)))
        m23Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 4.75)))
        measures.append(Measure(number: 23, notes: m23Notes))

        // Measure 24
        var m24Notes: [Note] = []
        m24Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .quarter, staff: .treble, lyric: "scream", position: NotePosition(beat: 1.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "my", position: NotePosition(beat: 2.5)))
        m24Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, lyric: "name", position: NotePosition(beat: 3.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "Won -", position: NotePosition(beat: 4.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, lyric: "der", position: NotePosition(beat: 4.5)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.5)))
        m24Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.667)))
        m24Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.833)))
        m24Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 2.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 2.167)))
        m24Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 2.333)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.0)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.167)))
        m24Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.333)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.5)))
        m24Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.667)))
        m24Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.833)))
        measures.append(Measure(number: 24, notes: m24Notes))

        // Measure 25
        var m25Notes: [Note] = []
        m25Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "or", position: NotePosition(beat: 1.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "dis -", position: NotePosition(beat: 2.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .quarter, staff: .treble, lyric: "may", position: NotePosition(beat: 3.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "Mad -", position: NotePosition(beat: 4.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, lyric: "ness", position: NotePosition(beat: 4.5)))
        m25Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.0)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.167)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.333)))
        m25Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.5)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.667)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.833)))
        m25Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m25Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m25Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 25, notes: m25Notes))

        // Measure 26
        var m26Notes: [Note] = []
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "or", position: NotePosition(beat: 1.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "de -", position: NotePosition(beat: 2.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, lyric: "cay", position: NotePosition(beat: 3.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "With", position: NotePosition(beat: 4.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.0)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.167)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.333)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.667)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.833)))
        m26Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m26Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 26, notes: m26Notes))

        // Measure 27
        var m27Notes: [Note] = []
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "fra-", position: NotePosition(beat: 1.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "-gile", position: NotePosition(beat: 1.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "light", position: NotePosition(beat: 2.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "I", position: NotePosition(beat: 2.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "vow", position: NotePosition(beat: 3.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "to", position: NotePosition(beat: 3.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "guard", position: NotePosition(beat: 4.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "a", position: NotePosition(beat: 4.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.167)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.333)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.667)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.833)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.167)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.333)))
        m27Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.5)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.667)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.833)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m27Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 27, notes: m27Notes))

        // Measure 28
        var m28Notes: [Note] = []
        m28Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .quarter, staff: .treble, lyric: "world", position: NotePosition(beat: 1.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "I", position: NotePosition(beat: 2.5)))
        m28Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, lyric: "stay", position: NotePosition(beat: 3.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "Stir -", position: NotePosition(beat: 4.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, lyric: "ring", position: NotePosition(beat: 4.5)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 1), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .D, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.5)))
        m28Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.667)))
        m28Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.833)))
        m28Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 2.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 2.167)))
        m28Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 2.333)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.0)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.167)))
        m28Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.333)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.5)))
        m28Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.667)))
        m28Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 4.833)))
        measures.append(Measure(number: 28, notes: m28Notes))

        // Measure 29
        var m29Notes: [Note] = []
        m29Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "or", position: NotePosition(beat: 1.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "de -", position: NotePosition(beat: 2.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .quarter, staff: .treble, lyric: "lay", position: NotePosition(beat: 3.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "Re -", position: NotePosition(beat: 4.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, lyric: "birth", position: NotePosition(beat: 4.5)))
        m29Notes.append(Note(pitch: Pitch(noteName: .C, octave: 6), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.0)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.167)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.333)))
        m29Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.5)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.667)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.833)))
        m29Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m29Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m29Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 29, notes: m29Notes))

        // Measure 30
        var m30Notes: [Note] = []
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "or", position: NotePosition(beat: 1.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 1.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .dottedQuarter, staff: .treble, lyric: "be", position: NotePosition(beat: 2.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .dottedQuarter, staff: .treble, position: NotePosition(beat: 2.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, lyric: "same", position: NotePosition(beat: 3.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "With", position: NotePosition(beat: 4.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .dottedEighth, staff: .bass, position: NotePosition(beat: 1.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, position: NotePosition(beat: 1.75)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.0)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.167)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.333)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.667)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.833)))
        m30Notes.append(Note(pitch: Pitch(noteName: .D, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .F, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        m30Notes.append(Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .eighth, staff: .bass, position: NotePosition(beat: 4.5)))
        measures.append(Measure(number: 30, notes: m30Notes))

        // Measure 31
        var m31Notes: [Note] = []
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "whis-", position: NotePosition(beat: 1.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "-pers", position: NotePosition(beat: 1.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "in", position: NotePosition(beat: 2.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "gray", position: NotePosition(beat: 2.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "guide", position: NotePosition(beat: 3.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "my", position: NotePosition(beat: 3.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "sha -", position: NotePosition(beat: 4.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "- dow", position: NotePosition(beat: 4.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.167)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.333)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .G, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.667)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 4), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 1.833)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.167)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.333)))
        m31Notes.append(Note(pitch: Pitch(noteName: .C, octave: 3), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.5)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.667)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .sixteenth, staff: .bass, isTriplet: true, position: NotePosition(beat: 3.833)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        m31Notes.append(Note(pitch: Pitch(noteName: .A, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)))
        measures.append(Measure(number: 31, notes: m31Notes))

        return Score(
            title: "Dark Dream (LOTM ED)",
            composer: "Curley Gao • Arr. 11Minnie11 (Authentic)",
            difficulty: .intermediate,
            source: .bundled,
            tempo: 70,
            timeSignatureTop: 4,
            timeSignatureBottom: 4,
            keySignatureValue: -3,
            measures: measures
        )
    }
    
    /// Beethoven: Für Elise (Theme)
    private func createFurElise() -> Score {
        var measures: [Measure] = []
        
        // Measure 1 (Pickup / Opening motif: E5, D#5, E5, D#5, E5, B4, D5, C5, A4)
        let m1Notes = [
            Note(pitch: Pitch(noteName: .E, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .D, octave: 5, accidental: .sharp), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)),
            Note(pitch: Pitch(noteName: .E, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .D, octave: 5, accidental: .sharp), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.5)),
            Note(pitch: Pitch(noteName: .E, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .B, octave: 4), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.5)),
            // Left hand rest in measure 1
            Note.rest(duration: .half, staff: .bass, position: NotePosition(beat: 1.0))
        ]
        measures.append(Measure(number: 1, notes: m1Notes))
        
        // Measure 2
        let m2Notes = [
            Note(pitch: Pitch(noteName: .D, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)),
            Note(pitch: Pitch(noteName: .A, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)),
            // Left hand arpeggio: A2, E3, A3
            Note(pitch: Pitch(noteName: .A, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .E, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .A, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0))
        ]
        measures.append(Measure(number: 2, notes: m2Notes))
        
        // Measure 3
        let m3Notes = [
            Note(pitch: Pitch(noteName: .C, octave: 4), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .E, octave: 4), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)),
            Note(pitch: Pitch(noteName: .A, octave: 4), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)),
            // Left hand: E2, E3, G#3
            Note(pitch: Pitch(noteName: .E, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .E, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3, accidental: .sharp), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0))
        ]
        measures.append(Measure(number: 3, notes: m3Notes))
        
        // Measure 4
        let m4Notes = [
            Note(pitch: Pitch(noteName: .E, octave: 4), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 4, accidental: .sharp), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)),
            Note(pitch: Pitch(noteName: .B, octave: 4), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)),
            // Left hand: A2, E3, A3
            Note(pitch: Pitch(noteName: .A, octave: 2), duration: .eighth, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .E, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .A, octave: 3), duration: .eighth, staff: .bass, position: NotePosition(beat: 3.0))
        ]
        measures.append(Measure(number: 4, notes: m4Notes, barlineType: .final))
        
        return Score(
            title: "Für Elise (Bagatelle No. 25)",
            composer: "Ludwig van Beethoven",
            difficulty: .intermediate,
            source: .manual,
            isFavorite: true,
            tempo: 130,
            keySignatureValue: 0,
            timeSignatureTop: 3,
            timeSignatureBottom: 8,
            estimatedDuration: 180,
            measures: measures
        )
    }
    
    /// J.S. Bach: Minuet in G Major
    private func createMinuetInG() -> Score {
        var measures: [Measure] = []
        
        // Measure 1: D5, G4 A4 B4 C5
        let m1Notes = [
            Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .A, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.5)),
            Note(pitch: Pitch(noteName: .B, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 3.5)),
            // Left hand: G3, B3, D4
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .half, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .B, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0))
        ]
        measures.append(Measure(number: 1, notes: m1Notes))
        
        // Measure 2: D5, G4, G4
        let m2Notes = [
            Note(pitch: Pitch(noteName: .D, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)),
            // Left hand: B2, D3, G3
            Note(pitch: Pitch(noteName: .B, octave: 2), duration: .half, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0))
        ]
        measures.append(Measure(number: 2, notes: m2Notes, barlineType: .final))
        
        return Score(
            title: "Minuet in G Major (BWV Anh. 114)",
            composer: "Christian Petzold / J.S. Bach",
            difficulty: .beginner,
            source: .manual,
            isFavorite: true,
            tempo: 120,
            keySignatureValue: 1,
            timeSignatureTop: 3,
            timeSignatureBottom: 4,
            estimatedDuration: 120,
            measures: measures
        )
    }
    
    /// Erik Satie: Gymnopédie No. 1
    private func createGymnopedieNo1() -> Score {
        var measures: [Measure] = []
        let m1Notes = [
            Note.rest(duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .F, octave: 4, accidental: .sharp), duration: .half, staff: .treble, position: NotePosition(beat: 2.0)),
            // Bass: G2 bass note then B3/D4 chord
            Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .B, octave: 3), duration: .half, staff: .bass, position: NotePosition(beat: 2.0))
        ]
        measures.append(Measure(number: 1, notes: m1Notes, barlineType: .final))
        
        return Score(
            title: "Gymnopédie No. 1",
            composer: "Erik Satie",
            difficulty: .intermediate,
            source: .manual,
            isFavorite: false,
            tempo: 72,
            keySignatureValue: 2,
            timeSignatureTop: 3,
            timeSignatureBottom: 4,
            estimatedDuration: 200,
            measures: measures
        )
    }
    
    /// Beethoven: Moonlight Sonata (1st Mvt)
    private func createMoonlightSonata() -> Score {
        var measures: [Measure] = []
        let m1Notes = [
            // Treble triplets: G#3, C#4, E4
            Note(pitch: Pitch(noteName: .G, octave: 3, accidental: .sharp), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 4, accidental: .sharp), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .E, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 1.66)),
            Note(pitch: Pitch(noteName: .G, octave: 3, accidental: .sharp), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 4, accidental: .sharp), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .E, octave: 4), duration: .eighth, staff: .treble, position: NotePosition(beat: 2.66)),
            // Bass: Octave C#2 / C#3
            Note(pitch: Pitch(noteName: .C, octave: 2, accidental: .sharp), duration: .whole, staff: .bass, position: NotePosition(beat: 1.0))
        ]
        measures.append(Measure(number: 1, notes: m1Notes, barlineType: .final))
        
        return Score(
            title: "Moonlight Sonata (Op. 27 No. 2)",
            composer: "Ludwig van Beethoven",
            difficulty: .advanced,
            source: .manual,
            isFavorite: true,
            tempo: 54,
            keySignatureValue: 4,
            timeSignatureTop: 4,
            timeSignatureBottom: 4,
            estimatedDuration: 360,
            measures: measures
        )
    }
    
    private func createDefaultPianoMeasures() -> [Measure] {
        return [Measure(number: 1, notes: [
            Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .E, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .quarter, staff: .treble, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .quarter, staff: .treble, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .whole, staff: .bass, position: NotePosition(beat: 1.0))
        ], barlineType: .final)]
    }
}
