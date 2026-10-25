// ImportScoreView.swift
// luksMusic
//
// Sheet / modal for importing musical scores from MusicXML and MIDI files.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Supported UTTypes

extension UTType {
    static let musicXML = UTType(filenameExtension: "musicxml") ?? .xml
    static let mxl = UTType(filenameExtension: "mxl") ?? .data
    static let midi = UTType(mimeType: "audio/midi") ?? .data
}

// MARK: - Import State

/// Phases of the import process.
enum ImportPhase: Equatable {
    case idle
    case loading
    case previewing
    case importing
    case success
    case failure(String)
}

// MARK: - ImportScoreView

/// A modal view for importing musical scores from files.
struct ImportScoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var phase: ImportPhase = .idle
    @State private var selectedURL: URL?
    @State private var detectedFileName = ""

    // Editable metadata
    @State private var title = ""
    @State private var composer = ""
    @State private var difficulty: Difficulty = .beginner

    // Progress
    @State private var importProgress: Double = 0

    // Allowed file types
    private let allowedTypes: [UTType] = [
        .xml,
        .musicXML,
        .mxl,
        .midi,
    ]

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch phase {
                case .idle:
                    fileSelectionView
                case .loading:
                    loadingView
                case .previewing:
                    metadataFormView
                case .importing:
                    importingView
                case .success:
                    successView
                case .failure(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Import Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: allowedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    // MARK: - Phase Views

    /// Initial state: prompt user to pick a file.
    private var fileSelectionView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundStyle(.indigo.opacity(0.5))
                        .frame(width: 200, height: 160)

                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(.indigo)

                        Text("Select a file to import")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Choose File", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Supported formats:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(".xml  ·  .musicxml  ·  .mxl  ·  .mid  ·  .midi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
            Spacer()
        }
    }

    /// Loading / parsing the selected file.
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Reading file…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    /// Metadata editing form before final import.
    private var metadataFormView: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.indigo)
                    Text(detectedFileName)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Selected File")
            }

            Section {
                TextField("Title", text: $title)
                TextField("Composer", text: $composer)
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
            } header: {
                Text("Score Details")
            } footer: {
                Text("You can change these details later.")
            }

            Section {
                Button {
                    performImport()
                } label: {
                    HStack {
                        Spacer()
                        Label("Import Score", systemImage: "arrow.down.doc.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .tint(.indigo)
            }
        }
    }

    /// Importing with progress.
    private var importingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: importProgress) {
                Text("Importing…")
                    .font(.subheadline.weight(.medium))
            } currentValueLabel: {
                Text("\(Int(importProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 60)

            Text(detectedFileName)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    /// Success state.
    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Import Successful!")
                .font(.title3.weight(.semibold))

            Text("\"\(title)\" has been added to your library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.top, 8)

            Spacer()
        }
    }

    /// Error state.
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("Import Failed")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Button("Try Again") {
                    phase = .idle
                    selectedURL = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Logic

    /// Handle file picker result.
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                phase = .failure("No file was selected.")
                return
            }

            selectedURL = url
            detectedFileName = url.lastPathComponent

            // Pre-populate title from filename
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            title = nameWithoutExtension
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")

            phase = .loading

            // Simulate brief parsing delay
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                await MainActor.run {
                    phase = .previewing
                }
            }

        case .failure(let error):
            phase = .failure("Could not open file: \(error.localizedDescription)")
        }
    }

    /// Perform the actual import and create a Score object.
    private func performImport() {
        phase = .importing
        importProgress = 0

        Task {
            guard let url = selectedURL else {
                await MainActor.run {
                    phase = .failure("No file selected.")
                }
                return
            }

            // Start secure access
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            do {
                // Verify file exists and is readable
                guard FileManager.default.isReadableFile(atPath: url.path) else {
                    throw ImportError.fileNotReadable
                }

                // Simulate progressive import
                for step in 1...5 {
                    try await Task.sleep(for: .milliseconds(300))
                    await MainActor.run {
                        importProgress = Double(step) / 5.0
                    }
                }

                // Determine source type
                let ext = url.pathExtension.lowercased()
                let source: ScoreSource = .imported

                // Parse file and create score
                let importedScore = try await ScoreStorageService.shared.importScore(from: url, modelContext: modelContext)
                if !title.isEmpty {
                    importedScore.title = title
                }
                if !composer.isEmpty {
                    importedScore.composer = composer
                }
                importedScore.difficulty = difficulty
                try? modelContext.save()

                await MainActor.run {
                    phase = .success
                }

            } catch {
                await MainActor.run {
                    phase = .failure(importErrorMessage(for: error))
                }
            }
        }
    }

    /// Convert errors to user-friendly messages.
    private func importErrorMessage(for error: Error) -> String {
        if let importError = error as? ImportError {
            return importError.localizedDescription
        }
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
}

// MARK: - Import Errors

/// Errors that can occur during score import.
enum ImportError: LocalizedError {
    case fileNotReadable
    case unsupportedFormat
    case parsingFailed(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .fileNotReadable:
            return "The selected file could not be read. Please check permissions and try again."
        case .unsupportedFormat:
            return "This file format is not supported. Please use MusicXML (.xml, .musicxml, .mxl) or MIDI (.mid, .midi) files."
        case .parsingFailed(let detail):
            return "Failed to parse the file: \(detail)"
        case .invalidData:
            return "The file contains invalid or corrupted data."
        }
    }
}

// MARK: - Preview

#Preview("Import - Idle") {
    ImportScoreView()
        .modelContainer(for: Score.self, inMemory: true)
        .preferredColorScheme(.dark)
}
