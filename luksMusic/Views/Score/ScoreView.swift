// ScoreView.swift
// luksMusic
//
// Authentic MuseScore-style vertical sheet music viewer for iOS.
// Displays full-width vertical grand staff systems, lyrics, pedal lines,
// smooth teardrop playback cursor, and a floating bottom transport pill.

import SwiftUI

struct ScoreView: View {
    @State var viewModel: ScoreViewModel
    @State private var showPracticeMode: Bool = false
    @State private var showEditorMode: Bool = false
    @State private var showMixerSheet: Bool = false
    @State private var showExportShare: Bool = false
    @State private var exportURL: URL? = nil
    @Environment(\.dismiss) private var dismiss
    
    // Zoom control
    @State private var zoomScale: CGFloat = 1.0
    
    // Hands volume controls
    @State private var rhVolume: Double = 0.95
    @State private var lhVolume: Double = 0.90
    @State private var rhMuted: Bool = false
    @State private var lhMuted: Bool = false
    
    init(score: Score) {
        _viewModel = State(initialValue: ScoreViewModel(score: score))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background Pure White matching MuseScore paper
                Color.white.ignoresSafeArea()
                
                // Sheet Music Area (Continuous Vertical Flow)
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 18) {
                            // Score Title (Clean serif title matching MuseScore app)
                            VStack(spacing: 4) {
                                Text(viewModel.score.title.uppercased())
                                    .font(.system(size: 21, weight: .regular, design: .serif))
                                    .tracking(0.5)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.black)
                                
                                if !viewModel.score.composer.isEmpty {
                                    Text(viewModel.score.composer)
                                        .font(.system(size: 11, weight: .regular, design: .serif))
                                        .foregroundColor(Color.black.opacity(0.6))
                                }
                            }
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                            
                            // Vertical Grand Staff Systems (1 Measure per System on iPhone)
                            ForEach(Array(viewModel.score.measures.enumerated()), id: \.element.id) { index, measure in
                                let isCurrent = (index == viewModel.currentMeasureIndex)
                                let isFirstMeasure = (index == 0)
                                let leftWidth: CGFloat = isFirstMeasure ? 72.0 : 54.0
                                let systemWidth = max(240.0, geometry.size.width - 24.0)
                                let measureWidth = systemWidth - leftWidth
                                let lineSpacing: CGFloat = 8.5 * zoomScale
                                
                                HStack(alignment: .top, spacing: 0) {
                                    // Left Clefs, Signatures & Grand Staff Brace
                                    StaffView(
                                        lineSpacing: lineSpacing,
                                        keySignatureValue: viewModel.score.keySignatureValue,
                                        timeSignatureTop: viewModel.score.timeSignatureTop,
                                        timeSignatureBottom: viewModel.score.timeSignatureBottom,
                                        showClefsAndSignatures: true,
                                        showTimeSignature: isFirstMeasure
                                    )
                                    .frame(width: leftWidth)
                                    
                                    // Measure Notes, Triplets, Lyrics, Pedal Line & Cursor
                                    MeasureView(
                                        measure: measure,
                                        isCurrent: isCurrent,
                                        currentBeat: viewModel.currentBeat,
                                        lineSpacing: lineSpacing,
                                        measureWidth: measureWidth,
                                        showMeasureNumber: true,
                                        showTempoAndDynamics: isFirstMeasure
                                    )
                                }
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.seekToMeasure(index)
                                }
                            }
                            
                            // Bottom padding so last measure is not blocked by floating pill
                            Spacer().frame(height: 110)
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
                
                // Floating MuseScore Bottom Controls Pill
                floatingMuseScorePill
                    .padding(.bottom, 10)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar) // HIDE TAB BAR TO DEDICATE 90% SCREEN TO SCORE!
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.stop()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showPracticeMode = true
                    } label: {
                        Label("Practice Piano", systemImage: "pianokeys")
                    }
                    
                    Button {
                        showEditorMode = true
                    } label: {
                        Label("Edit Score", systemImage: "square.and.pencil")
                    }
                    
                    Button {
                        exportScore()
                    } label: {
                        Label("Export MusicXML", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        viewModel.score.isPublic.toggle()
                    } label: {
                        Label(viewModel.score.isPublic ? "Definir como Privada" : "Definir como Pública", systemImage: viewModel.score.isPublic ? "lock.fill" : "globe")
                    }
                    
                    Divider()
                    
                    Button {
                        zoomScale = min(1.3, zoomScale + 0.1)
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    
                    Button {
                        zoomScale = max(0.7, zoomScale - 0.1)
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
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
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Floating MuseScore Transport Pill (Photo 2 Match)
    
    @ViewBuilder
    private var floatingMuseScorePill: some View {
        HStack(spacing: 28) {
            // 1. Loop Button
            Button {
                viewModel.isLooping.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(viewModel.isLooping ? Color(red: 0.22, green: 0.74, blue: 0.97) : .white)
            }
            
            // 2. Previous Measure
            Button {
                viewModel.previousMeasure()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // 3. Play / Pause Hero Button (White circle, black play icon)
            Button {
                viewModel.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: viewModel.isPlaying ? 0 : 1.5)
                }
            }
            
            // 4. Mixer / Tracks Button
            Button {
                showMixerSheet = true
            } label: {
                Image(systemName: "slider.vertical.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // 5. Fullscreen / Practice Piano Mode
            Button {
                showPracticeMode = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(red: 0.16, green: 0.12, blue: 0.26)) // Deep MuseScore purple/navy
                .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
        )
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
                        .foregroundColor(.cyan)
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
                        .foregroundColor(.green)
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
