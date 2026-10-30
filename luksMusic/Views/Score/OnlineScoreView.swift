// OnlineScoreView.swift
// luksMusic
//
// A score from the online library shown with its original engraved pages, exactly as on luksmusic.web.app,
// in the shared player frame: title bar, the pages, and the dock with the timeline, transport and keyboard.

import SwiftUI

struct OnlineScoreView: View {
    let score: OnlineScore

    @State private var content: OnlineScoreContent?
    @State private var viewModel: ScoreViewModel?
    @State private var errorMessage: String?
    @State private var showKeyboard: Bool = true
    @State private var showMixer: Bool = false
    @State private var zoom: Double = 1.0
    @Environment(\.dismiss) private var dismiss

    private static let zoomLevels: [Double] = [1.0, 1.25, 1.5, 2.0]

    private static func zoomLabel(_ zoom: Double) -> String {
        zoom == 1.0 ? "Ajustar à largura" : "\(Int(zoom * 100))%"
    }

    private var subtitle: String {
        var parts = [score.credits]
        parts.append("\(score.bpm) BPM")
        if let count = viewModel?.score.measureCount, count > 0 {
            parts.append("\(count) compassos")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " • ")
    }

    var body: some View {
        VStack(spacing: 0) {
            PlayerTopBar(title: score.title, subtitle: subtitle, onBack: close) {
                if score.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PlayerTheme.muted)
                        .accessibilityLabel("Partitura privada")
                }
                menu
            }

            if let content, let viewModel {
                PageScoreWebView(
                    pageURLs: score.pageURLs,
                    content: content,
                    beatsPerMeasure: score.beatsPerMeasure,
                    measureIndex: viewModel.currentMeasureIndex,
                    cursorBeat: viewModel.cursorBeat,
                    zoom: zoom
                ) { measure, beat in
                    viewModel.seek(toMeasure: measure, beat: beat)
                }

                PlayerDock(viewModel: viewModel, showKeyboard: $showKeyboard) {
                    showMixer = true
                }
            } else if let errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(PlayerTheme.muted)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(PlayerTheme.text)
                        .multilineTextAlignment(.center)
                    Button("Tentar de novo") {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PlayerTheme.blue)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Carregando partitura…")
                    .tint(PlayerTheme.cyan)
                    .foregroundStyle(PlayerTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PlayerTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if content == nil {
                await load()
            }
        }
        .onDisappear {
            viewModel?.stop()
        }
        .sheet(isPresented: $showMixer) {
            if let viewModel {
                HandsMixerSheet(viewModel: viewModel)
                    .presentationDetents([.fraction(0.42)])
            }
        }
    }

    private var menu: some View {
        Menu {
            Picker("Zoom", selection: $zoom) {
                ForEach(Self.zoomLevels, id: \.self) { level in
                    Text(Self.zoomLabel(level)).tag(level)
                }
            }
            Button {
                showMixer = true
            } label: {
                Label("Mixer de mãos", systemImage: "slider.vertical.3")
            }
            ShareLink(item: score.webURL) {
                Label("Compartilhar link", systemImage: "square.and.arrow.up")
            }
        } label: {
            PlayerMenuLabel()
        }
        .accessibilityLabel("Opções da partitura")
        .accessibilityIdentifier("scoreMenuButton")
    }

    private func close() {
        viewModel?.stop()
        dismiss()
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await OnlineLibraryService.shared.loadContent(for: score)
            let playable = Score(
                title: score.title,
                composer: score.credits,
                difficulty: .advanced,
                source: .imported,
                tempo: score.bpm,
                timeSignatureTop: score.beatsPerMeasure,
                timeSignatureBottom: 4,
                measures: loaded.measures
            )
            viewModel = ScoreViewModel(score: playable)
            content = loaded
        } catch {
            errorMessage = "Não foi possível abrir a partitura: \(error.localizedDescription)"
        }
    }
}
