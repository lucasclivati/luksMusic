// ContentView.swift
// luksMusic
//
// Root navigation container with Google Auth gating, Firebase Sync, and TabView.

import SwiftUI
import SwiftData

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
                    Label("Library", systemImage: "music.note.list")
                }
                .tag(0)
            
            // Tab 2: Scanner (OMR)
            ScannerView()
                .tabItem {
                    Label("Scanner", systemImage: "camera.viewfinder")
                }
                .tag(1)
            
            // Tab 3: History & Stats
            PracticeHistoryView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.xaxis")
                }
                .tag(2)
            
            // Tab 4: Settings & Cloud Sync
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
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
                        Text("No Practice Sessions Yet")
                            .font(.headline)
                        Text("Open any score in the library or scan a sheet to begin training!")
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
                    
                    Section("Recent Sessions") {
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
                                    Text("\(session.practiceMode.displayName) • \(session.totalNotesPlayed) notes")
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
            .navigationTitle("Practice Progress")
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
                Text("Sessions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f%%", avgAccuracy))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("Avg Accuracy")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("\(maxStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("Max Streak")
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
    @State private var selectedSoundFont = "Concert Grand Piano"
    @State private var keyboardOctaves = 3
    @State private var showNoteLabels = true
    @State private var hapticFeedbackEnabled = true
    
    var body: some View {
        NavigationStack {
            Form {
                // User Account / Google Login Section
                Section("Account & Firebase Cloud") {
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
                        
                        // Sync Button
                        Button {
                            Task {
                                await cloudSync.syncLibrary(scores: scores)
                            }
                        } label: {
                            HStack {
                                Label("Sync Scores to Firebase", systemImage: "arrow.triangle.2.circlepath")
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
                        
                        HStack {
                            Text("Projeto Firebase:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(FirebaseConfig.projectId)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            authService.signOut()
                        }
                    } else {
                        Button("Sign in with Google") {
                            Task {
                                await authService.signInWithGoogle()
                            }
                        }
                    }
                }
                
                Section("Piano Audio Engine") {
                    Picker("Sound Instrument", selection: $selectedSoundFont) {
                        Text("Concert Grand Piano (Steinway)").tag("Concert Grand Piano")
                        Text("Upright Acoustic Piano").tag("Upright Acoustic Piano")
                        Text("Electric Grand (CP80)").tag("Electric Grand (CP80)")
                        Text("Rhodes Vintage Piano").tag("Rhodes Vintage Piano")
                    }
                }
                
                Section("Interactive Piano Keyboard") {
                    Stepper("Keyboard Range: \(keyboardOctaves) Octaves", value: $keyboardOctaves, in: 2...5)
                    Toggle("Show Note Names on Keys", isOn: $showNoteLabels)
                    Toggle("Haptic Touch Feedback", isOn: $hapticFeedbackEnabled)
                }
                
                Section("External MIDI Connection") {
                    HStack {
                        Image(systemName: "pianokeys")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CoreMIDI Status")
                                .font(.subheadline)
                            Text(MIDIService.shared.isDeviceConnected ? "Connected" : "No external MIDI device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (MuseScore Piano Companion)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Cloud Backend")
                        Spacer()
                        Text("Google Firebase Enabled")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
