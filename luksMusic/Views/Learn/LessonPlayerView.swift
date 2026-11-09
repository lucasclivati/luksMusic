// LessonPlayerView.swift
// luksMusic
//
// One lesson on screen: its explanation, the staff, whether the note played was right, and the keyboard. Notes can
// be played on the screen, on a USB keyboard, or on a real piano with the microphone on.

import SwiftUI

struct LessonPlayerView: View {
    @State private var viewModel: LessonPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    init(lesson: Lesson) {
        _viewModel = State(initialValue: LessonPlayerViewModel(lesson: lesson))
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                PlayerTopBar(title: viewModel.lesson.title, subtitle: subtitle, onBack: close) {
                    microphoneButton
                }

                ProgressView(value: viewModel.progress)
                    .tint(PlayerTheme.cyan)

                if viewModel.isFinished {
                    finishedView
                } else {
                    lessonContent
                        .frame(maxHeight: .infinity)

                    keyboard
                        .frame(height: min(220, max(130, geo.size.height * 0.26)))
                }
            }
        }
        .background(PlayerTheme.background.ignoresSafeArea())
        .onDisappear {
            viewModel.stop()
        }
    }

    private var subtitle: String {
        viewModel.isFinished ? "Aula concluída" : "Passo \(viewModel.stepIndex + 1) de \(viewModel.lesson.steps.count)"
    }

    private func close() {
        viewModel.stop()
        dismiss()
    }

    // MARK: - Step

    private var lessonContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.step.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PlayerTheme.text)
                Text(viewModel.step.text)
                    .font(.system(size: 15))
                    .foregroundStyle(PlayerTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if !viewModel.step.notes.isEmpty {
                ReadingStaffView(
                    steps: viewModel.segment.steps,
                    accidentals: viewModel.accidentals,
                    results: viewModel.segment.results,
                    current: viewModel.step.isExercise ? viewModel.segment.current : viewModel.segment.steps.count,
                    staff: viewModel.step.staff,
                    keySignature: 0,
                    wrongPitch: viewModel.wrongPitch,
                    listeningStep: viewModel.demoNote,
                    showsAllNames: viewModel.step.kind == .explain || viewModel.step.kind == .guided
                )
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .frame(minHeight: 110, maxHeight: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
            } else {
                Spacer(minLength: 0)
            }

            inputStatus
            feedbackLine
            actions
        }
    }

    /// Where the notes are coming from.
    @ViewBuilder
    private var inputStatus: some View {
        if let message = viewModel.microphoneMessage {
            statusText(message, symbol: "exclamationmark.triangle.fill", color: .orange)
        } else if let name = viewModel.connectedKeyboardName {
            statusText("Teclado conectado: \(name)", symbol: "cable.connector", color: PlayerTheme.green)
        } else if viewModel.usesMicrophone {
            statusText("Microfone ligado: toque uma nota por vez, em um lugar silencioso", symbol: "mic.fill", color: PlayerTheme.green)
        }
    }

    private func statusText(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lessonInputStatus")
    }

    @ViewBuilder
    private var feedbackLine: some View {
        if let content = feedbackContent {
            HStack(spacing: 8) {
                Image(systemName: content.symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(content.text)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(content.color)
            .padding(.horizontal, 14)
            .frame(minHeight: 28)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("lessonFeedback")
        }
    }

    private var feedbackContent: (symbol: String, text: String, color: Color)? {
        let amber = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
        switch viewModel.feedback {
        case .none:
            return nil
        case .prompt:
            return ("hand.tap", viewModel.step.kind == .guided ? "Toque a tecla acesa" : "Toque a nota azul", PlayerTheme.text)
        case .correct(let name):
            return ("checkmark.circle.fill", "Certo! \(name)", PlayerTheme.green)
        case .wrong(let name):
            return ("xmark.circle.fill", "Você tocou \(name). Tente de novo.", Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255))
        case .revealed(let name):
            return ("lightbulb.fill", "A nota é \(name). A tecla está acesa.", amber)
        case .listening:
            return ("ear", "Ouça…", PlayerTheme.cyan)
        case .yourTurn:
            return ("hand.tap", "Sua vez: toque as notas da pauta", PlayerTheme.text)
        case .stepDone(let clean, let total):
            return clean == total
                ? ("star.fill", "Muito bem! Todas certas de primeira", PlayerTheme.green)
                : ("flag.checkered", "\(clean) de \(total) certas de primeira", amber)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if viewModel.step.kind == .listen {
                secondaryButton("Ouvir", symbol: "speaker.wave.2.fill", identifier: "lessonListenButton") {
                    viewModel.playDemo()
                }
                .disabled(viewModel.isDemonstrating)
            }
            if viewModel.showsRepeat {
                secondaryButton("Repetir", symbol: "arrow.counterclockwise", identifier: "lessonRepeatButton") {
                    viewModel.repeatStep()
                }
            }
            Spacer(minLength: 0)
            if viewModel.showsContinue {
                Button {
                    viewModel.continueLesson()
                } label: {
                    Text("Continuar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26)
                        .frame(height: 42)
                        .background(PlayerTheme.deepBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityIdentifier("lessonContinueButton")
            }
        }
        .frame(minHeight: 42)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func secondaryButton(_ title: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PlayerTheme.text)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityIdentifier(identifier)
    }

    private var microphoneButton: some View {
        Button {
            viewModel.setMicrophone(on: !viewModel.usesMicrophone)
        } label: {
            PlayerMenuLabel(systemName: viewModel.usesMicrophone ? "mic.fill" : "mic.slash",
                            tint: viewModel.usesMicrophone ? PlayerTheme.green : PlayerTheme.text)
        }
        .accessibilityLabel(viewModel.usesMicrophone ? "Desligar microfone" : "Ligar microfone")
        .accessibilityIdentifier("lessonMicrophoneButton")
    }

    // MARK: - Keyboard

    private var keyboard: some View {
        GeometryReader { geo in
            PianoKeyboardView(
                viewModel: viewModel.keyboard,
                onKeyPress: { note in viewModel.screenKeyPressed(note) },
                onKeyRelease: { note in viewModel.screenKeyReleased(note) }
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
        .accessibilityIdentifier("lessonKeyboard")
    }

    private static func whiteKeyCount(for width: CGFloat) -> Int {
        max(10, min(36, Int(width / 26)))
    }

    // MARK: - End of the Lesson

    private var finishedView: some View {
        VStack(spacing: 18) {
            Spacer()
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { star in
                    Image(systemName: star <= viewModel.stars ? "star.fill" : "star")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.stars) de 3 estrelas")

            Text("Aula concluída")
                .font(.title2.weight(.bold))
                .foregroundStyle(PlayerTheme.text)
            Text("\(viewModel.cleanNotes) de \(viewModel.totalNotes) notas certas de primeira")
                .font(.subheadline)
                .foregroundStyle(PlayerTheme.muted)

            VStack(spacing: 10) {
                if let next = viewModel.nextLesson {
                    Button {
                        viewModel.open(next)
                    } label: {
                        Text("Próxima aula: \(next.title)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(PlayerTheme.deepBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .accessibilityIdentifier("lessonNextButton")
                }
                Button("Refazer a aula") {
                    viewModel.restartLesson()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PlayerTheme.cyan)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
