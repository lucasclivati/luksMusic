// ScoreView.swift
// luksMusic
//
// Sheet music viewer: the score is engraved by OpenSheetMusicDisplay (ScoreWebView) with a cursor that
// steps note by note, an interactive keyboard showing the keys under the cursor, a floating transport bar,
// and a bottom drawer with the score's actions. Controls fade out while the music plays.

import SwiftUI

struct ScoreView: View {
    @State var viewModel: ScoreViewModel
    @State private var showPracticeMode: Bool = false
    @State private var showEditorMode: Bool = false
    @State private var showMixerSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showExportShare: Bool = false
    @State private var showMenu: Bool = false
    @State private var exportURL: URL? = nil
    @Environment(\.dismiss) private var dismiss

    // Engraved score source, rebuilt when the score is edited
    @State private var musicXML: String = ""

    // Zoom control
    @State private var zoomScale: CGFloat = 1.0

    // Display settings
    @State private var displayMode: ScoreDisplayMode = .portraitView
    @State private var hqSoundEnabled: Bool = true
    @State private var showKeyboard: Bool = true
    @State private var keyboardViewModel = PianoKeyboardViewModel(rangeStart: 48, rangeEnd: 84)

    // Bottom drawer
    @State private var isDrawerExpanded: Bool = false
    @State private var drawerDragOffset: CGFloat = 0.0
    @State private var isFavorite: Bool = false

    private let accentPurple = Color(red: 48/255, green: 26/255, blue: 73/255)

    init(score: Score) {
        _viewModel = State(initialValue: ScoreViewModel(score: score))
        _isFavorite = State(initialValue: score.isFavorite)
    }

    /// Room the page leaves under the floating controls so the last system can scroll above them.
    private var bottomInset: CGFloat {
        110 + (showKeyboard ? 140 : 0) + (isDrawerExpanded ? 150 : 0)
    }

    /// "Vertical Scroll" fits two measures per line; "Portrait View" shows one larger measure per line.
    private var renderZoom: Double {
        Double(zoomScale) * (displayMode == .verticalScroll ? 0.8 : 1.0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()
            
            // The app runs in dark mode (white status bar text), so the status bar gets a dark strip over the paper
            accentPurple
                .frame(height: 0)
                .ignoresSafeArea(edges: .top)
            
            ScoreWebView(
                title: viewModel.score.title,
                composer: viewModel.score.composer,
                musicXML: musicXML,
                measureIndex: viewModel.currentMeasureIndex,
                cursorBeat: viewModel.cursorBeat,
                zoom: renderZoom,
                transposition: viewModel.transpositionSemitones,
                horizontal: displayMode == .singleLine,
                topInset: 64,
                bottomInset: bottomInset
            ) { measure, beat in
                viewModel.seek(toMeasure: measure, beat: beat)
            }
            .ignoresSafeArea(edges: .bottom)

            topBar

            if showMenu {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showMenu = false
                        }
                    }

                expandedTopMenuCard
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Bottom layer: keyboard, transport bar and drawer
            VStack(spacing: 8) {
                Spacer()

                if showKeyboard {
                    interactiveKeyboardDock
                }

                floatingTransportPill

                if isDrawerExpanded {
                    draggableBottomDrawer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    collapsedDrawerTab
                }
            }
            .offset(y: max(0, drawerDragOffset))
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // Controls drawn over the white paper use light-mode colors
        .environment(\.colorScheme, .light)
        .onAppear {
            musicXML = MusicXMLExporter.export(viewModel.score)
        }
        .onChange(of: viewModel.score.lastModified) { _, _ in
            musicXML = MusicXMLExporter.export(viewModel.score)
        }
        .onChange(of: viewModel.activeMidiNotes, initial: true) { _, activeMidi in
            keyboardViewModel.midiActiveKeys = activeMidi
        }
        .onChange(of: viewModel.transpositionSemitones) { _, _ in
            viewModel.refreshActiveNotes()
        }
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            if isPlaying {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showMenu = false
                }
            }
        }
        .sheet(isPresented: $showPracticeMode) {
            PracticeView(score: viewModel.score)
        }
        .sheet(isPresented: $showEditorMode) {
            EditorView(score: viewModel.score)
        }
        .sheet(isPresented: $showMixerSheet) {
            handsMixerSheet
                .presentationDetents([.fraction(0.38)])
        }
        .sheet(isPresented: $showSettingsSheet) {
            ScoreSettingsView(
                viewModel: viewModel,
                displayMode: $displayMode,
                hqSoundEnabled: $hqSoundEnabled,
                showKeyboard: $showKeyboard
            )
            .presentationDetents([.fraction(0.68)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Top Bar

    /// Back and menu buttons; hidden while playing so they never cover the notes being read.
    @ViewBuilder
    private var topBar: some View {
        HStack {
            Button {
                viewModel.stop()
                dismiss()
            } label: {
                floatingCircle(systemName: "chevron.left")
            }
            .accessibilityLabel("Voltar")

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showMenu.toggle()
                }
            } label: {
                floatingCircle(systemName: showMenu ? "xmark" : "ellipsis")
            }
            .accessibilityLabel("Opções da partitura")
            .accessibilityIdentifier("scoreMenuButton")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .opacity(viewModel.isPlaying ? 0 : 1)
        .allowsHitTesting(!viewModel.isPlaying)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isPlaying)
    }

    private func floatingCircle(systemName: String) -> some View {
        Circle()
            .fill(accentPurple)
            .frame(width: 42, height: 42)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            )
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    // MARK: - Interactive Piano Keyboard Dock

    @ViewBuilder
    private var interactiveKeyboardDock: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Teclas sob o cursor")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.6))
                Spacer()
                Button {
                    withAnimation {
                        showKeyboard = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color.black.opacity(0.4))
                }
                .accessibilityLabel("Esconder teclado")
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            PianoKeyboardView(
                viewModel: keyboardViewModel,
                onKeyPress: { midiNote in
                    AudioEngineService.shared.playNote(midiNote: UInt8(midiNote), velocity: 90)
                },
                onKeyRelease: { midiNote in
                    AudioEngineService.shared.stopNote(midiNote: UInt8(midiNote))
                }
            )
            .frame(height: 112)
        }
        .padding(.bottom, 4)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 6, y: -2)
        .padding(.horizontal, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Floating Transport Bar

    @ViewBuilder
    private var floatingTransportPill: some View {
        HStack(spacing: 24) {
            Button {
                viewModel.isLooping.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.isLooping ? Color(red: 0.22, green: 0.74, blue: 0.97) : .white)
            }
            .accessibilityLabel("Repetir")

            Button {
                viewModel.previousMeasure()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Compasso anterior")

            Button {
                viewModel.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.28), radius: 4, y: 2)

                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: viewModel.isPlaying ? 0 : 1.5)
                }
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pausar" : "Tocar")
            .accessibilityIdentifier("playPauseButton")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showKeyboard.toggle()
                }
            } label: {
                Image(systemName: "pianokeys")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(showKeyboard ? Color(red: 0.22, green: 0.74, blue: 0.97) : .white)
            }
            .accessibilityLabel("Teclado")
            .accessibilityIdentifier("keyboardToggleButton")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDrawerExpanded.toggle()
                }
            } label: {
                Image(systemName: isDrawerExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accessibilityLabel(isDrawerExpanded ? "Fechar detalhes" : "Abrir detalhes")
            .accessibilityIdentifier("drawerToggleButton")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(accentPurple)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        )
    }

    // MARK: - Bottom Drawer

    @ViewBuilder
    private var draggableBottomDrawer: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 38, height: 4.5)
                .padding(.top, 8)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.score.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)

                    Text(viewModel.score.composer)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.black.opacity(0.6))
                }

                Spacer()

                Button {
                    viewModel.score.isFavorite.toggle()
                    isFavorite = viewModel.score.isFavorite
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isFavorite ? .red : Color.black.opacity(0.7))
                }
                .accessibilityLabel(isFavorite ? "Remover dos favoritos" : "Adicionar aos favoritos")
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    drawerPill(title: "Modo Estudo", systemName: "pianokeys", prominent: true) {
                        showPracticeMode = true
                    }
                    drawerPill(title: "Exportar", systemName: "square.and.arrow.up") {
                        exportScore()
                    }
                    drawerPill(title: "Mixer de Mãos", systemName: "slider.vertical.3") {
                        showMixerSheet = true
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 10, y: -4)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        drawerDragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if value.translation.height > 80 {
                            isDrawerExpanded = false
                        }
                        drawerDragOffset = 0
                    }
                }
        )
    }

    private func drawerPill(title: String, systemName: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                Text(title)
                    .fontWeight(prominent ? .semibold : .regular)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(prominent ? accentPurple : Color.black.opacity(0.06))
            .foregroundColor(prominent ? .white : .black)
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var collapsedDrawerTab: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isDrawerExpanded = true
            }
        } label: {
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.95))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 4, y: -2)
                .padding(.horizontal, 40)
                .padding(.bottom, 6)
        }
        .accessibilityLabel("Abrir detalhes")
    }

    // MARK: - Options Menu

    @ViewBuilder
    private var expandedTopMenuCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Zoom: \(Int(zoomScale * 100))%", systemImage: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("-") {
                    zoomScale = max(0.7, zoomScale - 0.1)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button("+") {
                    zoomScale = min(1.3, zoomScale + 0.1)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            HStack {
                Label("Velocidade", systemImage: "speedometer")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Picker("Velocidade", selection: $viewModel.playbackSpeed) {
                    Text("0.5×").tag(0.5)
                    Text("0.75×").tag(0.75)
                    Text("1×").tag(1.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal, 12)
            
            Divider()
            
            menuItem("Configurações", systemName: "gearshape.fill", identifier: "menuSettingsButton") {
                showSettingsSheet = true
            }
            menuItem("Modo Estudo", systemName: "pianokeys", identifier: "menuPracticeButton") {
                showPracticeMode = true
            }
            menuItem("Mixer de Mãos", systemName: "slider.vertical.3", identifier: "menuMixerButton") {
                showMixerSheet = true
            }
            menuItem("Editar Partitura", systemName: "square.and.pencil", identifier: "menuEditButton") {
                showEditorMode = true
            }
            menuItem("Exportar MusicXML", systemName: "square.and.arrow.up", identifier: "menuExportButton") {
                exportScore()
            }
            .padding(.bottom, 10)
        }
        .frame(width: 270)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
        )
    }

    private func menuItem(_ title: String, systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button {
            showMenu = false
            action()
        } label: {
            Label(title, systemImage: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Hands Mixer

    @ViewBuilder
    private var handsMixerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                mixerChannel(
                    symbol: "𝄞",
                    title: "Mão direita (clave de sol)",
                    volume: $viewModel.trebleVolume,
                    muted: $viewModel.trebleMuted
                )
                mixerChannel(
                    symbol: "𝄢",
                    title: "Mão esquerda (clave de fá)",
                    volume: $viewModel.bassVolume,
                    muted: $viewModel.bassMuted
                )

                HStack(spacing: 10) {
                    Button("Duas mãos") {
                        viewModel.trebleMuted = false
                        viewModel.bassMuted = false
                    }
                    .buttonStyle(.bordered)

                    Button("Só direita") {
                        viewModel.trebleMuted = false
                        viewModel.bassMuted = true
                    }
                    .buttonStyle(.bordered)

                    Button("Só esquerda") {
                        viewModel.trebleMuted = true
                        viewModel.bassMuted = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Mixer de Mãos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        showMixerSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func mixerChannel(symbol: String, title: String, volume: Binding<Double>, muted: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Text(symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(accentPurple)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Slider(value: volume, in: 0...1)
            }

            Button(muted.wrappedValue ? "Mudo" : "Silenciar") {
                muted.wrappedValue.toggle()
            }
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(muted.wrappedValue ? Color.red : Color(.tertiarySystemFill))
            .foregroundColor(muted.wrappedValue ? .white : .primary)
            .cornerRadius(6)
        }
        .padding(.horizontal)
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
