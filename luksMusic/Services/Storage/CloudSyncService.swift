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
    let measureCount: Int
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
        guard let user = authService.currentUser, user.authProvider != .guest else {
            syncError = "Entre com sua conta para sincronizar as partituras."
            return
        }

        isSyncing = true
        syncError = nil

        do {
            let idToken = try await authService.freshIdToken()
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
                    measureCount: score.measureCount,
                    userId: user.id,
                    updatedAt: Date()
                )
                
                try await uploadScoreToFirebase(payload: payload, userId: user.id, idToken: idToken)
                count += 1
            }
            
            self.uploadedCount = count
            self.lastSyncDate = Date()
            UserDefaults.standard.set(self.lastSyncDate, forKey: "luksMusic_lastSync")
            self.isSyncing = false
        } catch {
            self.syncError = "Não foi possível sincronizar: \(error.localizedDescription)"
            self.isSyncing = false
        }
    }
    
    private func uploadScoreToFirebase(payload: RemoteScorePayload, userId: String, idToken: String) async throws {
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/users/\(userId)/scores/\(payload.id)?key=\(FirebaseConfig.apiKey)"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let firestoreFields: [String: Any] = [
            "fields": [
                "title": ["stringValue": payload.title],
                "composer": ["stringValue": payload.composer],
                "difficulty": ["stringValue": payload.difficulty],
                "tempo": ["integerValue": String(payload.tempo)],
                "userId": ["stringValue": payload.userId],
                "measuresCount": ["integerValue": String(payload.measureCount)]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: firestoreFields)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
    }
    
    // MARK: - Account Deletion
    
    /// Deletes every score the user synced to Firestore, then the user document itself.
    func deleteRemoteData(userId: String, idToken: String) async throws {
        let documentsURL = "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents"
        var pageToken: String? = nil
        repeat {
            guard var components = URLComponents(string: "\(documentsURL)/users/\(userId)/scores") else { return }
            components.queryItems = [URLQueryItem(name: "pageSize", value: "300"), URLQueryItem(name: "mask.fieldPaths", value: "title")]
            if let pageToken {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            guard let listURL = components.url else { return }
            
            let page = try await firestoreRequest(listURL, method: "GET", idToken: idToken)
            for document in page["documents"] as? [[String: Any]] ?? [] {
                if let name = document["name"] as? String, let url = URL(string: "https://firestore.googleapis.com/v1/\(name)") {
                    try await firestoreRequest(url, method: "DELETE", idToken: idToken)
                }
            }
            pageToken = page["nextPageToken"] as? String
        } while pageToken != nil
        
        if let userURL = URL(string: "\(documentsURL)/users/\(userId)") {
            try await firestoreRequest(userURL, method: "DELETE", idToken: idToken)
        }
    }
    
    func resetSyncState() {
        lastSyncDate = nil
        uploadedCount = 0
        syncError = nil
        UserDefaults.standard.removeObject(forKey: "luksMusic_lastSync")
    }
    
    @discardableResult
    private func firestoreRequest(_ url: URL, method: String, idToken: String) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "Falha ao apagar dados na nuvem: \(errorText)"])
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
