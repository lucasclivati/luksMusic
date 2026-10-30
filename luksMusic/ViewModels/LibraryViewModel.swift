// LibraryViewModel.swift
// luksMusic
//
// View model managing score library filtering, sorting, and file imports.

import Foundation
import Observation
import SwiftData

@Observable
final class LibraryViewModel {
    
    var searchText: String = ""
    var selectedDifficulty: Difficulty? = nil
    var selectedSource: ScoreSource? = nil
    var showFavoritesOnly: Bool = false
    var sortOption: LibrarySortOption = .dateCreated
    var sortAscending: Bool = false
    
    var showImportSheet: Bool = false
    var showCreateSheet: Bool = false
    
    private let storageService = ScoreStorageService.shared
    
    func filterScores(_ scores: [Score]) -> [Score] {
        var filtered = scores
        
        // Search text
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.composer.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Favorites
        if showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        // Difficulty
        if let difficulty = selectedDifficulty {
            filtered = filtered.filter { $0.difficulty == difficulty }
        }
        
        // Source
        if let source = selectedSource {
            filtered = filtered.filter { $0.source == source }
        }
        
        // Sort
        filtered.sort { a, b in
            let result: Bool
            switch sortOption {
            case .dateCreated:
                result = a.dateCreated > b.dateCreated
            case .title:
                result = a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .difficulty:
                result = a.difficulty.rawValue < b.difficulty.rawValue
            case .lastPracticed:
                let d1 = a.lastPracticed ?? Date.distantPast
                let d2 = b.lastPracticed ?? Date.distantPast
                result = d1 > d2
            }
            return sortAscending ? !result : result
        }
        
        return filtered
    }
    
    func deleteScore(_ score: Score, modelContext: ModelContext) {
        modelContext.delete(score)
        try? modelContext.save()
    }
    
    func toggleFavorite(_ score: Score, modelContext: ModelContext) {
        score.isFavorite.toggle()
        try? modelContext.save()
    }
}
