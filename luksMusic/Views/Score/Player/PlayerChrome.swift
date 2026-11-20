// PlayerChrome.swift
// luksMusic
//
// The score player's frame, drawn like the luksmusic.web.app player: a dark title bar above the paper and a docked
// control panel below it (timeline, transport, the notes under the cursor by hand and the keyboard), so no control
// ever covers the music.

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
    /// The metronome's light on the first beat of a measure and on the others
    static let downbeat = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let beat = Color(red: 234 / 255, green: 179 / 255, blue: 8 / 255)
}

// MARK: - Top Bar

struct PlayerTopBar<Trailing: View>: View {
    let title: String
    let subtitle: String
    var onBack: () -> Void
    /// Slimmer bar for a phone held sideways, where every point of height goes to the music
    var compact: Bool = false
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
        .padding(.vertical, compact ? 4 : 8)
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
    /// A phone held sideways: one row with the timeline and the transport, no notes row and a short keyboard, so
    /// the engraving keeps most of the height
    var compact: Bool = false
    var onMixer: () -> Void

    /// Timeline position while the finger is on the slider; the player seeks when it lets go.
    @State private var scrubProgress: Double?
    /// The metronome's light, on for a moment at each click
    @State private var metronomeLight: Color?

    private static let speeds: [Double] = [0.5, 0.75, 1.0, 1.25]

    var body: some View {
        VStack(spacing: 0) {
            if compact {
                compactControls
            } else {
                timeline
                transport
                notesUnderCursor
            }
            if showKeyboard {
                PlayerKeyboard(
                    trebleKeys: viewModel.activeTrebleMidi,
                    bassKeys: viewModel.activeBassMidi,
                    range: keyboardRange
                )
                .frame(height: compact ? 64 : 100)
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

    /// The slider's position, the measure and the time shown: where the finger is while scrubbing, else the player's.
    private var shownProgress: Double {
        scrubProgress ?? progress
    }

    private var shownMeasure: Int {
        scrubProgress.map { measureIndex(at: $0) } ?? viewModel.currentMeasureIndex
    }

    private var shownSeconds: Double {
        scrubProgress.map { $0 * viewModel.totalSeconds } ?? viewModel.elapsedSeconds
    }

    private var timeline: some View {
        HStack(spacing: 10) {
            clockLabel
            scrubber
            measureBadge
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var clockLabel: some View {
        Text("\(Self.clock(shownSeconds)) / \(Self.clock(viewModel.totalSeconds))")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(PlayerTheme.cyan)
            .fixedSize()
    }

    private var scrubber: some View {
        Slider(
            value: Binding(get: { shownProgress }, set: { scrubProgress = $0 }),
            in: 0...1,
            onEditingChanged: { editing in
                guard !editing, let target = scrubProgress else { return }
                viewModel.seek(toMeasure: measureIndex(at: target), beat: 1.0)
                scrubProgress = nil
            }
        )
        .tint(PlayerTheme.cyan)
        .accessibilityLabel("Posição na música")
    }

    private var measureBadge: some View {
        Text("Compasso \(shownMeasure + 1)/\(measureCount)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(PlayerTheme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
            .fixedSize()
            .accessibilityIdentifier("measureBadge")
    }

    private static func clock(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 0) {
            repeatButton
            Spacer(minLength: 4)
            restartButton
            Spacer(minLength: 4)
            previousNoteButton
            Spacer(minLength: 4)
            playButton(diameter: 48)
            Spacer(minLength: 4)
            nextNoteButton
            Spacer(minLength: 4)
            speedMenu
            Spacer(minLength: 4)
            metronomeButton
            Spacer(minLength: 4)
            mixerButton
            Spacer(minLength: 4)
            keyboardButton
        }
        // Nine controls fit a 375-point-wide phone
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    /// Sideways: the transport around the timeline in a single row (the clock gives its room to the slider).
    private var compactControls: some View {
        HStack(spacing: 6) {
            repeatButton
            restartButton
            previousNoteButton
            playButton(diameter: 38)
            nextNoteButton
            scrubber
                .frame(minWidth: 80)
                .padding(.horizontal, 4)
            measureBadge
            speedMenu
            metronomeButton
            mixerButton
            keyboardButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var restartButton: some View {
        controlButton("backward.end.fill",
                      label: viewModel.loopMode == .measure
                          ? String(localized: "Voltar ao início do compasso") : String(localized: "Voltar ao início"),
                      identifier: "Voltar ao início") {
            viewModel.restart()
        }
    }

    private var previousNoteButton: some View {
        controlButton("backward.frame.fill", label: String(localized: "Nota anterior"), identifier: "previousNoteButton") {
            viewModel.stepBackward()
        }
    }

    private var nextNoteButton: some View {
        controlButton("forward.frame.fill", label: String(localized: "Próxima nota"), identifier: "nextNoteButton") {
            viewModel.stepForward()
        }
    }

    private func playButton(diameter: CGFloat) -> some View {
        let large = diameter >= 48
        return Button {
            viewModel.togglePlayback()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: large ? 19 : 16, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: viewModel.isPlaying ? 0 : 2)
                .frame(width: diameter, height: diameter)
                .background(
                    Circle().fill(LinearGradient(colors: [PlayerTheme.blue, PlayerTheme.deepBlue], startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: PlayerTheme.blue.opacity(0.6), radius: large ? 10 : 6)
        }
        .accessibilityLabel(viewModel.isPlaying ? String(localized: "Pausar") : String(localized: "Tocar"))
        .accessibilityIdentifier("playPauseButton")
    }

    private var speedMenu: some View {
        Menu {
            Picker("Velocidade", selection: $viewModel.playbackSpeed) {
                ForEach(Self.speeds, id: \.self) { speed in
                    Text(Self.speedLabel(speed)).tag(speed)
                }
            }
        } label: {
            Text(Self.speedLabel(viewModel.playbackSpeed))
                .font(.system(size: 13, weight: .bold))
                .minimumScaleFactor(0.8)
                .foregroundStyle(viewModel.playbackSpeed == 1.0 ? PlayerTheme.text : PlayerTheme.cyan)
                .frame(width: 38, height: 36)
                .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
        }
        .accessibilityLabel("Velocidade")
    }

    private var mixerButton: some View {
        controlButton("slider.vertical.3", label: String(localized: "Mixer de mãos"), identifier: "Mixer de mãos", action: onMixer)
    }

    private var keyboardButton: some View {
        controlButton("pianokeys", label: String(localized: "Teclado"), isOn: showKeyboard, identifier: "keyboardToggleButton") {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showKeyboard.toggle()
            }
        }
    }

    /// Switches between no repeat, the measure under the cursor and the whole piece, like the web player's loop button.
    private var repeatButton: some View {
        let mode = viewModel.loopMode
        let label: String
        switch mode {
        case .off: label = String(localized: "Repetir: desligado")
        case .measure: label = String(localized: "Repetir: compasso")
        case .piece: label = String(localized: "Repetir: música")
        }
        return controlButton(mode == .measure ? "repeat.1" : "repeat", label: label, isOn: mode != .off,
                             identifier: "repeatButton") {
            viewModel.loopMode = viewModel.loopMode.next
        }
    }

    /// Clicks on every beat while the piece plays, like the web player's metronome; its light flashes red on the
    /// first beat of the measure and yellow on the others.
    private var metronomeButton: some View {
        controlButton(viewModel.isMetronomeOn ? "metronome.fill" : "metronome", label: String(localized: "Metrônomo"),
                      isOn: viewModel.isMetronomeOn, identifier: "metronomeButton") {
            viewModel.isMetronomeOn.toggle()
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(metronomeLight ?? Color.clear)
                .frame(width: 7, height: 7)
                .shadow(color: metronomeLight ?? Color.clear, radius: 4)
                .padding(4)
                .allowsHitTesting(false)
        }
        .onChange(of: viewModel.metronomeClicks) { _, clicks in
            metronomeLight = viewModel.metronomeAccent ? PlayerTheme.downbeat : PlayerTheme.beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if viewModel.metronomeClicks == clicks {
                    metronomeLight = nil
                }
            }
        }
    }

    private func controlButton(_ systemName: String, label: String, isOn: Bool = false, identifier: String? = nil,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? PlayerTheme.cyan : PlayerTheme.text)
                .frame(width: 34, height: 36)
                .background(isOn ? PlayerTheme.cyan.opacity(0.15) : PlayerTheme.raised,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isOn ? PlayerTheme.cyan.opacity(0.6) : PlayerTheme.border, lineWidth: 1))
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? label)
    }

    /// The decimal separator follows the app's language (0,5× in Portuguese, 0.5× in English).
    private static func speedLabel(_ speed: Double) -> String {
        switch speed {
        case 0.5: return String(localized: "0,5×")
        case 0.75: return String(localized: "0,75×")
        case 1.25: return String(localized: "1,25×")
        default: return "1×"
        }
    }

    // MARK: Notes Under the Cursor

    private var notesUnderCursor: some View {
        HStack(spacing: 14) {
            hand(String(localized: "Mão dir."), names: viewModel.trebleNoteNames, color: PlayerTheme.cyan)
            hand(String(localized: "Mão esq."), names: viewModel.bassNoteNames, color: PlayerTheme.green)
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
            Text(names.isEmpty ? String(localized: "pausa") : names)
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
                channel(symbol: "𝄞", title: String(localized: "Mão direita"), color: PlayerTheme.cyan,
                        volume: $viewModel.trebleVolume, muted: $viewModel.trebleMuted)
                channel(symbol: "𝄢", title: String(localized: "Mão esquerda"), color: PlayerTheme.green,
                        volume: $viewModel.bassVolume, muted: $viewModel.bassMuted)

                HStack(spacing: 8) {
                    preset(String(localized: "Duas mãos"), treble: true, bass: true)
                    preset(String(localized: "Só direita"), treble: true, bass: false)
                    preset(String(localized: "Só esquerda"), treble: false, bass: true)
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

            Button(muted.wrappedValue ? String(localized: "Mudo") : String(localized: "Silenciar")) {
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
