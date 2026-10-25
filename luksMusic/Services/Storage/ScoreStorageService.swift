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
    
    /// Preloads classic piano pieces into SwiftData if library is empty.
    func preloadSampleScoresIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Score>()
        let existingScores = (try? modelContext.fetch(descriptor)) ?? []
        guard existingScores.isEmpty else { return }
        
        let samplePieces = [
            createFurElise(),
            createMinuetInG(),
            createGymnopedieNo1(),
            createMoonlightSonata()
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
