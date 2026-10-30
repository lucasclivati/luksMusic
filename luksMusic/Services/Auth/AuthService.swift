// AuthService.swift
// luksMusic
//
// Real Firebase Authentication service supporting Google Sign-In via OAuth 2.0,
// Firebase Email/Password Auth, Sign in with Apple, Guest mode, and account deletion.

import Foundation
import Observation
import AuthenticationServices
import CryptoKit
import UIKit

/// User profile information stored during active session.
struct UserProfile: Codable, Identifiable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: URL?
    let authProvider: AuthProvider
    var idToken: String?
    var refreshToken: String?
    
    enum AuthProvider: String, Codable, Sendable {
        case google = "Google"
        case email = "E-mail"
        case apple = "Apple"
        case guest = "Guest"
    }
}

/// Firebase Project Configuration constants
struct FirebaseConfig {
    static let apiKey = "AIzaSyAT2rggY4Kd5bzHbB56KdAyl0jhU894344"
    static let projectId = "luksmusic-5a7ff"
    static let clientId = "623234251480-i68t2l0dlq37pm94ib5fadsuhkkr05vo.apps.googleusercontent.com"
    static let reversedClientId = "com.googleusercontent.apps.623234251480-i68t2l0dlq37pm94ib5fadsuhkkr05vo"
}

@MainActor
final class AuthenticationPresentationAnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationPresentationAnchorProvider()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
            if let window = scene.windows.first {
                return window
            }
        }
        return ASPresentationAnchor()
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
    private var webAuthSession: ASWebAuthenticationSession?
    
    private init() {
        loadSavedUser()
    }
    
    // MARK: - Google Sign-In via OAuth 2.0 + Firebase Auth
    
    /// Starts Google Sign-In flow using ASWebAuthenticationSession and exchanges token with Firebase.
    func signInWithGoogle() async {
        isAuthenticating = true
        authError = nil
        
        do {
            let authCode = try await startGoogleOAuthFlow()
            let (googleIdToken, _) = try await exchangeGoogleAuthCode(authCode)
            let profile = try await exchangeGoogleTokenWithFirebase(googleIdToken: googleIdToken)
            
            saveUser(profile)
            isAuthenticating = false
        } catch {
            authError = "Falha no login com Google: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }
    
    private func startGoogleOAuthFlow() async throws -> String {
        let redirectURI = "\(FirebaseConfig.reversedClientId):/oauth2redirect"
        let scope = "openid%20profile%20email"
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(FirebaseConfig.clientId)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope)"
        
        guard let authURL = URL(string: authURLString) else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL de autenticação inválida"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: FirebaseConfig.reversedClientId) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: NSError(domain: "luksMusic", code: 401, userInfo: [NSLocalizedDescriptionKey: "Código de autorização não recebido"]))
                    return
                }
                
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = AuthenticationPresentationAnchorProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }
    }
    
    private func exchangeGoogleAuthCode(_ code: String) async throws -> (idToken: String, accessToken: String) {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL de token inválida"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let redirectURI = "\(FirebaseConfig.reversedClientId):/oauth2redirect"
        let bodyParams = "code=\(code)&client_id=\(FirebaseConfig.clientId)&redirect_uri=\(redirectURI)&grant_type=authorization_code"
        request.httpBody = bodyParams.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "Falha na troca de token Google: \(errorText)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "id_token não encontrado no payload do Google"])
        }
        
        let accessToken = json["access_token"] as? String ?? ""
        return (idToken, accessToken)
    }
    
    private func exchangeGoogleTokenWithFirebase(googleIdToken: String) async throws -> UserProfile {
        let endpoint = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(FirebaseConfig.apiKey)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL do Firebase inválida"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "postBody": "id_token=\(googleIdToken)&providerId=google.com",
            "requestUri": "http://localhost",
            "returnIdpCredential": true,
            "returnSecureToken": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "Falha no Firebase Sign-In: \(errorText)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "Resposta inválida do Firebase"])
        }
        
        let localId = json["localId"] as? String ?? UUID().uuidString
        let email = json["email"] as? String ?? ""
        let displayName = json["displayName"] as? String ?? email.components(separatedBy: "@").first?.capitalized ?? "Pianista"
        let photoURLStr = json["photoUrl"] as? String
        let idToken = json["idToken"] as? String
        let refreshToken = json["refreshToken"] as? String
        
        return UserProfile(
            id: localId,
            email: email,
            displayName: displayName,
            photoURL: photoURLStr != nil ? URL(string: photoURLStr!) : nil,
            authProvider: .google,
            idToken: idToken,
            refreshToken: refreshToken
        )
    }
    
    // MARK: - Firebase Email / Password Authentication
    
    /// Sign in or auto sign up with Email and Password using Firebase Auth REST API.
    func signInWithEmail(email: String, password: String) async {
        isAuthenticating = true
        authError = nil
        
        do {
            let profile = try await performFirebaseEmailAuth(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            saveUser(profile)
            isAuthenticating = false
        } catch {
            authError = "Erro de autenticação: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }
    
    private func performFirebaseEmailAuth(email: String, password: String) async throws -> UserProfile {
        // First try signInWithPassword
        let signInEndpoint = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(FirebaseConfig.apiKey)"
        guard let signInURL = URL(string: signInEndpoint) else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL inválida"])
        }
        
        var request = URLRequest(url: signInURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let localId = json["localId"] as? String ?? UUID().uuidString
                let email = json["email"] as? String ?? email
                let displayName = json["displayName"] as? String ?? email.components(separatedBy: "@").first?.capitalized ?? "Pianista"
                let idToken = json["idToken"] as? String
                let refreshToken = json["refreshToken"] as? String
                
                return UserProfile(
                    id: localId,
                    email: email,
                    displayName: displayName,
                    photoURL: nil,
                    authProvider: .email,
                    idToken: idToken,
                    refreshToken: refreshToken
                )
            }
        }
        
        // If signIn failed, check if user needs to be registered (signUp)
        let signUpEndpoint = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(FirebaseConfig.apiKey)"
        guard let signUpURL = URL(string: signUpEndpoint) else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL inválida"])
        }
        
        var signUpReq = URLRequest(url: signUpURL)
        signUpReq.httpMethod = "POST"
        signUpReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        signUpReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (signData, signResp) = try await URLSession.shared.data(for: signUpReq)
        if let httpResp = signResp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            if let json = try? JSONSerialization.jsonObject(with: signData) as? [String: Any] {
                let localId = json["localId"] as? String ?? UUID().uuidString
                let email = json["email"] as? String ?? email
                let displayName = email.components(separatedBy: "@").first?.capitalized ?? "Pianista"
                let idToken = json["idToken"] as? String
                let refreshToken = json["refreshToken"] as? String
                
                return UserProfile(
                    id: localId,
                    email: email,
                    displayName: displayName,
                    photoURL: nil,
                    authProvider: .email,
                    idToken: idToken,
                    refreshToken: refreshToken
                )
            }
        }
        
        // If both failed, parse error message
        let errorJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
        let message = errorJson?["message"] as? String ?? "Credenciais inválidas"
        throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    // MARK: - Sign in with Apple

    /// Raw nonce for the pending Apple request; Apple receives its SHA-256 and Firebase checks the raw value.
    private var currentAppleNonce: String?

    /// Configures a `SignInWithAppleButton` request (used for sign-in and for confirming account deletion).
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func signInWithApple(_ result: Result<ASAuthorization, Error>) async {
        authError = nil
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                authError = "Falha no Sign in with Apple: \(error.localizedDescription)"
            }
        case .success(let authorization):
            isAuthenticating = true
            do {
                let profile = try await exchangeAppleAuthorizationWithFirebase(authorization)
                saveUser(profile)
            } catch {
                authError = "Falha no Sign in with Apple: \(error.localizedDescription)"
            }
            isAuthenticating = false
        }
    }

    private func exchangeAppleAuthorizationWithFirebase(_ authorization: ASAuthorization) async throws -> UserProfile {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let appleIdToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentAppleNonce else {
            throw NSError(domain: "luksMusic", code: 401, userInfo: [NSLocalizedDescriptionKey: "Credencial da Apple inválida"])
        }

        let json = try await postIdentityToolkit("v1/accounts:signInWithIdp", body: [
            "postBody": "id_token=\(appleIdToken)&providerId=apple.com&nonce=\(nonce)",
            "requestUri": "http://localhost",
            "returnSecureToken": true
        ])
        guard let localId = json["localId"] as? String else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "Resposta inválida do Firebase"])
        }

        // Apple only sends the name on the first authorization, so keep it on the Firebase profile.
        let appleName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = json["email"] as? String ?? credential.email ?? ""
        let idToken = json["idToken"] as? String
        var displayName = json["displayName"] as? String
        if displayName == nil, !appleName.isEmpty, let idToken {
            _ = try? await postIdentityToolkit("v1/accounts:update", body: ["idToken": idToken, "displayName": appleName])
            displayName = appleName
        }

        return UserProfile(
            id: localId,
            email: email,
            displayName: displayName ?? email.components(separatedBy: "@").first?.capitalized ?? "Pianista",
            photoURL: nil,
            authProvider: .apple,
            idToken: idToken,
            refreshToken: json["refreshToken"] as? String
        )
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Guest Mode
    
    func continueAsGuest() {
        let profile = UserProfile(
            id: "guest_\(UUID().uuidString.prefix(8))",
            email: "guest@luksmusic.local",
            displayName: "Convidado Local",
            photoURL: nil,
            authProvider: .guest
        )
        saveUser(profile)
    }
    
    // MARK: - Account Deletion

    /// How the user confirms their identity before deletion; Firebase only deletes accounts with a recent sign-in.
    enum Reauthentication {
        case password(String)
        case google
        case apple(ASAuthorization)
    }

    /// Deletes the user's cloud data and Firebase account, then signs out. Returns false and sets `authError` on failure.
    func deleteAccount(_ reauthentication: Reauthentication) async -> Bool {
        guard let user = currentUser else { return false }
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        do {
            let confirmed: UserProfile
            var appleAuthorizationCode: String?
            switch reauthentication {
            case .password(let password):
                confirmed = try await signInWithPassword(email: user.email, password: password)
            case .google:
                let authCode = try await startGoogleOAuthFlow()
                let (googleIdToken, _) = try await exchangeGoogleAuthCode(authCode)
                confirmed = try await exchangeGoogleTokenWithFirebase(googleIdToken: googleIdToken)
            case .apple(let authorization):
                confirmed = try await exchangeAppleAuthorizationWithFirebase(authorization)
                appleAuthorizationCode = (authorization.credential as? ASAuthorizationAppleIDCredential)?
                    .authorizationCode
                    .flatMap { String(data: $0, encoding: .utf8) }
            }

            guard confirmed.id == user.id, let idToken = confirmed.idToken else {
                throw NSError(domain: "luksMusic", code: 403, userInfo: [NSLocalizedDescriptionKey: "Confirme com a mesma conta que está conectada."])
            }

            try await CloudSyncService.shared.deleteRemoteData(userId: user.id, idToken: idToken)
            if let appleAuthorizationCode {
                await revokeAppleToken(authorizationCode: appleAuthorizationCode, idToken: idToken)
            }
            try await postIdentityToolkit("v1/accounts:delete", body: ["idToken": idToken])

            CloudSyncService.shared.resetSyncState()
            signOut()
            return true
        } catch {
            authError = "Não foi possível excluir a conta: \(error.localizedDescription)"
            return false
        }
    }

    private func signInWithPassword(email: String, password: String) async throws -> UserProfile {
        let json = try await postIdentityToolkit("v1/accounts:signInWithPassword", body: [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ])
        return UserProfile(
            id: json["localId"] as? String ?? "",
            email: email,
            displayName: json["displayName"] as? String ?? email,
            photoURL: nil,
            authProvider: .email,
            idToken: json["idToken"] as? String,
            refreshToken: json["refreshToken"] as? String
        )
    }

    /// Asks Firebase to revoke the Apple tokens (Apple requires it when an account is deleted).
    /// Only works once the Apple provider's key is configured in Firebase, so a failure doesn't block deletion.
    private func revokeAppleToken(authorizationCode: String, idToken: String) async {
        _ = try? await postIdentityToolkit("v2/accounts:revokeToken", body: [
            "providerId": "apple.com",
            "tokenType": "CODE",
            "token": authorizationCode,
            "idToken": idToken
        ])
    }

    @discardableResult
    private func postIdentityToolkit(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/\(path)?key=\(FirebaseConfig.apiKey)") else {
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL inválida"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Erro desconhecido"
            throw NSError(domain: "luksMusic", code: 400, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return json
    }

    // MARK: - Sign Out
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - Persistence & Migration
    
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
        
        // Purge old mock users (including the placeholder Apple login from early builds)
        if user.email == "pianist@gmail.com" || user.id.hasPrefix("apple_user_") {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            self.currentUser = nil
            self.isAuthenticated = false
            return
        }
        
        self.currentUser = user
        self.isAuthenticated = true
    }
}
