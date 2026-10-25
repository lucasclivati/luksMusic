// luksMusicApp.swift
// luksMusic
//
// Application entry point with SwiftData container and audio engine setup.

import SwiftUI
import SwiftData

@main
struct luksMusicApp: App {
    
    /// Shared ModelContainer for persistence of Score and PracticeSession models.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Score.self,
            PracticeSession.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
