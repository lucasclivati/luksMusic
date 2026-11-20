// ScoreView.swift
// luksMusic
//
// Sheet music viewer for the scores saved on the device: the engraving by OpenSheetMusicDisplay (ScoreWebView)
// on a sheet of paper in the shared player frame, with a cursor that steps note by note, the dock below it
// (timeline, transport, notes under the cursor, keyboard) and the score's actions in the title bar's menu.

import SwiftUI

/// The two study screens the player opens full screen; switching from one to the other only changes the item.
enum StudyScreen: String, Identifiable {
    case practice
    case reading

    var id: String { rawValue }
}

struct ScoreView: View {
    @State var viewModel: ScoreViewModel
    /// Modo Estudo or the reading drill, over the player
    @State private var studyScreen: StudyScreen?
    @State private var showEditorMode: Bool = false
    @State private var showMixerSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showExportShare: Bool = false
    @State private var exportURL: URL? = nil
    @Environment(\.dismiss) private var dismiss
    /// A phone held sideways
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // Engraved score source, rebuilt when the score is edited
    @State private var musicXML: String = ""

    // Display settings, remembered from score to score
    @AppStorage("scorePlayer.displayMode") private var displayMode: ScoreDisplayMode = .portraitView
    // Zoom of the engraving (below 0.95 fits two measures per line)
    @AppStorage("scorePlayer.zoom") private var zoomScale: Double = 1.0
    @AppStorage("scorePlayer.showKeyboard") private var showKeyboard: Bool = true
    // Sideways the keyboard is a choice of its own, hidden at first so the music keeps the height
    @AppStorage("scorePlayer.showKeyboardLandscape") private var showKeyboardLandscape: Bool = false
    // "Sala de concerto": reverb on the piano
    @AppStorage("scorePlayer.concertHall") private var hqSoundEnabled: Bool = true

    @State private var isFavorite: Bool = false

    // The player's metronome and speed, also remembered from score to score; the view model holds them while open
    private static let metronomeKey = "scorePlayer.metronome"
    private static let speedKey = "scorePlayer.speed"

    // The clef each hand's staff shows (chosen in Configurações)
    @AppStorage(ClefChoice.rightHandKey) private var rightClef: ClefChoice = .score
    @AppStorage(ClefChoice.leftHandKey) private var leftClef: ClefChoice = .score
    @AppStorage(ClefChoice.automaticUsesAltoKey) private var automaticUsesAlto: Bool = true

    private static let zoomLevels: [Double] = [0.8, 1.0, 1.15, 1.3]

    init(score: Score) {
        let viewModel = ScoreViewModel(score: score)
        viewModel.isMetronomeOn = UserDefaults.standard.bool(forKey: Self.metronomeKey)
        viewModel.playbackSpeed = UserDefaults.standard.object(forKey: Self.speedKey) as? Double ?? 1.0
        _viewModel = State(initialValue: viewModel)
        _isFavorite = State(initialValue: score.isFavorite)
    }

    /// Sideways on a phone: slim top bar and a single control row, so the engraving keeps most of the height.
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    /// The keyboard setting for the way the phone is held.
    private var keyboardBinding: Binding<Bool> {
        isCompactHeight ? $showKeyboardLandscape : $showKeyboard
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
        parts.append(viewModel.score.measureCount == 1
                     ? String(localized: "1 compasso")
                     : String(localized: "\(viewModel.score.measureCount) compassos"))
        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(spacing: 0) {
            PlayerTopBar(title: viewModel.score.title, subtitle: subtitle, onBack: close, compact: isCompactHeight) {
                HStack(spacing: 8) {
                    Button {
                        viewModel.score.isFavorite.toggle()
                        isFavorite = viewModel.score.isFavorite
                    } label: {
                        PlayerMenuLabel(systemName: isFavorite ? "heart.fill" : "heart",
                                        tint: isFavorite ? Color(red: 244 / 255, green: 63 / 255, blue: 94 / 255) : PlayerTheme.text)
                    }
                    .accessibilityLabel(isFavorite ? String(localized: "Remover dos favoritos") : String(localized: "Adicionar aos favoritos"))

                    Button(action: openPracticeMode) {
                        PlayerMenuLabel(systemName: "graduationcap")
                    }
                    .accessibilityLabel("Modo Estudo")
                    .accessibilityIdentifier("practiceModeButton")

                    Button(action: openReadingTrainer) {
                        PlayerMenuLabel(systemName: "music.quarternote.3")
                    }
                    .accessibilityLabel("Treino de leitura")
                    .accessibilityIdentifier("readingTrainerButton")

                    menu
                }
            }

            ScoreWebView(
                title: viewModel.score.title,
                composer: viewModel.score.composer,
                musicXML: musicXML,
                measureIndex: viewModel.currentMeasureIndex,
                cursorBeat: viewModel.cursorBeat,
                zoom: renderZoom,
                transposition: viewModel.transpositionSemitones,
                rightClef: rightClef,
                leftClef: leftClef,
                automaticUsesAlto: automaticUsesAlto,
                horizontal: displayMode == .singleLine,
                isDark: true,
                topInset: 0,
                bottomInset: isCompactHeight ? 8 : 16
            ) { measure, beat in
                viewModel.seek(toMeasure: measure, beat: beat)
            }

            PlayerDock(viewModel: viewModel, showKeyboard: keyboardBinding, compact: isCompactHeight) {
                showMixerSheet = true
            }
        }
        .background(PlayerTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // The file the score was read from when its notes were not edited, else the edited measures
        .onAppear {
            musicXML = viewModel.score.originalMusicXML ?? MusicXMLExporter.export(viewModel.score)
            applyConcertHall()
        }
        .onChange(of: viewModel.score.lastModified) { _, _ in
            musicXML = viewModel.score.originalMusicXML ?? MusicXMLExporter.export(viewModel.score)
        }
        .onChange(of: viewModel.transpositionSemitones) { _, _ in
            viewModel.refreshActiveNotes()
        }
        .onChange(of: hqSoundEnabled) { _, _ in
            applyConcertHall()
        }
        .onChange(of: viewModel.isMetronomeOn) { _, isOn in
            UserDefaults.standard.set(isOn, forKey: Self.metronomeKey)
        }
        .onChange(of: viewModel.playbackSpeed) { _, speed in
            UserDefaults.standard.set(speed, forKey: Self.speedKey)
        }
        // One cover for both study screens: each one's button for the other just changes the item
        .fullScreenCover(item: $studyScreen) { screen in
            switch screen {
            case .practice:
                PracticeView(score: viewModel.score, onSwitchToReading: { studyScreen = .reading })
            case .reading:
                ReadingTrainerView(score: viewModel.score, storageKey: viewModel.score.id.uuidString,
                                   onSwitchToPractice: { studyScreen = .practice })
            }
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
                showKeyboard: keyboardBinding
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
                Button(action: openPracticeMode) {
                    Label("Modo Estudo", systemImage: "graduationcap")
                }
                .accessibilityIdentifier("menuPracticeButton")

                Button(action: openReadingTrainer) {
                    Label("Treino de leitura", systemImage: "music.quarternote.3")
                }
                .accessibilityIdentifier("menuReadingButton")

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

            Section("Claves") {
                clefPicker(String(localized: "Mão direita"), selection: $rightClef)
                clefPicker(String(localized: "Mão esquerda"), selection: $leftClef)
            }

            Section {
                // The bundled sample pieces are not editable
                if !viewModel.score.isSample {
                    Button {
                        viewModel.pause()
                        showEditorMode = true
                    } label: {
                        Label("Editar partitura", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("menuEditButton")
                }

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

    private func clefPicker(_ hand: String, selection: Binding<ClefChoice>) -> some View {
        Picker(selection: selection) {
            ForEach(ClefChoice.allCases) { choice in
                Text(choice.fixedClef?.displayName ?? choice.displayName).tag(choice)
            }
        } label: {
            Label(hand, systemImage: "music.note")
        }
        .pickerStyle(.menu)
    }

    /// The reverb belongs to the audio engine the whole app shares, so the remembered choice is set again on opening.
    private func applyConcertHall() {
        AudioEngineService.shared.setReverb(hqSoundEnabled ? 0.25 : 0.0)
    }

    private func close() {
        viewModel.stop()
        dismiss()
    }

    private func openPracticeMode() {
        viewModel.pause()
        studyScreen = .practice
    }

    private func openReadingTrainer() {
        viewModel.pause()
        studyScreen = .reading
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
