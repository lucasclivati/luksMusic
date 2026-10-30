// ScoreView.swift
// luksMusic
//
// Authentic MuseScore iOS sheet music viewer.
// Features pure white paper background, floating purple circular buttons,
// expanded pill action menu (Image 4), compact 4-system portrait engraving,
// teardrop playhead cursor, floating transport pill, draggable bottom drawer (Image 2 & 3),
// and fully functional Settings modal (Image 5 - Display Mode, HQ+ Sound, Keyboard, Transposition).

import SwiftUI

struct ScoreView: View {
    @State var viewModel: ScoreViewModel
    @State private var showPracticeMode: Bool = false
    @State private var showEditorMode: Bool = false
    @State private var showMixerSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showExportShare: Bool = false
    @State private var showTopMenu: Bool = false
    @State private var exportURL: URL? = nil
    @Environment(\.dismiss) private var dismiss
    
    // Zoom control
    @State private var zoomScale: CGFloat = 1.0
    
    // Settings state matching MuseScore Settings screen
    @State private var displayMode: ScoreDisplayMode = .portraitView
    @State private var hqSoundEnabled: Bool = true
    @State private var showKeyboard: Bool = false
    @State private var keyboardViewModel = PianoKeyboardViewModel(rangeStart: 48, rangeEnd: 84)
    
    // Bottom Drawer State (Expanded in Image 2 & 4, Collapsed in Image 3)
    @State private var isDrawerExpanded: Bool = true
    @State private var drawerDragOffset: CGFloat = 0.0
    @State private var isFavorite: Bool = false
    
    // Hands volume controls
    @State private var rhVolume: Double = 0.95
    @State private var lhVolume: Double = 0.90
    @State private var rhMuted: Bool = false
    @State private var lhMuted: Bool = false
    
    // MuseScore Deep Purple Accent Color (#301a49)
    private let musePurple = Color(red: 48/255, green: 26/255, blue: 73/255)
    
    init(score: Score) {
        _viewModel = State(initialValue: ScoreViewModel(score: score))
        _isFavorite = State(initialValue: score.isFavorite)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background Pure White matching MuseScore paper
                Color.white.ignoresSafeArea()
                
                // Sheet Music Area based on selected Display Mode
                switch displayMode {
                case .singleLine:
                    singleLineScoreView(geometry: geometry)
                case .verticalScroll, .portraitView:
                    verticalScoreView(geometry: geometry)
                }
                
                // Floating Top Left Back Button (Circular MuseScore Deep Purple)
                HStack {
                    Button {
                        viewModel.stop()
                        dismiss()
                    } label: {
                        Circle()
                            .fill(musePurple)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // Floating Top Right Action Stack
                    VStack(spacing: 10) {
                        // 1. Zoom Button
                        Button {
                            cycleZoom()
                        } label: {
                            Circle()
                                .fill(musePurple)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        }
                        
                        // 2. Practice Mode Button
                        Button {
                            showPracticeMode = true
                        } label: {
                            Circle()
                                .fill(musePurple)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        }
                        
                        // 3. Settings Button (Opens authentic MuseScore Settings Sheet)
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Circle()
                                .fill(musePurple)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        }
                        
                        // 4. Menu Expander Button (Image 4)
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showTopMenu.toggle()
                            }
                        } label: {
                            Circle()
                                .fill(musePurple)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: showTopMenu ? "xmark" : "chevron.down")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 48) // Safe area top
                
                // Top-Right Expanded Action Menu (Image 4 Parity)
                if showTopMenu {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showTopMenu = false
                            }
                        }
                    
                    VStack(alignment: .trailing, spacing: 10) {
                        expandedTopMenuCard
                            .padding(.top, 100)
                            .padding(.trailing, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Bottom Layer: Interactive Piano Keyboard + Transport Pill + Draggable Bottom Drawer
                VStack(spacing: 8) {
                    Spacer()
                    
                    // Interactive Piano Keyboard (when toggled on in Settings)
                    if showKeyboard {
                        interactiveKeyboardDock
                    }
                    
                    // Floating MuseScore Transport Bar Pill
                    floatingTransportPill
                    
                    // Draggable MuseScore Bottom Sheet (Image 2)
                    if isDrawerExpanded {
                        draggableBottomDrawer
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Collapsed bottom drag tab (Image 3)
                        collapsedDrawerTab
                    }
                }
                .offset(y: max(0, drawerDragOffset))
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: viewModel.activeMidiNotes, initial: true) { _, activeMidi in
            keyboardViewModel.midiActiveKeys = activeMidi
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
    
    // MARK: - Vertical / Portrait View
    
    @ViewBuilder
    private func verticalScoreView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: displayMode == .portraitView ? 14 : 20) {
                    // Top spacing for floating back/action buttons
                    Spacer().frame(height: 52)
                    
                    // Score Title (Classic MuseScore Serif Typography)
                    VStack(spacing: 3) {
                        Text(viewModel.score.title.uppercased())
                            .font(.system(size: 19, weight: .regular, design: .serif))
                            .tracking(0.8)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                        
                        Text(viewModel.score.composer)
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .foregroundColor(Color.black.opacity(0.65))
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    
                    // Vertical Grand Staff Systems
                    ForEach(Array(viewModel.score.measures.enumerated()), id: \.element.id) { index, measure in
                        let isCurrent = (index == viewModel.currentMeasureIndex)
                        let isFirstMeasure = (index == 0)
                        let leftWidth: CGFloat = isFirstMeasure ? 64.0 : 48.0
                        let systemWidth = max(260.0, geometry.size.width - 24.0)
                        let measureWidth = systemWidth - leftWidth
                        let lineSpacing: CGFloat = (displayMode == .portraitView ? 6.4 : 7.2) * zoomScale
                        
                        HStack(alignment: .top, spacing: 0) {
                            // Left Clefs, Signatures & Grand Staff Brace
                            StaffView(
                                lineSpacing: lineSpacing,
                                keySignatureValue: viewModel.currentKeySignatureValue,
                                timeSignatureTop: viewModel.score.timeSignatureTop,
                                timeSignatureBottom: viewModel.score.timeSignatureBottom,
                                showClefsAndSignatures: true,
                                showTimeSignature: isFirstMeasure
                            )
                            .frame(width: leftWidth)
                            
                            // Measure Notes, Triplets, Lyrics, Pedal Line & Teardrop Cursor
                            MeasureView(
                                measure: measure,
                                isCurrent: isCurrent,
                                currentBeat: viewModel.currentBeat,
                                lineSpacing: lineSpacing,
                                measureWidth: measureWidth,
                                showMeasureNumber: true,
                                showTempoAndDynamics: isFirstMeasure,
                                tempo: viewModel.score.tempo
                            )
                        }
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let beat = MeasureView.beat(atX: location.x - leftWidth, measureWidth: measureWidth)
                            viewModel.seek(toMeasure: index, beat: beat)
                        }
                    }
                    
                    // Bottom padding so last measure is not blocked
                    Spacer().frame(height: isDrawerExpanded ? 340 : (showKeyboard ? 260 : 120))
                }
                .padding(.horizontal, 12)
            }
            .background(Color.white)
            .onChange(of: viewModel.currentMeasureIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Single Line (Horizontal Flow) Display Mode
    
    @ViewBuilder
    private func singleLineScoreView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { scrollProxy in
            VStack {
                Spacer().frame(height: 70)
                
                // Score Title
                VStack(spacing: 2) {
                    Text(viewModel.score.title.uppercased())
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .tracking(0.6)
                        .foregroundColor(.black)
                    Text(viewModel.score.composer)
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 12)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(viewModel.score.measures.enumerated()), id: \.element.id) { index, measure in
                            let isCurrent = (index == viewModel.currentMeasureIndex)
                            let isFirstMeasure = (index == 0)
                            let leftWidth: CGFloat = isFirstMeasure ? 64.0 : 44.0
                            let measureWidth: CGFloat = 280.0 * zoomScale
                            let lineSpacing: CGFloat = 7.0 * zoomScale
                            
                            HStack(alignment: .top, spacing: 0) {
                                StaffView(
                                    lineSpacing: lineSpacing,
                                    keySignatureValue: viewModel.currentKeySignatureValue,
                                    timeSignatureTop: viewModel.score.timeSignatureTop,
                                    timeSignatureBottom: viewModel.score.timeSignatureBottom,
                                    showClefsAndSignatures: true,
                                    showTimeSignature: isFirstMeasure
                                )
                                .frame(width: leftWidth)
                                
                                MeasureView(
                                    measure: measure,
                                    isCurrent: isCurrent,
                                    currentBeat: viewModel.currentBeat,
                                    lineSpacing: lineSpacing,
                                    measureWidth: measureWidth,
                                    showMeasureNumber: true,
                                    showTempoAndDynamics: isFirstMeasure,
                                    tempo: viewModel.score.tempo
                                )
                            }
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let beat = MeasureView.beat(atX: location.x - leftWidth, measureWidth: measureWidth)
                                viewModel.seek(toMeasure: index, beat: beat)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 180)
                
                Spacer()
            }
            .background(Color.white)
            .onChange(of: viewModel.currentMeasureIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Interactive Piano Keyboard Dock
    
    @ViewBuilder
    private var interactiveKeyboardDock: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Piano Interativo (C3 - C6)")
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
    
    // MARK: - Floating Transport Pill (Image 2 & 3 Parity)
    
    @ViewBuilder
    private var floatingTransportPill: some View {
        HStack(spacing: 24) {
            // 1. Loop Button (Toggles loop, cyan when active)
            Button {
                viewModel.isLooping.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.isLooping ? Color(red: 0.22, green: 0.74, blue: 0.97) : .white)
            }
            
            // 2. Rewind / Previous Measure
            Button {
                viewModel.previousMeasure()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // 3. Circular Hero Play/Pause Button (White circle, black icon)
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
            
            // 4. Hands Mixer / Volumes Button
            Button {
                showMixerSheet = true
            } label: {
                Image(systemName: "slider.vertical.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // 5. Drawer Toggle (Expand / Collapse Bottom Sheet)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDrawerExpanded.toggle()
                }
            } label: {
                Image(systemName: isDrawerExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(musePurple)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        )
    }
    
    // MARK: - Draggable Bottom Sheet / Drawer (Image 2 Parity)
    
    @ViewBuilder
    private var draggableBottomDrawer: some View {
        VStack(spacing: 12) {
            // Drag Handle Pill
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 38, height: 4.5)
                .padding(.top, 8)
            
            // Score Header in Drawer
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
                
                // Favorite Heart Button
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isFavorite ? .red : Color.black.opacity(0.7))
                }
            }
            .padding(.horizontal, 18)
            
            // Horizontal Action Pills Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Modo Estudo Pill
                    Button {
                        showPracticeMode = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pianokeys")
                            Text("Modo Estudo")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(musePurple)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    
                    // Download Pill
                    Button {
                        exportScore()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.to.line")
                            Text("Download")
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.06))
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    }
                    
                    // Salvar Offline Pill
                    Button {
                        // Offline save toggle
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark.fill")
                            Text("Salvar offline")
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.06))
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    }
                    
                    // Add to Playlist Pill
                    Button {
                        // Playlist modal
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.06))
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 18)
            }
            
            // Comments & Community Preview
            HStack(spacing: 10) {
                Text("Comments 8")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                
                Text("\"Muito boa essa música!\"")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Spacer()
                
                Text("❤️")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.03))
            .cornerRadius(8)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
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
    
    // MARK: - Collapsed Drawer Tab (Image 3 Parity)
    
    @ViewBuilder
    private var collapsedDrawerTab: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isDrawerExpanded = true
            }
        } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 36, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.95))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, y: -2)
            .padding(.horizontal, 40)
            .padding(.bottom, 6)
        }
    }
    
    // MARK: - Top Right Expanded Action Menu (Image 4 Parity)
    
    @ViewBuilder
    private var expandedTopMenuCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Zoom Steppers
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
            
            Divider()
            
            // Settings Button
            Button {
                showTopMenu = false
                showSettingsSheet = true
            } label: {
                Label("Configurações (Settings)", systemImage: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            
            // Practice Mode Button
            Button {
                showTopMenu = false
                showPracticeMode = true
            } label: {
                Label("Modo Estudo (Piano)", systemImage: "pianokeys")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            
            // Hands Mixer Button
            Button {
                showTopMenu = false
                showMixerSheet = true
            } label: {
                Label("Mixer de Mãos", systemImage: "slider.vertical.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            
            // Edit Score Button
            Button {
                showTopMenu = false
                showEditorMode = true
            } label: {
                Label("Editar Partitura", systemImage: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            
            // Export MusicXML
            Button {
                showTopMenu = false
                exportScore()
            } label: {
                Label("Exportar MusicXML", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            
            Divider()
            
            // Close Button
            Button {
                withAnimation {
                    showTopMenu = false
                }
            } label: {
                Label("Fechar", systemImage: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: 230)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
        )
    }
    
    private func cycleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if zoomScale >= 1.25 {
                zoomScale = 0.85
            } else if zoomScale >= 1.0 {
                zoomScale = 1.25
            } else {
                zoomScale = 1.0
            }
        }
    }
    
    // MARK: - Hands Mixer Modal Sheet
    
    @ViewBuilder
    private var handsMixerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Right Hand Channel
                HStack(spacing: 14) {
                    Text("𝄞")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(musePurple)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Right Hand (Melody)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Slider(value: $rhVolume, in: 0...1)
                    }
                    
                    Button(rhMuted ? "Muted" : "Mute") {
                        rhMuted.toggle()
                    }
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(rhMuted ? Color.red : Color(.tertiarySystemFill))
                    .foregroundColor(rhMuted ? .white : .primary)
                    .cornerRadius(6)
                }
                .padding(.horizontal)
                
                // Left Hand Channel
                HStack(spacing: 14) {
                    Text("𝄢")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(musePurple)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Left Hand (Bass / Chords)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Slider(value: $lhVolume, in: 0...1)
                    }
                    
                    Button(lhMuted ? "Muted" : "Mute") {
                        lhMuted.toggle()
                    }
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(lhMuted ? Color.red : Color(.tertiarySystemFill))
                    .foregroundColor(lhMuted ? .white : .primary)
                    .cornerRadius(6)
                }
                .padding(.horizontal)
                
                // Quick Presets
                HStack(spacing: 10) {
                    Button("Both Hands") {
                        rhMuted = false
                        lhMuted = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Melody Only") {
                        rhMuted = false
                        lhMuted = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Bass Only") {
                        rhMuted = true
                        lhMuted = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Hands Mixer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showMixerSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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
