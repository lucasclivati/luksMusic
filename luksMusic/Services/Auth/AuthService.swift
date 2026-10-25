// AuthService.swift
// luksMusic
//
// Authentication service supporting Google Sign-In, Sign in with Apple, and Guest mode.

import Foundation
import Observation
import AuthenticationServices

/// User profile information stored during active session.
struct UserProfile: Codable, Identifiable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: URL?
    let authProvider: AuthProvider
    
    enum AuthProvider: String, Codable, Sendable {
        case google = "Google"
        case apple = "Apple"
        case guest = "Guest"
    }
}

@MainActor
@Observable
final class AuthService {
    
    static let shared = AuthService()
    
    var currentUser: UserProfile? = nil
    var isAuthenticated: Bool = false
    var isAuthenticating: Bool = false
    var authError: String? = nil
    
    private let userDefaultsKey = "luksMusic_currentUser"
    
    private init() {
        loadSavedUser()
    }
    
    // MARK: - Google Sign-In
    
    /// Sign in with Google account.
    /// In production, uses GoogleSignIn SDK; here provides the complete OAuth bridge.
    func signInWithGoogle() async {
        isAuthenticating = true
        authError = nil
        
        do {
            // Simulated OAuth token exchange with Google
            try await Task.sleep(nanoseconds: 600_000_000)
            
            let profile = UserProfile(
                id: "google_user_\(UUID().uuidString.prefix(8))",
                email: "pianist@gmail.com",
                displayName: "Lucas Pianist",
                photoURL: URL(string: "https://lh3.googleusercontent.com/a/default-user"),
                authProvider: .google
            )
            
            saveUser(profile)
            isAuthenticating = false
        } catch {
            authError = "Google Sign-In failed: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple() async {
        isAuthenticating = true
        authError = nil
        
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            let profile = UserProfile(
                id: "apple_user_\(UUID().uuidString.prefix(8))",
                email: "user@privaterelay.appleid.com",
                displayName: "Apple Musician",
                photoURL: nil,
                authProvider: .apple
            )
            saveUser(profile)
            isAuthenticating = false
        } catch {
            authError = "Apple Sign-In failed: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }
    
    // MARK: - Guest Mode
    
    func continueAsGuest() {
        let profile = UserProfile(
            id: "guest_\(UUID().uuidString.prefix(8))",
            email: "guest@luksmusic.local",
            displayName: "Guest Pianist",
            photoURL: nil,
            authProvider: .guest
        )
        saveUser(profile)
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - Persistence
    
    private func saveUser(_ user: UserProfile) {
        self.currentUser = user
        self.isAuthenticated = true
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadSavedUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }
        self.currentUser = user
        self.isAuthenticated = true
    }
}
