// ReadingTrainerView.swift
// luksMusic
//
// "Treino de leitura": a few notes of one hand on a staff, to be found on the keyboard. Each note turns green
// when found on the first try, orange when found after a mistake or a hint; a wrong key flashes red and shows
// where it would be written. The piece is read in order (remembering where it stopped) or in random segments.

import SwiftUI

struct ReadingTrainerView: View {
    @State private var viewModel: ReadingTrainerViewModel
    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - storageKey: identifies the score for the remembered position
    ///   - spellsFromKey: the score only has MIDI numbers (online scores), so notes are named for its likely key
    init(score: Score, storageKey: String, spellsFromKey: Bool = false) {
        _viewModel = State(initialValue: ReadingTrainerViewModel(score: score, storageKey: storageKey, spellsFromKey: spellsFromKey))
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                PlayerTopBar(title: "Treino de leitura", subtitle: viewModel.title, onBack: close) {
                    settingsMenu
                }

                handBar

                staffCard
                    .frame(maxHeight: .infinity)

                statusLine
                feedbackLine
                controls
                statsLine

                keyboard
                    .frame(height: min(230, max(130, geo.size.height * 0.27)))
            }
        }
        .background(PlayerTheme.background.ignoresSafeArea())
        .onDisappear {
            viewModel.stop()
        }
    }

    private func close() {
        viewModel.stop()
        dismiss()
    }

    // MARK: - Hand and Order

    private var handBar: some View {
        HStack(spacing: 8) {
            ForEach(ReadingHand.allCases) { hand in
                let selected = viewModel.hand == hand
                let tint = hand == .right ? PlayerTheme.cyan : PlayerTheme.green
                Button {
                    viewModel.setHand(hand)
                } label: {
                    HStack(spacing: 5) {
                        Text(hand == .right ? "𝄞" : "𝄢")
                            .font(.system(size: 16, weight: .bold))
                        Text(hand.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected ? PlayerTheme.background : PlayerTheme.text)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(selected ? tint : PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? tint : PlayerTheme.border, lineWidth: 1))
                }
                .accessibilityIdentifier(hand == .right ? "readingRightHand" : "readingLeftHand")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }

            Spacer(minLength: 4)

            Menu {
                Picker("Ordem", selection: Binding(get: { viewModel.order }, set: { viewModel.setOrder($0) })) {
                    ForEach(ReadingOrder.allCases) { order in
                        Label(order.displayName, systemImage: order == .sequential ? "arrow.right" : "shuffle")
                            .tag(order)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.order == .sequential ? "arrow.right" : "shuffle")
                    Text(viewModel.order.displayName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PlayerTheme.text)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Ordem dos trechos")
            .accessibilityIdentifier("readingOrderMenu")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Staff

    private var staffCard: some View {
        Group {
            if viewModel.steps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 30))
                        .foregroundStyle(.gray)
                    Text("A \(viewModel.hand.displayName.lowercased()) não tem notas nesta partitura.")
                        .font(.subheadline)
                        .foregroundStyle(ReadingStaffView.ink)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ReadingStaffView(
                    steps: viewModel.segment.steps,
                    accidentals: viewModel.accidentals,
                    results: viewModel.segment.results,
                    current: viewModel.segment.current,
                    staff: viewModel.hand.staff,
                    keySignature: viewModel.keySignature,
                    wrongPitch: viewModel.wrongPitch,
                    listeningStep: viewModel.listeningStep
                )
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .frame(minHeight: 120)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
    }

    // MARK: - Status and Feedback

    private var statusLine: some View {
        HStack {
            Group {
                if viewModel.order == .sequential && viewModel.segmentCount > 0 {
                    Text("Trecho \(viewModel.segmentNumber) de \(viewModel.segmentCount) • \(viewModel.measuresLabel)")
                } else {
                    Text(viewModel.measuresLabel)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PlayerTheme.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            if !viewModel.segment.steps.isEmpty {
                let total = viewModel.segment.steps.count
                Text("Nota \(min(viewModel.segment.current + 1, total)) de \(total)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PlayerTheme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var feedbackLine: some View {
        let (symbol, text, color) = feedbackContent
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("readingFeedback")
        .animation(.easeOut(duration: 0.15), value: viewModel.feedback)
    }

    private var feedbackContent: (String, String, Color) {
        switch viewModel.feedback {
        case .prompt(let chord):
            return chord > 1
                ? ("hand.tap", "Toque as \(chord) notas azuis (acorde)", PlayerTheme.text)
                : ("hand.tap", "Toque a nota azul no teclado", PlayerTheme.text)
        case .correct(let name):
            return ("checkmark.circle.fill", "Certo! \(name)", PlayerTheme.green)
        case .wrong(let name):
            return ("xmark.circle.fill", "Você tocou \(name). Tente de novo.", Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255))
        case .revealed(let name):
            return ("lightbulb.fill", "A nota é \(name)", Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
        case .segmentDone(let clean, let total):
            return clean == total
                ? ("star.fill", "Perfeito! \(total) de \(total) de primeira", PlayerTheme.green)
                : ("flag.checkered", "Trecho concluído: \(clean) de \(total) de primeira", Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
        case .noNotes:
            return ("music.note", "Escolha a outra mão", PlayerTheme.muted)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        let done = viewModel.segment.isComplete && !viewModel.segment.steps.isEmpty
        return HStack(spacing: 8) {
            controlButton("backward.fill", label: "Trecho anterior", identifier: "readingPreviousButton") {
                viewModel.previousSegment()
            }
            .disabled(!viewModel.canGoBack)
            .opacity(viewModel.canGoBack ? 1 : 0.4)

            controlButton("speaker.wave.2.fill", label: "Ouvir", identifier: "readingListenButton") {
                viewModel.listen()
            }

            controlButton("lightbulb", label: "Dica", identifier: "readingHintButton") {
                viewModel.reveal()
            }
            .disabled(viewModel.segment.isComplete)
            .opacity(viewModel.segment.isComplete ? 0.4 : 1)

            controlButton("arrow.counterclockwise", label: "Repetir", identifier: "readingRepeatButton") {
                viewModel.repeatSegment()
            }

            Button {
                viewModel.nextSegment()
            } label: {
                HStack(spacing: 6) {
                    Text("Próximo")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(done ? AnyShapeStyle(LinearGradient(colors: [PlayerTheme.blue, PlayerTheme.deepBlue], startPoint: .top, endPoint: .bottom))
                                   : AnyShapeStyle(PlayerTheme.raised))
                )
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(done ? PlayerTheme.blue : PlayerTheme.border, lineWidth: 1))
                .shadow(color: done ? PlayerTheme.blue.opacity(0.5) : .clear, radius: 8)
            }
            .accessibilityLabel("Próximo trecho")
            .accessibilityIdentifier("readingNextButton")
            .disabled(viewModel.steps.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func controlButton(_ systemName: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(PlayerTheme.text)
            .frame(width: 50, height: 40)
            .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Session Results

    private var statsLine: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(PlayerTheme.green)
                Text(viewModel.answered == 0
                     ? "De primeira: –"
                     : "De primeira: \(viewModel.cleanPercentage)% (\(viewModel.answeredClean)/\(viewModel.answered))")
            }
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Sequência \(viewModel.streak)")
            }
            if viewModel.bestStreak > 0 {
                Text("Recorde \(viewModel.bestStreak)")
                    .foregroundStyle(PlayerTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(PlayerTheme.text)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Keyboard

    private var keyboard: some View {
        GeometryReader { geo in
            PianoKeyboardView(
                viewModel: viewModel.keyboard,
                onKeyPress: { midi in viewModel.keyPressed(midi) },
                onKeyRelease: { midi in viewModel.keyReleased(midi) }
            )
            .onAppear {
                viewModel.setWhiteKeyCount(Self.whiteKeyCount(for: geo.size.width))
            }
            .onChange(of: geo.size.width) { _, width in
                viewModel.setWhiteKeyCount(Self.whiteKeyCount(for: width))
            }
        }
        .padding(.horizontal, 2)
        .background(PlayerTheme.panel.ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("readingKeyboard")
    }

    /// About 26 points per white key: two octaves on a phone held upright, more on its side.
    private static func whiteKeyCount(for width: CGFloat) -> Int {
        max(10, min(36, Int(width / 26)))
    }

    // MARK: - Settings

    private var settingsMenu: some View {
        Menu {
            Picker(selection: Binding(get: { viewModel.order }, set: { viewModel.setOrder($0) })) {
                ForEach(ReadingOrder.allCases) { order in
                    Text(order.displayName).tag(order)
                }
            } label: {
                Label("Ordem", systemImage: "arrow.left.arrow.right")
            }
            .pickerStyle(.menu)

            Picker(selection: Binding(get: { viewModel.segmentSize }, set: { viewModel.setSegmentSize($0) })) {
                ForEach(ReadingTrainerViewModel.segmentSizes, id: \.self) { size in
                    Text(size == 1 ? "1 nota" : "\(size) notas").tag(size)
                }
            } label: {
                Label("Notas por trecho", systemImage: "music.note.list")
            }
            .pickerStyle(.menu)

            Picker(selection: Binding(get: { viewModel.keyLabels }, set: { viewModel.setKeyLabels($0) })) {
                ForEach(ReadingKeyLabels.allCases) { labels in
                    Text(labels.displayName).tag(labels)
                }
            } label: {
                Label("Nomes nas teclas", systemImage: "pianokeys")
            }
            .pickerStyle(.menu)

            Toggle(isOn: Binding(get: { viewModel.advancesAutomatically }, set: { viewModel.setAdvancesAutomatically($0) })) {
                Label("Avançar sozinho ao acertar tudo", systemImage: "forward.end")
            }

            if viewModel.order == .sequential {
                Button {
                    viewModel.restartPiece()
                } label: {
                    Label("Voltar ao início da música", systemImage: "backward.end.fill")
                }
            }
        } label: {
            PlayerMenuLabel(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel("Ajustes do treino")
        .accessibilityIdentifier("readingSettingsMenu")
    }
}
