// ContentView.swift
// luksMusic
//
// Root navigation container with Google Auth gating, Firebase Sync, and TabView.

import SwiftUI
import SwiftData
import AuthenticationServices

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var scores: [Score]
    
    @State private var authService = AuthService.shared
    @State private var cloudSync = CloudSyncService.shared
    @State private var selectedTab: Int = 0
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                mainTabView
            } else {
                LoginView()
            }
        }
        .onAppear {
            ScoreStorageService.shared.preloadSampleScoresIfNeeded(modelContext: modelContext)
            AudioEngineService.shared.setupEngine()
            MIDIService.shared.startListening()
        }
    }
    
    @ViewBuilder
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Library
            LibraryView()
                .tabItem {
                    Label("Biblioteca", systemImage: "music.note.list")
                }
                .tag(0)
            
            // Tab 3: History & Stats
            PracticeHistoryView()
                .tabItem {
                    Label("Progresso", systemImage: "chart.bar.xaxis")
                }
                .tag(2)
            
            // Tab 4: Settings & Cloud Sync
            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(.accentColor)
    }
}

// MARK: - Practice History Tab

struct PracticeHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.startTime, order: .reverse) private var sessions: [PracticeSession]
    
    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "pianokeys")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("Nenhum estudo registrado ainda")
                            .font(.headline)
                        Text("Abra uma partitura e toque em Modo Estudo para começar a treinar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        summaryStatsCard()
                    }
                    
                    Section("Estudos recentes") {
                        ForEach(sessions) { session in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(session.accuracy / 100.0))
                                        .stroke(session.accuracy >= 80 ? Color.green : Color.orange, lineWidth: 4)
                                        .rotationEffect(.degrees(-90))
                                    Text(String(format: "%.0f%%", session.accuracy))
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .frame(width: 36, height: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.scoreTitle)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("\(session.practiceMode.displayName) • \(session.totalNotesPlayed) notas")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(session.startTime, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Progresso")
        }
    }
    
    @ViewBuilder
    private func summaryStatsCard() -> some View {
        HStack(spacing: 16) {
            let avgAccuracy = sessions.isEmpty ? 0.0 : (sessions.reduce(0.0) { $0 + $1.accuracy } / Double(sessions.count))
            let maxStreak = sessions.reduce(0) { max($0, $1.longestStreak) }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(sessions.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Estudos")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f%%", avgAccuracy))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("Precisão média")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("\(maxStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("Maior sequência")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Settings Tab

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var scores: [Score]
    
    @State private var authService = AuthService.shared
    @State private var cloudSync = CloudSyncService.shared
    @State private var showDeleteAccount = false

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // User Account / Google Login Section
                Section("Conta e nuvem") {
                    if let user = authService.currentUser {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(user.displayName.prefix(1)))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text("\(user.email) (\(user.authProvider.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Sync needs a cloud account; guests keep everything on the device
                        if user.authProvider != .guest {
                            Button {
                                Task {
                                    await cloudSync.syncLibrary(scores: scores)
                                }
                            } label: {
                                HStack {
                                    Label("Sincronizar partituras na nuvem", systemImage: "arrow.triangle.2.circlepath")
                                    Spacer()
                                    if cloudSync.isSyncing {
                                        ProgressView()
                                    } else if let lastSync = cloudSync.lastSyncDate {
                                        Text(lastSync, format: .dateTime.hour().minute())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            if let syncError = cloudSync.syncError {
                                Text(syncError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Button("Sair da conta", role: .destructive) {
                            authService.signOut()
                        }

                        if user.authProvider != .guest {
                            Button("Excluir conta", role: .destructive) {
                                authService.authError = nil
                                showDeleteAccount = true
                            }
                        }
                    } else {
                        Button("Entrar com Google") {
                            Task {
                                await authService.signInWithGoogle()
                            }
                        }
                    }
                }
                
                Section("Teclado MIDI externo") {
                    HStack {
                        Image(systemName: "pianokeys")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conexão MIDI")
                                .font(.subheadline)
                            Text(MIDIService.shared.isDeviceConnected ? "Conectado" : "Nenhum teclado MIDI conectado")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Sobre") {
                    HStack {
                        Text("Versão do app")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Ajustes")
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
        }
    }
}

// MARK: - Account Deletion

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Sua conta e as partituras sincronizadas na nuvem serão apagadas permanentemente. As partituras salvas neste aparelho continuam disponíveis no modo convidado.")
                        .font(.subheadline)
                }

                if let user = authService.currentUser {
                    Section("Confirme sua identidade") {
                        switch user.authProvider {
                        case .email:
                            SecureField("Senha de \(user.email)", text: $password)
                                .textContentType(.password)
                            Button("Excluir Conta Permanentemente", role: .destructive) {
                                delete(.password(password))
                            }
                            .disabled(password.isEmpty || authService.isAuthenticating)
                        case .google:
                            Button("Confirmar com Google e Excluir", role: .destructive) {
                                delete(.google)
                            }
                            .disabled(authService.isAuthenticating)
                        case .apple:
                            SignInWithAppleButton(.continue) { request in
                                authService.prepareAppleRequest(request)
                            } onCompletion: { result in
                                if case .success(let authorization) = result {
                                    delete(.apple(authorization))
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 44)
                            .disabled(authService.isAuthenticating)
                        case .guest:
                            EmptyView()
                        }
                    }
                }

                if authService.isAuthenticating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                if let error = authService.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Excluir Conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func delete(_ reauthentication: AuthService.Reauthentication) {
        Task {
            if await authService.deleteAccount(reauthentication) {
                dismiss()
            }
        }
    }
}
