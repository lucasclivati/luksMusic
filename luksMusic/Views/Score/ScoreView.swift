// ScoreView.swift
// luksMusic
//
// MuseScore-like sheet music viewer displaying grand staff notation,
// horizontal measure scrolling, playback cursor, and action buttons.

import SwiftUI

struct ScoreView: View {
    @State var viewModel: ScoreViewModel
    @State private var showPracticeMode: Bool = false
    @State private var showEditorMode: Bool = false
    @State private var showExportShare: Bool = false
    @State private var exportURL: URL? = nil
    
    init(score: Score) {
        _viewModel = State(initialValue: ScoreViewModel(score: score))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Score Header
            scoreHeader()
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            Divider()
            
            // Sheet Music Area
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // Left Clefs and Key/Time signatures
                        StaffView(
                            lineSpacing: 12.0 * viewModel.zoomScale,
                            keySignatureValue: viewModel.score.keySignatureValue,
                            timeSignatureTop: viewModel.score.timeSignatureTop,
                            timeSignatureBottom: viewModel.score.timeSignatureBottom,
                            showClefsAndSignatures: true
                        )
                        .padding(.leading, 16)
                        
                        // Measures in sequence
                        ForEach(Array(viewModel.score.measures.enumerated()), id: \.element.id) { index, measure in
                            MeasureView(
                                measure: measure,
                                isCurrent: index == viewModel.currentMeasureIndex,
                                currentBeat: viewModel.currentBeat,
                                lineSpacing: 12.0 * viewModel.zoomScale,
                                measureWidth: 180.0 * viewModel.zoomScale
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.seekToMeasure(index)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 24)
                }
                .onChange(of: viewModel.currentMeasureIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .background(Color(.systemBackground))
            
            Divider()
            
            // Bottom Action Bar: Practice & Edit shortcuts
            HStack(spacing: 12) {
                Button {
                    showPracticeMode = true
                } label: {
                    Label("Practice Piano", systemImage: "pianokeys")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                
                Button {
                    showEditorMode = true
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                        .font(.subheadline)
                        .frame(width: 80)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemFill))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Playback Controls
            PlaybackControlsView(
                isPlaying: viewModel.isPlaying,
                tempo: viewModel.score.tempo,
                currentMeasure: viewModel.currentMeasureIndex + 1,
                totalMeasures: max(1, viewModel.score.measureCount),
                onPlayPause: { viewModel.togglePlayback() },
                onStop: { viewModel.stop() },
                onPrevious: { viewModel.previousMeasure() },
                onNext: { viewModel.nextMeasure() },
                onTempoChange: { newBPM in viewModel.score.tempo = newBPM }
            )
            .padding(.bottom, 8)
        }
        .navigationTitle(viewModel.score.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportScore()
                    } label: {
                        Label("Export MusicXML", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        viewModel.zoomScale = min(1.5, viewModel.zoomScale + 0.15)
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    
                    Button {
                        viewModel.zoomScale = max(0.7, viewModel.zoomScale - 0.15)
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showPracticeMode) {
            PracticeView(score: viewModel.score)
        }
        .sheet(isPresented: $showEditorMode) {
            EditorView(score: viewModel.score)
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func scoreHeader() -> some View {
        VStack(spacing: 4) {
            Text(viewModel.score.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(viewModel.score.composer)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Label("\(viewModel.score.tempo) BPM", systemImage: "metronome")
                Label("\(viewModel.score.timeSignatureTop)/\(viewModel.score.timeSignatureBottom)", systemImage: "music.note")
                Label(viewModel.score.keySignatureName, systemImage: "tuningfork")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 2)
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
