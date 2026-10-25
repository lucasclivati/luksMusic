// ScannerViewModel.swift
// luksMusic
//
// View model managing optical music recognition (OMR), camera input, and scan results.

import Foundation
import Observation
import UIKit
import SwiftData

/// The state of the OCR scanning pipeline.
enum ScanStatus: Equatable {
    case idle
    case capturing
    case processing(step: String)
    case success(ScanResult)
    case failure(String)
    
    static func == (lhs: ScanStatus, rhs: ScanStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.capturing, .capturing): return true
        case (.processing(let a), .processing(let b)): return a == b
        case (.success, .success): return true
        case (.failure(let a), .failure(let b)): return a == b
        default: return false
        }
    }
}

@Observable
final class ScannerViewModel {
    
    // MARK: - State Properties
    
    var status: ScanStatus = .idle
    var selectedImage: UIImage? = nil
    var showCamera: Bool = false
    var showPhotoPicker: Bool = false
    var showScanResult: Bool = false
    
    // Editable metadata for scanned score
    var editedTitle: String = ""
    var editedComposer: String = ""
    var editedTempo: Int = 100
    var editedDifficulty: Difficulty = .intermediate
    
    private let ocrService = MusicOCRService.shared
    
    // MARK: - Actions
    
    /// Process the captured or selected image through the OCR pipeline.
    func processImage(_ image: UIImage) {
        self.selectedImage = image
        self.status = .processing(step: "Enhancing image contrast...")
        
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                self.status = .processing(step: "Detecting staff lines & clefs...")
                
                try await Task.sleep(nanoseconds: 300_000_000)
                self.status = .processing(step: "Recognizing notes & barlines...")
                
                let result = try await self.ocrService.recognizeMusic(from: image)
                
                self.editedTitle = result.score.title
                self.editedComposer = result.score.composer
                self.editedTempo = result.score.tempo
                self.editedDifficulty = result.score.difficulty
                
                self.status = .success(result)
                self.showScanResult = true
            } catch {
                self.status = .failure(error.localizedDescription)
            }
        }
    }
    
    /// Save the scanned score into the user's SwiftData library.
    func saveScannedScore(modelContext: ModelContext) -> Score? {
        guard case .success(let result) = status else { return nil }
        
        let score = result.score
        score.title = editedTitle.isEmpty ? "Scanned Score" : editedTitle
        score.composer = editedComposer.isEmpty ? "Unknown" : editedComposer
        score.tempo = editedTempo
        score.difficulty = editedDifficulty
        score.thumbnailData = selectedImage?.jpegData(compressionQuality: 0.6)
        
        modelContext.insert(score)
        try? modelContext.save()
        
        reset()
        return score
    }
    
    func reset() {
        status = .idle
        selectedImage = nil
        showScanResult = false
        editedTitle = ""
        editedComposer = ""
    }
}
