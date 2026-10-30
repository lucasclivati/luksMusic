// ScoreView.swift
// luksMusic
//
// Sheet music viewer for the scores saved on the device: the engraving by OpenSheetMusicDisplay (ScoreWebView)
// on a sheet of paper in the shared player frame, with a cursor that steps note by note, the dock below it
// (timeline, transport, notes under the cursor, keyboard) and the score's actions in the title bar's menu.

import SwiftUI

struct ScoreView: View {
    @State var viewModel: ScoreViewModel
    @State private var showPracticeMode: Bool = false
    @State private var showEditorMode: Bool = false
    @State private var showMixerSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showExportShare: Bool = false
    @State private var exportURL: URL? = nil
    @Environment(\.dismiss) private var dismiss

    // Engraved score source, rebuilt when the score is edited
    @State private var musicXML: String = ""

    // Zoom of the engraving (below 0.95 fits two measures per line)
    @State private var zoomScale: Double = 1.0

    // Display settings
    @State private var displayMode: ScoreDisplayMode = .portraitView
    @State private var hqSoundEnabled: Bool = true
    @State private var showKeyboard: Bool = true
    @State private var isFavorite: Bool = false

    private static let zoomLevels: [Double] = [0.8, 1.0, 1.15, 1.3]

    init(score: Score) {
        _viewModel = State(initialValue: ScoreViewModel(score: score))
        _isFavorite = State(initialValue: score.isFavorite)
    }

    /// "Página" fits two measures per line; "Ampliada" shows one larger measure per line.
    private var renderZoom: Double {
        zoomScale * (displayMode == .verticalScroll ? 0.8 : 1.0)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !viewModel.score.composer.isEmpty {
            parts.append(viewModel.score.composer)
        }
        parts.append("\(viewModel.score.tempo) BPM")
        parts.append("\(viewModel.score.measureCount) compassos")
        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(spacing: 0) {
            PlayerTopBar(title: viewModel.score.title, subtitle: subtitle, onBack: close) {
                Button {
                    viewModel.score.isFavorite.toggle()
                    isFavorite = viewModel.score.isFavorite
                } label: {
                    PlayerMenuLabel(systemName: isFavorite ? "heart.fill" : "heart",
                                    tint: isFavorite ? Color(red: 244 / 255, green: 63 / 255, blue: 94 / 255) : PlayerTheme.text)
                }
                .accessibilityLabel(isFavorite ? "Remover dos favoritos" : "Adicionar aos favoritos")

                menu
            }

            ScoreWebView(
                title: viewModel.score.title,
                composer: viewModel.score.composer,
                musicXML: musicXML,
                measureIndex: viewModel.currentMeasureIndex,
                cursorBeat: viewModel.cursorBeat,
                zoom: renderZoom,
                transposition: viewModel.transpositionSemitones,
                horizontal: displayMode == .singleLine,
                isDark: true,
                topInset: 0,
                bottomInset: 16
            ) { measure, beat in
                viewModel.seek(toMeasure: measure, beat: beat)
            }

            PlayerDock(viewModel: viewModel, showKeyboard: $showKeyboard) {
                showMixerSheet = true
            }
        }
        .background(PlayerTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            musicXML = MusicXMLExporter.export(viewModel.score)
        }
        .onChange(of: viewModel.score.lastModified) { _, _ in
            musicXML = MusicXMLExporter.export(viewModel.score)
        }
        .onChange(of: viewModel.transpositionSemitones) { _, _ in
            viewModel.refreshActiveNotes()
        }
        .sheet(isPresented: $showPracticeMode) {
            PracticeView(score: viewModel.score)
        }
        .sheet(isPresented: $showEditorMode) {
            EditorView(score: viewModel.score)
        }
        .sheet(isPresented: $showMixerSheet) {
            HandsMixerSheet(viewModel: viewModel)
                .presentationDetents([.fraction(0.42)])
        }
        .sheet(isPresented: $showSettingsSheet) {
            ScoreSettingsView(
                viewModel: viewModel,
                displayMode: $displayMode,
                hqSoundEnabled: $hqSoundEnabled,
                showKeyboard: $showKeyboard
            )
            .presentationDetents([.fraction(0.7)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Menu

    private var menu: some View {
        Menu {
            Section {
                Button {
                    viewModel.pause()
                    showPracticeMode = true
                } label: {
                    Label("Modo Estudo", systemImage: "graduationcap")
                }
                .accessibilityIdentifier("menuPracticeButton")

                Button {
                    showMixerSheet = true
                } label: {
                    Label("Mixer de mãos", systemImage: "slider.vertical.3")
                }
                .accessibilityIdentifier("menuMixerButton")

                Button {
                    showSettingsSheet = true
                } label: {
                    Label("Configurações", systemImage: "gearshape")
                }
                .accessibilityIdentifier("menuSettingsButton")
            }

            Picker(selection: $zoomScale) {
                ForEach(Self.zoomLevels, id: \.self) { level in
                    Text("\(Int(level * 100))%").tag(level)
                }
            } label: {
                Label("Zoom", systemImage: "plus.magnifyingglass")
            }
            .pickerStyle(.menu)

            Section {
                Button {
                    viewModel.pause()
                    showEditorMode = true
                } label: {
                    Label("Editar partitura", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier("menuEditButton")

                Button {
                    exportScore()
                } label: {
                    Label("Exportar MusicXML", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("menuExportButton")
            }
        } label: {
            PlayerMenuLabel()
        }
        .accessibilityLabel("Opções da partitura")
        .accessibilityIdentifier("scoreMenuButton")
    }

    private func close() {
        viewModel.stop()
        dismiss()
    }

    private func exportScore() {
        if let url = try? ScoreStorageService.shared.exportScoreAsMusicXML(viewModel.score) {
            exportURL = url
            showExportShare = true
        }
    }
}

/// UIActivityViewController wrapper for file sharing
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
