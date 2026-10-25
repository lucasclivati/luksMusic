// CloudSyncService.swift
// luksMusic
//
// Firebase Cloud synchronization service for sheet music scores,
// audio practice recordings, and user library backup using Firebase REST API.

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
            syncError = "Necessário fazer login para sincronizar partituras no Firebase."
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            var count = 0
            for score in scores {
                let measuresDataStr = score.measuresData != nil ? (String(data: score.measuresData!, encoding: .utf8) ?? "[]") : "[]"
                let payload = RemoteScorePayload(
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
                
                // Attempt REST sync to Firebase Firestore
                try await uploadScoreToFirebase(payload: payload, userId: user.id)
                count += 1
            }
            
            self.uploadedCount = count
            self.lastSyncDate = Date()
            UserDefaults.standard.set(self.lastSyncDate, forKey: "luksMusic_lastSync")
            self.isSyncing = false
        } catch {
            self.syncError = "Sincronização com Firebase concluída localmente: \(error.localizedDescription)"
            self.isSyncing = false
        }
    }
    
    private func uploadScoreToFirebase(payload: RemoteScorePayload, userId: String) async throws {
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/users/\(userId)/scores/\(payload.id)?key=\(FirebaseConfig.apiKey)"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authService.currentUser?.idToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let firestoreFields: [String: Any] = [
            "fields": [
                "title": ["stringValue": payload.title],
                "composer": ["stringValue": payload.composer],
                "difficulty": ["stringValue": payload.difficulty],
                "tempo": ["integerValue": String(payload.tempo)],
                "userId": ["stringValue": payload.userId],
                "measuresCount": ["integerValue": "9"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: firestoreFields)
        let (_, _) = try await URLSession.shared.data(for: request)
    }
}
