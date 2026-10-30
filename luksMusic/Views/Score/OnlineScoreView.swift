// OnlineScoreView.swift
// luksMusic
//
// A score from the online library shown with its original engraved pages, exactly as on luksmusic.web.app,
// with the native player, cursor and interactive keyboard. Controls fade out while the music plays.

import SwiftUI

struct OnlineScoreView: View {
    let score: OnlineScore

    @State private var content: OnlineScoreContent?
    @State private var viewModel: ScoreViewModel?
    @State private var errorMessage: String?
    @State private var showKeyboard: Bool = true
    @State private var keyboardViewModel = PianoKeyboardViewModel(rangeStart: 36, rangeEnd: 96)
    @Environment(\.dismiss) private var dismiss

    private let accentPurple = Color(red: 48/255, green: 26/255, blue: 73/255)

    /// Room the page leaves under the floating controls so the last system can scroll above them.
    private var bottomInset: CGFloat {
        110 + (showKeyboard ? 140 : 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // The app runs in dark mode (white status bar text), so the paper stops below the status bar
            accentPurple.ignoresSafeArea()
            Color.white.ignoresSafeArea(edges: .bottom)

            if let content, let viewModel {
                PageScoreWebView(
                    pageURLs: score.pageURLs,
                    content: content,
                    beatsPerMeasure: score.beatsPerMeasure,
                    measureIndex: viewModel.currentMeasureIndex,
                    cursorBeat: viewModel.cursorBeat,
                    topInset: 64,
                    bottomInset: bottomInset
                ) { measure, beat in
                    viewModel.seek(toMeasure: measure, beat: beat)
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 8) {
                    Spacer()
                    if showKeyboard {
                        keyboardDock
                    }
                    transportBar(viewModel)
                        .padding(.bottom, 12)
                }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                    Button("Tentar de novo") {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentPurple)
                }
                .foregroundColor(.black)
                .padding(32)
                .frame(maxHeight: .infinity)
            } else {
                ProgressView("Carregando partitura…")
                    .frame(maxHeight: .infinity)
            }

            topBar
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // Controls drawn over the white paper use light-mode colors
        .environment(\.colorScheme, .light)
        .task {
            if content == nil {
                await load()
            }
        }
        .onChange(of: viewModel?.activeMidiNotes ?? [], initial: true) { _, activeMidi in
            keyboardViewModel.midiActiveKeys = activeMidi
        }
        .onDisappear {
            viewModel?.stop()
        }
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

    // MARK: - Top Bar

    /// Back button and title; hidden while playing so they never cover the notes being read.
    @ViewBuilder
    private var topBar: some View {
        let isPlaying = viewModel?.isPlaying ?? false
        HStack(spacing: 12) {
            Button {
                viewModel?.stop()
                dismiss()
            } label: {
                Circle()
                    .fill(accentPurple)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            }
            .accessibilityLabel("Voltar")

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .opacity(isPlaying ? 0 : 1)
        .allowsHitTesting(!isPlaying)
        .animation(.easeInOut(duration: 0.25), value: isPlaying)
    }

    // MARK: - Keyboard

    @ViewBuilder
    private var keyboardDock: some View {
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

    // MARK: - Transport

    private func transportBar(_ viewModel: ScoreViewModel) -> some View {
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

            Menu {
                ForEach([0.5, 0.75, 1.0], id: \.self) { speed in
                    Button {
                        viewModel.playbackSpeed = speed
                    } label: {
                        if viewModel.playbackSpeed == speed {
                            Label(speedLabel(speed), systemImage: "checkmark")
                        } else {
                            Text(speedLabel(speed))
                        }
                    }
                }
            } label: {
                Image(systemName: "speedometer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Velocidade")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(accentPurple)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        )
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == 1.0 ? "1×" : (speed == 0.5 ? "0,5×" : "0,75×")
    }
}
