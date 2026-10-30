// PlayerChrome.swift
// luksMusic
//
// The score player's frame, shared by local scores and the online library, drawn like the luksmusic.web.app
// player: a dark title bar above the paper and a docked control panel below it (timeline, transport, the notes
// under the cursor by hand and the keyboard), so no control ever covers the music.

import SwiftUI

/// Colors of the web player (index.html's CSS variables).
enum PlayerTheme {
    static let background = Color(red: 11 / 255, green: 17 / 255, blue: 32 / 255)
    static let panel = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    static let raised = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    static let border = Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255)
    static let blue = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    static let deepBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
    static let cyan = Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255)
    static let green = Color(red: 74 / 255, green: 222 / 255, blue: 128 / 255)
    static let text = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
    static let muted = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
}

// MARK: - Top Bar

struct PlayerTopBar<Trailing: View>: View {
    let title: String
    let subtitle: String
    var onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PlayerTheme.text)
                    .frame(width: 36, height: 36)
                    .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("Voltar")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PlayerTheme.text)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PlayerTheme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PlayerTheme.panel.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PlayerTheme.raised)
                .frame(height: 1)
        }
    }
}

/// Square icon label for the top bar's buttons and menus ("…" by default).
struct PlayerMenuLabel: View {
    var systemName: String = "ellipsis"
    var tint: Color = PlayerTheme.text

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Dock

struct PlayerDock: View {
    @Bindable var viewModel: ScoreViewModel
    @Binding var showKeyboard: Bool
    var keyboardRange: ClosedRange<Int> = 36...96
    var onMixer: () -> Void

    /// Timeline position while the finger is on the slider; the player seeks when it lets go.
    @State private var scrubProgress: Double?

    private static let speeds: [Double] = [0.5, 0.75, 1.0, 1.25]

    var body: some View {
        VStack(spacing: 0) {
            timeline
            transport
            notesUnderCursor
            if showKeyboard {
                PlayerKeyboard(
                    trebleKeys: viewModel.activeTrebleMidi,
                    bassKeys: viewModel.activeBassMidi,
                    range: keyboardRange
                )
                .frame(height: 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(PlayerTheme.panel.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PlayerTheme.raised)
                .frame(height: 1)
        }
    }

    // MARK: Timeline

    private var progress: Double {
        let total = viewModel.totalSeconds
        return total > 0 ? min(1, max(0, viewModel.elapsedSeconds / total)) : 0
    }

    private var measureCount: Int {
        max(1, viewModel.score.measureCount)
    }

    private func measureIndex(at progress: Double) -> Int {
        min(measureCount - 1, Int(progress * Double(measureCount)))
    }

    private var timeline: some View {
        let shown = scrubProgress ?? progress
        let measure = scrubProgress.map { measureIndex(at: $0) } ?? viewModel.currentMeasureIndex
        let seconds = scrubProgress.map { $0 * viewModel.totalSeconds } ?? viewModel.elapsedSeconds

        return HStack(spacing: 10) {
            Text("\(Self.clock(seconds)) / \(Self.clock(viewModel.totalSeconds))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(PlayerTheme.cyan)
                .fixedSize()

            Slider(
                value: Binding(get: { shown }, set: { scrubProgress = $0 }),
                in: 0...1,
                onEditingChanged: { editing in
                    guard !editing, let target = scrubProgress else { return }
                    viewModel.seek(toMeasure: measureIndex(at: target), beat: 1.0)
                    scrubProgress = nil
                }
            )
            .tint(PlayerTheme.cyan)
            .accessibilityLabel("Posição na música")

            Text("Compasso \(measure + 1)/\(measureCount)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PlayerTheme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
                .fixedSize()
                .accessibilityIdentifier("measureBadge")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private static func clock(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 0) {
            controlButton("repeat", label: "Repetir", isOn: viewModel.isLooping) {
                viewModel.isLooping.toggle()
            }
            Spacer(minLength: 4)
            controlButton("backward.end.fill", label: "Voltar ao início") {
                viewModel.restart()
            }
            Spacer(minLength: 4)
            controlButton("backward.frame.fill", label: "Nota anterior", identifier: "previousNoteButton") {
                viewModel.stepBackward()
            }
            Spacer(minLength: 4)

            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: viewModel.isPlaying ? 0 : 2)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(LinearGradient(colors: [PlayerTheme.blue, PlayerTheme.deepBlue], startPoint: .top, endPoint: .bottom))
                    )
                    .shadow(color: PlayerTheme.blue.opacity(0.6), radius: 10)
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pausar" : "Tocar")
            .accessibilityIdentifier("playPauseButton")

            Spacer(minLength: 4)
            controlButton("forward.frame.fill", label: "Próxima nota", identifier: "nextNoteButton") {
                viewModel.stepForward()
            }
            Spacer(minLength: 4)

            Menu {
                Picker("Velocidade", selection: $viewModel.playbackSpeed) {
                    ForEach(Self.speeds, id: \.self) { speed in
                        Text(Self.speedLabel(speed)).tag(speed)
                    }
                }
            } label: {
                Text(Self.speedLabel(viewModel.playbackSpeed))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(viewModel.playbackSpeed == 1.0 ? PlayerTheme.text : PlayerTheme.cyan)
                    .frame(width: 40, height: 36)
                    .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Velocidade")

            Spacer(minLength: 4)
            controlButton("slider.vertical.3", label: "Mixer de mãos", action: onMixer)
            Spacer(minLength: 4)
            controlButton("pianokeys", label: "Teclado", isOn: showKeyboard, identifier: "keyboardToggleButton") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showKeyboard.toggle()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func controlButton(_ systemName: String, label: String, isOn: Bool = false, identifier: String? = nil,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? PlayerTheme.cyan : PlayerTheme.text)
                .frame(width: 36, height: 36)
                .background(isOn ? PlayerTheme.cyan.opacity(0.15) : PlayerTheme.raised,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isOn ? PlayerTheme.cyan.opacity(0.6) : PlayerTheme.border, lineWidth: 1))
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? label)
    }

    private static func speedLabel(_ speed: Double) -> String {
        switch speed {
        case 0.5: return "0,5×"
        case 0.75: return "0,75×"
        case 1.25: return "1,25×"
        default: return "1×"
        }
    }

    // MARK: Notes Under the Cursor

    private var notesUnderCursor: some View {
        HStack(spacing: 14) {
            hand("Mão dir.", names: viewModel.trebleNoteNames, color: PlayerTheme.cyan)
            hand("Mão esq.", names: viewModel.bassNoteNames, color: PlayerTheme.green)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("notesUnderCursor")
    }

    private func hand(_ title: String, names: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(names.isEmpty ? "pausa" : names)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(names.isEmpty ? PlayerTheme.muted : PlayerTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Hands Mixer

struct HandsMixerSheet: View {
    @Bindable var viewModel: ScoreViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                channel(symbol: "𝄞", title: "Mão direita (clave de sol)", color: PlayerTheme.cyan,
                        volume: $viewModel.trebleVolume, muted: $viewModel.trebleMuted)
                channel(symbol: "𝄢", title: "Mão esquerda (clave de fá)", color: PlayerTheme.green,
                        volume: $viewModel.bassVolume, muted: $viewModel.bassMuted)

                HStack(spacing: 8) {
                    preset("Duas mãos", treble: true, bass: true)
                    preset("Só direita", treble: true, bass: false)
                    preset("Só esquerda", treble: false, bass: true)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .background(PlayerTheme.panel.ignoresSafeArea())
            .navigationTitle("Mixer de mãos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func channel(symbol: String, title: String, color: Color, volume: Binding<Double>, muted: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Text(symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PlayerTheme.text)
                Slider(value: volume, in: 0...1)
                    .tint(color)
                    .disabled(muted.wrappedValue)
            }

            Button(muted.wrappedValue ? "Mudo" : "Silenciar") {
                muted.wrappedValue.toggle()
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(muted.wrappedValue ? Color.red : PlayerTheme.raised, in: Capsule())
            .foregroundStyle(.white)
        }
    }

    private func preset(_ title: String, treble: Bool, bass: Bool) -> some View {
        let selected = viewModel.trebleMuted == !treble && viewModel.bassMuted == !bass
        return Button(title) {
            viewModel.trebleMuted = !treble
            viewModel.bassMuted = !bass
        }
        .font(.footnote.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(selected ? PlayerTheme.blue : PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundStyle(.white)
    }
}
