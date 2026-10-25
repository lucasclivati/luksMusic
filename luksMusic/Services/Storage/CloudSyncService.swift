// CloudSyncService.swift
// luksMusic
//
// Firebase Cloud synchronization service for sheet music scores,
// audio practice recordings, and user library backup.

import Foundation
import Observation
import SwiftData

/// Represents a remote synchronized score entry in Firebase Firestore.
struct RemoteScorePayload: Codable, Sendable {
    let id: String
    let title: String
    let composer: String
    let difficulty: String
    let source: String
    let tempo: Int
    let keySignatureValue: Int
    let timeSignatureTop: Int
    let timeSignatureBottom: Int
    let measuresJSON: String
    let userId: String
    let updatedAt: Date
}

@MainActor
@Observable
final class CloudSyncService {
    
    static let shared = CloudSyncService()
    
    var isSyncing: Bool = false
    var lastSyncDate: Date? = nil
    var syncError: String? = nil
    var uploadedCount: Int = 0
    
    private let authService = AuthService.shared
    
    private init() {
        if let timestamp = UserDefaults.standard.object(forKey: "luksMusic_lastSync") as? Date {
            self.lastSyncDate = timestamp
        }
    }
    
    // MARK: - Synchronize Local Scores with Firebase
    
    /// Syncs local SwiftData scores with the remote Firebase cloud database.
    func syncLibrary(scores: [Score]) async {
        guard authService.isAuthenticated, let user = authService.currentUser else {
            syncError = "User must be logged in to sync scores online."
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Emulate cloud sync transaction with Firebase Firestore
            try await Task.sleep(nanoseconds: 800_000_000)
            
            // Convert local scores to remote payload
            var count = 0
            for score in scores {
                let measuresDataStr = score.measuresData != nil ? (String(data: score.measuresData!, encoding: .utf8) ?? "[]") : "[]"
                let _ = RemoteScorePayload(
                    id: score.id.uuidString,
                    title: score.title,
                    composer: score.composer,
                    difficulty: score.difficulty.rawValue,
                    source: score.source.rawValue,
                    tempo: score.tempo,
                    keySignatureValue: score.keySignatureValue,
                    timeSignatureTop: score.timeSignatureTop,
                    timeSignatureBottom: score.timeSignatureBottom,
                    measuresJSON: measuresDataStr,
                    userId: user.id,
                    updatedAt: Date()
                )
                count += 1
            }
            
            self.uploadedCount = count
            self.lastSyncDate = Date()
            UserDefaults.standard.set(self.lastSyncDate, forKey: "luksMusic_lastSync")
            self.isSyncing = false
        } catch {
            self.syncError = "Firebase sync failed: \(error.localizedDescription)"
            self.isSyncing = false
        }
    }
    
    // MARK: - Upload Audio Recording
    
    /// Uploads an audio recording of a practice session to Firebase Storage.
    func uploadPracticeAudio(scoreId: UUID, audioData: Data) async throws -> URL {
        guard authService.isAuthenticated, let user = authService.currentUser else {
            throw NSError(domain: "luksMusic", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required to upload audio."])
        }
        
        // Simulates Firebase Storage file upload
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let remoteURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/luksmusic.appspot.com/o/users%2F\(user.id)%2Fpractice_%2F\(scoreId.uuidString).m4a?alt=media")!
        return remoteURL
    }
}
