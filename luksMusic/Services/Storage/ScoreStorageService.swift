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
                if !hasLyrics || existingDarkDream.measures.count < 9 {
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
        
        // Measure 1: "When my eyes a-wake"
        let m1Notes = [
            // Right Hand (Treble): Accompaniment triplets (G4-C5-Eb5) + Melody (G5)
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, lyric: "When", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "my", isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "eyes", isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "a-wake", isTriplet: true, position: NotePosition(beat: 4.67)),
            
            // Left Hand (Bass): C3 + G3 on beat 1, G3 on 2, C3 on 3, C3 on 4
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 1, notes: m1Notes))
        
        // Measure 2: "Skies start to break"
        let m2Notes = [
            // Right Hand (Treble): Accompaniment triplets + Melody (G5)
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, lyric: "Skies", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "start", isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "to", isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "break", isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "break", isTriplet: true, position: NotePosition(beat: 4.67)),
            
            // Left Hand (Bass): Bb2 + G3 on beat 1, G3 on 2, C3 on 3, C3 on 4
            Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 2, notes: m2Notes))
        
        // Measure 3: "Storms o-ver-take"
        let m3Notes = [
            // Right Hand (Treble): G4+G5 on 1.0, Ab4+Ab5 on 3.0
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, lyric: "Storms", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "o-", isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .A, octave: 5, accidental: .flat), duration: .quarter, staff: .treble, lyric: "-ver-", position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "take", isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            
            // Left Hand (Bass): Ab3 + C4 on beat 1, C4 on 2, F3 on 3, F3 on 4
            Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 3, notes: m3Notes))
        
        // Measure 4: "Clocks cease to shake" (B natural!)
        let m4Notes = [
            // Right Hand (Treble): Ab4+F5 on 1.0, B4 natural on 3.33 & 4.33
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .quarter, staff: .treble, lyric: "Clocks", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "cease", isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "to", isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, lyric: "shake", isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .B, octave: 4, accidental: .natural), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .D, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            Note(pitch: Pitch(noteName: .A, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            
            // Left Hand (Bass): B2 natural + G3 on 1.0, F3 on 2, Eb3 on 3, D3 on 4
            Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .natural), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 4, notes: m4Notes))
        
        // Measure 5: "Home-less for-sake"
        let m5Notes = [
            // Right Hand (Treble)
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, lyric: "Home-", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "-less", isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "for-", isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, lyric: "sake", isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            
            // Left Hand (Bass): C2 + G2 + C3 on 1.0, G3 on 2, D2 + C3 on 3, Eb2 + C3 on 4
            Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .D, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .E, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 5, notes: m5Notes))
        
        // Measure 6: "Dream I'll cre-ate"
        let m6Notes = [
            // Right Hand (Treble)
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, lyric: "Dream", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "I'll", isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "cre-", isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, lyric: "-ate", isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            
            // Left Hand (Bass): Bb1 + F2 + Bb2 on 1.0, G3 on 2, G2 + C3 on 3, C3 on 4
            Note(pitch: Pitch(noteName: .B, octave: 1, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .F, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .B, octave: 2, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 6, notes: m6Notes))
        
        // Measure 7: "Burns to re-make"
        let m7Notes = [
            // Right Hand (Treble)
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .quarter, staff: .treble, lyric: "Burns", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, lyric: "to", isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "re-", isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "make", isTriplet: true, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 4.67)),
            
            // Left Hand (Bass): Eb3 + Ab3 + C4 on 1.0, C4 on 2, F3 + D4 on 3, F3 on 4
            Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .D, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .F, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 7, notes: m7Notes))
        
        // Measure 8: "Craft dic-tates the" + Melodic High Flourish
        let m8Notes = [
            // Right Hand (Treble)
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .quarter, staff: .treble, lyric: "Craft", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 1.67)),
            
            Note(pitch: Pitch(noteName: .A, octave: 4, accidental: .flat), duration: .eighth, staff: .treble, lyric: "dic-", isTriplet: true, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .F, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 2.67)),
            
            Note(pitch: Pitch(noteName: .F, octave: 4), duration: .eighth, staff: .treble, lyric: "-tates", isTriplet: true, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .G, octave: 4), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .eighth, staff: .treble, isTriplet: true, position: NotePosition(beat: 3.67)),
            
            // Rapid high register flourish on beat 4: D6 -> Eb6 -> D6 -> C6 -> [G5 + G6]
            Note(pitch: Pitch(noteName: .D, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .E, octave: 6, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.25)),
            Note(pitch: Pitch(noteName: .D, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.5)),
            Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.75)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .eighth, staff: .treble, position: NotePosition(beat: 4.75)),
            Note(pitch: Pitch(noteName: .G, octave: 6), duration: .eighth, staff: .treble, lyric: "fate", position: NotePosition(beat: 4.75)),
            
            // Left Hand (Bass): G2 + D3 + G3 on 1.0, Ab3 on 2, G2 + D3 + Bb3 on 3, G2 + D3 + C4 on 4
            Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .A, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .B, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .G, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .C, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 8, notes: m8Notes))
        
        // Measure 9: "Fate ... I've made ... Where" (Arpeggios)
        let m9Notes = [
            // Right Hand (Treble): Sextuplet arpeggio waves (C6-G5-Eb5-C5-Eb5-G5)
            Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "Fate...", position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.17)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.33)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.5)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 1.83)),
            
            Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.17)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.33)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.5)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 2.83)),
            
            Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, lyric: "I've made...", position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.17)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.33)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.5)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 3.83)),
            
            Note(pitch: Pitch(noteName: .C, octave: 6), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.17)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.33)),
            Note(pitch: Pitch(noteName: .C, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.5)),
            Note(pitch: Pitch(noteName: .E, octave: 5, accidental: .flat), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.67)),
            Note(pitch: Pitch(noteName: .G, octave: 5), duration: .sixteenth, staff: .treble, position: NotePosition(beat: 4.83)),
            
            // Left Hand (Bass): C3 + G3 + D4 on 1.0, C2 + C3 on 2, C3 + Eb3 + G3 on 3, D2 + D3 on 4
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .D, octave: 4), duration: .quarter, staff: .bass, position: NotePosition(beat: 1.0)),
            Note(pitch: Pitch(noteName: .C, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 2.0)),
            Note(pitch: Pitch(noteName: .C, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .E, octave: 3, accidental: .flat), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .G, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 3.0)),
            Note(pitch: Pitch(noteName: .D, octave: 2), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0)),
            Note(pitch: Pitch(noteName: .D, octave: 3), duration: .quarter, staff: .bass, position: NotePosition(beat: 4.0))
        ]
        measures.append(Measure(number: 9, notes: m9Notes, barlineType: .final))
        
        return Score(
            title: "Dark Dream (Lord of Mysteries ED)",
            composer: "Curley Gao (Arr. 11Minnie11)",
            difficulty: .intermediate,
            source: .manual,
            isFavorite: true,
            tempo: 70,
            keySignatureValue: -3,
            timeSignatureTop: 4,
            timeSignatureBottom: 4,
            estimatedDuration: 180,
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
