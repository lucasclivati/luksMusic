// ReadingTrainerView.swift
// luksMusic
//
// "Treino de leitura": a few notes of one hand (or both, on a grand staff) to be found on the keyboard. Each note turns green
// when found on the first try, orange when found after a mistake or a hint; a wrong key flashes red and shows
// where it would be written. The piece is read in order (remembering where it stopped) or in random segments.

import SwiftUI

struct ReadingTrainerView: View {
    let score: Score
    /// Identifies the score for the remembered position
    let storageKey: String
    /// Opens Modo Estudo in this screen's place (the player's cover switches screens); no button when nil
    var onSwitchToPractice: (() -> Void)?

    /// Built once, when the screen appears. The player re-creates this view every time it redraws, and building
    /// the drill each time (it reads the score and saves the position, which redraws the player) never let the app
    /// settle.
    @State private var viewModel: ReadingTrainerViewModel?

    init(score: Score, storageKey: String, onSwitchToPractice: (() -> Void)? = nil) {
        self.score = score
        self.storageKey = storageKey
        self.onSwitchToPractice = onSwitchToPractice
    }

    var body: some View {
        Group {
            if let viewModel {
                ReadingTrainerScreen(viewModel: viewModel, onSwitchToPractice: onSwitchToPractice)
            } else {
                PlayerTheme.background.ignoresSafeArea()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ReadingTrainerViewModel(score: score, storageKey: storageKey)
            }
        }
    }
}

private struct ReadingTrainerScreen: View {
    @Bindable var viewModel: ReadingTrainerViewModel
    var onSwitchToPractice: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var midi = MIDIService.shared

    var body: some View {
        GeometryReader { geo in
            // A phone held sideways: the staff beside the status and the controls, a shorter keyboard below
            let compact = geo.size.height < 500
            VStack(spacing: 0) {
                PlayerTopBar(title: String(localized: "Treino de leitura"), subtitle: viewModel.title, onBack: close,
                             compact: compact) {
                    HStack(spacing: 8) {
                        if onSwitchToPractice != nil {
                            practiceButton
                        }
                        settingsMenu
                    }
                }

                if compact {
                    HStack(alignment: .top, spacing: 0) {
                        staffCard
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 6)

                        VStack(spacing: 0) {
                            setupBar
                            statusLine
                            feedbackLine
                            controls
                            statsLine
                            Spacer(minLength: 0)
                        }
                        .frame(width: min(400, geo.size.width * 0.46))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    setupBar

                    staffCard
                        .frame(maxHeight: .infinity)

                    statusLine
                    feedbackLine
                    controls
                    statsLine
                }

                if viewModel.showsKeyboard {
                    keyboard
                        .frame(height: compact
                               ? min(120, max(90, geo.size.height * 0.3))
                               : min(230, max(130, geo.size.height * 0.27)))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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

    /// Stops what the drill is playing, as closing does, and opens Modo Estudo in its place.
    private func switchToPractice() {
        viewModel.stop()
        onSwitchToPractice?()
    }

    /// Modo Estudo, with its name, next to the settings: the other way of studying the same piece.
    private var practiceButton: some View {
        Button(action: switchToPractice) {
            HStack(spacing: 5) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 14, weight: .semibold))
                Text("Modo Estudo")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(PlayerTheme.text)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
            .fixedSize()
        }
        .accessibilityLabel("Modo Estudo")
        .accessibilityIdentifier("readingPracticeButton")
    }

    // MARK: - Current Setup

    /// What is being read (hand, notes, order), changed in the settings menu, and the MIDI keyboard when one is
    /// plugged in.
    private var setupBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Text(viewModel.hand == .left ? "𝄢" : "𝄞")
                    .font(.system(size: 15, weight: .bold))
                Text("\(viewModel.hand.displayName) · \(viewModel.notes.displayName) · \(viewModel.order.displayName)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(PlayerTheme.text)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("readingSetup")

            Spacer(minLength: 4)

            if let device = midi.connectedDevices.first {
                HStack(spacing: 5) {
                    Image(systemName: "pianokeys")
                        .font(.system(size: 12, weight: .bold))
                    Text("Teclado conectado")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(PlayerTheme.green)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(PlayerTheme.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PlayerTheme.green.opacity(0.5), lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Teclado conectado: \(device.name)"))
                .accessibilityIdentifier("readingConnectedKeyboard")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(.easeOut(duration: 0.2), value: midi.connectedDevices.count)
    }

    // MARK: - Staff

    private var staffCard: some View {
        Group {
            if viewModel.steps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 30))
                        .foregroundStyle(.gray)
                    Text(viewModel.hand == .both
                         ? String(localized: "Esta partitura não tem notas.")
                         : String(localized: "A \(viewModel.hand.displayName.lowercased()) não tem notas nesta partitura."))
                        .font(.subheadline)
                        .foregroundStyle(ReadingStaffView.ink)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hand == .both {
                // Both hands: each note on its own staff, sol and fá, with the columns lined up
                GrandStaffView(
                    steps: viewModel.segment.steps,
                    accidentals: viewModel.accidentals,
                    results: viewModel.segment.results,
                    current: viewModel.segment.current,
                    keySignature: viewModel.keySignature,
                    wrongPitch: viewModel.wrongPitch,
                    listeningStep: viewModel.listeningStep
                )
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            } else {
                ReadingStaffView(
                    steps: viewModel.segment.steps,
                    accidentals: viewModel.accidentals,
                    results: viewModel.segment.results,
                    current: viewModel.segment.current,
                    clef: viewModel.clef,
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
                ? ("hand.tap", String(localized: "Toque as \(chord) notas azuis (acorde)"), PlayerTheme.text)
                : ("hand.tap", String(localized: "Toque a nota azul no teclado"), PlayerTheme.text)
        case .correct(let name):
            return ("checkmark.circle.fill", String(localized: "Certo! \(name)"), PlayerTheme.green)
        case .wrong(let name):
            return ("xmark.circle.fill", String(localized: "Você tocou \(name). Tente de novo."), Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255))
        case .revealed(let name):
            return ("lightbulb.fill", String(localized: "A nota é \(name)"), Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
        case .segmentDone(let clean, let total):
            return clean == total
                ? ("star.fill", String(localized: "Perfeito! \(total) de \(total) de primeira"), PlayerTheme.green)
                : ("flag.checkered", String(localized: "Trecho concluído: \(clean) de \(total) de primeira"), Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
        case .noNotes:
            return ("music.note", String(localized: "Escolha a outra mão"), PlayerTheme.muted)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        let done = viewModel.segment.isComplete && !viewModel.segment.steps.isEmpty
        return HStack(spacing: 8) {
            controlButton("backward.fill", label: String(localized: "Anterior"), identifier: "readingPreviousButton") {
                viewModel.previousSegment()
            }
            .disabled(!viewModel.canGoBack)
            .opacity(viewModel.canGoBack ? 1 : 0.4)

            controlButton("speaker.wave.2.fill", label: String(localized: "Ouvir"), identifier: "readingListenButton") {
                viewModel.listen()
            }

            controlButton("lightbulb", label: String(localized: "Dica"), identifier: "readingHintButton") {
                viewModel.reveal()
            }
            .disabled(viewModel.segment.isComplete)
            .opacity(viewModel.segment.isComplete ? 0.4 : 1)

            controlButton("arrow.counterclockwise", label: String(localized: "Repetir"), identifier: "readingRepeatButton") {
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
            if onSwitchToPractice != nil {
                Button(action: switchToPractice) {
                    Label("Modo Estudo", systemImage: "graduationcap")
                }

                Divider()
            }

            Picker(selection: Binding(get: { viewModel.hand }, set: { viewModel.setHand($0) })) {
                ForEach(ReadingHand.allCases) { hand in
                    Text(hand.displayName).tag(hand)
                }
            } label: {
                Label("Mão", systemImage: "hand.raised")
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("readingHandPicker")

            Picker(selection: Binding(get: { viewModel.notes }, set: { viewModel.setNotes($0) })) {
                ForEach(ReadingNotes.allCases) { notes in
                    Text(notes.displayName).tag(notes)
                }
            } label: {
                Label("Notas", systemImage: "music.quarternote.3")
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("readingNotesPicker")

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

            // Both hands read sol and fá, as the piece is written
            if viewModel.hand != .both {
                Picker(selection: Binding(get: { viewModel.clefChoice }, set: { viewModel.setClefChoice($0) })) {
                    ForEach(ClefChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                } label: {
                    Label("Clave da \(viewModel.hand.displayName.lowercased())", systemImage: "music.note")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("readingClefPicker")
            }

            if viewModel.hand != .both && viewModel.clefChoice == .automatic {
                Toggle(isOn: Binding(get: { viewModel.automaticUsesAlto }, set: { viewModel.setAutomaticUsesAlto($0) })) {
                    Label("Clave de dó na automática", systemImage: "music.note.list")
                }
            }

            Picker(selection: Binding(get: { viewModel.keyLabels }, set: { viewModel.setKeyLabels($0) })) {
                ForEach(ReadingKeyLabels.allCases) { labels in
                    Text(labels.displayName).tag(labels)
                }
            } label: {
                Label("Nomes nas teclas", systemImage: "pianokeys")
            }
            .pickerStyle(.menu)

            Toggle(isOn: Binding(get: { viewModel.showsKeyboard }, set: { value in
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.setShowsKeyboard(value) }
            })) {
                Label("Mostrar teclado na tela", systemImage: "pianokeys")
            }
            .accessibilityIdentifier("readingShowKeyboardToggle")

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
