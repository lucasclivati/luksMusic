// LessonPlayerView.swift
// luksMusic
//
// One lesson on screen: what the step is (a badge), what to do, the staff, whether the note played was right, and the
// keyboard. A finished step shows a result card with what comes next. Notes can be played on the screen, on a USB
// keyboard, or on a real piano with the microphone on.

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
        .onAppear {
            viewModel.activate()
        }
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
                HStack(spacing: 8) {
                    let badge = stepBadge
                    Label(badge.text, systemImage: badge.symbol)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(badge.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badge.color.opacity(0.16), in: Capsule())
                        .accessibilityIdentifier("lessonStepBadge")
                    if viewModel.pages.count > 1 {
                        Text("Parte \(viewModel.pageNumber) de \(viewModel.pages.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PlayerTheme.muted)
                    }
                }
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

            if viewModel.segment.steps.isEmpty {
                Spacer(minLength: 0)
            } else {
                staff
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .frame(minHeight: 110, maxHeight: .infinity)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 12)
            }

            inputStatus
            if viewModel.isStepDone {
                resultCard
            } else {
                feedbackLine
                actions
            }
        }
    }

    private static let amber = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
    private static let violet = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)

    /// What kind of step this is, so learning, practice and music look different at a glance.
    private var stepBadge: (text: String, symbol: String, color: Color) {
        let step = viewModel.step
        switch step.kind {
        case .learn:
            return ("APRENDA", "lightbulb.fill", PlayerTheme.cyan)
        case .read:
            if step.isDrill { return ("TREINO", "target", PlayerTheme.green) }
            if step.isPiece { return ("MÚSICA", "music.note", Self.amber) }
            return ("LEITURA", "eye.fill", PlayerTheme.green)
        case .listen:
            return ("OUVIDO", "ear.fill", Self.violet)
        case .rhythm:
            return ("RITMO", "metronome.fill", Self.amber)
        case .playAlong:
            return ("TOCANDO JUNTO", "music.quarternote.3", Self.amber)
        }
    }

    /// The step's result, what comes next, and the buttons to go on or try again.
    private var resultCard: some View {
        var clean = 0
        var total = 0
        if case .stepDone(let right, let all) = viewModel.feedback {
            clean = right
            total = all
        }
        // Learning a note is never wrong
        let perfect = !viewModel.step.isScored || clean == total
        let headline = !viewModel.step.isScored ? "Muito bem!"
            : (perfect ? "Todas certas de primeira!" : "\(clean) de \(total) certas de primeira")
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: perfect ? "star.fill" : "flag.checkered")
                    .font(.system(size: 17, weight: .semibold))
                Text(headline)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(perfect ? PlayerTheme.green : Self.amber)
            Text(viewModel.nextStepTitle.map { "A seguir: \($0)" } ?? "A seguir: fim da aula")
                .font(.system(size: 13))
                .foregroundStyle(PlayerTheme.muted)
            HStack(spacing: 8) {
                if viewModel.showsRepeat {
                    secondaryButton("Repetir", symbol: "arrow.counterclockwise", identifier: "lessonRepeatButton") {
                        viewModel.repeatStep()
                    }
                }
                Spacer(minLength: 0)
                primaryButton("Continuar", identifier: "lessonContinueButton") {
                    viewModel.continueLesson()
                }
            }
        }
        .padding(12)
        .background(PlayerTheme.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lessonResultCard")
    }

    @ViewBuilder
    private var staff: some View {
        let step = viewModel.step
        let namesEverything = step.kind == .learn
        if step.isGrand {
            GrandStaffView(
                steps: viewModel.visibleSteps,
                accidentals: viewModel.visibleAccidentals,
                results: viewModel.visibleResults,
                current: viewModel.visibleCurrent,
                keySignature: step.keySignature,
                wrongPitch: viewModel.wrongPitch,
                listeningStep: viewModel.visibleDemoNote,
                showsAllNames: namesEverything,
                timeSignature: step.meter
            )
        } else {
            ReadingStaffView(
                steps: viewModel.visibleSteps,
                accidentals: viewModel.visibleAccidentals,
                results: viewModel.visibleResults,
                current: viewModel.visibleCurrent,
                staff: step.staff,
                keySignature: step.keySignature,
                wrongPitch: viewModel.wrongPitch,
                listeningStep: viewModel.visibleDemoNote,
                showsAllNames: namesEverything,
                timeSignature: step.meter
            )
        }
    }

    /// Where the notes are coming from.
    @ViewBuilder
    private var inputStatus: some View {
        if let message = viewModel.microphoneMessage {
            statusText(message, symbol: "exclamationmark.triangle.fill", color: .orange)
        } else if viewModel.isSilentForMicrophone {
            statusText("Com o microfone sem fone de ouvido, o app fica em silêncio e marca o pulso na tela", symbol: "headphones", color: .orange)
        } else if let name = viewModel.connectedKeyboardName {
            statusText("Teclado conectado: \(name)", symbol: "cable.connector", color: PlayerTheme.green)
        } else if viewModel.usesMicrophone {
            microphoneMeter
        }
    }

    /// Shows that the microphone hears the room, and the last note it recognized.
    private var microphoneMeter: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
            Text("Ouvindo")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PlayerTheme.raised)
                    Capsule()
                        .fill(PlayerTheme.green)
                        .frame(width: geo.size.width * min(1, max(0.03, viewModel.microphoneLevel)))
                }
            }
            .frame(width: 70, height: 6)
            if let name = viewModel.heardNoteName {
                Text("última nota: \(name)")
                    .foregroundStyle(PlayerTheme.text)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(PlayerTheme.green)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lessonMicrophoneMeter")
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
                beatDots
            }
            .foregroundStyle(content.color)
            .padding(.horizontal, 14)
            .frame(minHeight: 28)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("lessonFeedback")
        }
    }

    /// The metronome on screen: one dot per beat of the measure.
    @ViewBuilder
    private var beatDots: some View {
        if let beat = viewModel.beatInMeasure {
            HStack(spacing: 6) {
                ForEach(0..<(viewModel.step.meter ?? 4), id: \.self) { index in
                    Circle()
                        .fill(index == beat ? PlayerTheme.cyan : PlayerTheme.raised)
                        .frame(width: index == beat ? 14 : 10, height: index == beat ? 14 : 10)
                }
            }
            .frame(height: 16)
            .accessibilityHidden(true)
        }
    }

    private typealias FeedbackContent = (symbol: String, text: String, color: Color)

    private var feedbackContent: FeedbackContent? {
        let amber = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
        let red = Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255)
        let isChord = (viewModel.segment.currentStep?.midiNotes.count ?? 1) > 1
        switch viewModel.feedback {
        case .none:
            return nil
        case .prompt:
            if viewModel.step.kind == .learn {
                return ("hand.tap", isChord ? "Toque as teclas acesas juntas" : "Toque a tecla acesa", PlayerTheme.text)
            }
            return ("hand.tap", isChord ? "Toque as notas azuis juntas" : "Toque a nota azul", PlayerTheme.text)
        case .correct(let name):
            return ("checkmark.circle.fill", "Certo! \(name)", PlayerTheme.green)
        case .wrong(let name):
            return ("xmark.circle.fill", "Você tocou \(name). Tente de novo.", red)
        case .revealed(let name):
            return ("lightbulb.fill", "A nota é \(name). A tecla está acesa.", amber)
        case .listening:
            return ("ear", "Ouça…", PlayerTheme.cyan)
        case .yourTurn:
            return ("hand.tap", "Sua vez: toque as notas que ouviu, na ordem", PlayerTheme.text)
        case .readyToStart:
            return ("metronome", "Toque em Começar quando estiver pronto", PlayerTheme.text)
        case .countIn(let beats):
            return ("metronome", "Prepare-se… \(beats)", PlayerTheme.cyan)
        case .playing:
            return ("music.note", "Toque no tempo", PlayerTheme.cyan)
        case .onTime:
            return ("checkmark.circle.fill", "No tempo!", PlayerTheme.green)
        case .early:
            return ("hare", "Adiantado", amber)
        case .late:
            return ("tortoise", "Atrasado", amber)
        case .missed:
            return ("xmark.circle.fill", "Essa nota passou", red)
        case .chordMissed:
            return ("waveform", "Não ouvi todas as notas. Toque juntas de novo.", amber)
        case .stepDone:
            // Shown by the result card
            return nil
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if viewModel.showsListen {
                secondaryButton("Ouvir", symbol: "speaker.wave.2.fill", identifier: "lessonListenButton") {
                    viewModel.playDemo()
                }
                .disabled(viewModel.isDemonstrating)
            }
            Spacer(minLength: 0)
            if viewModel.timedPhase == .ready {
                primaryButton("Começar", identifier: "lessonStartButton") {
                    viewModel.startTimedStep()
                }
                .disabled(viewModel.isDemonstrating)
            }
        }
        .frame(minHeight: 42)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func primaryButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .frame(height: 42)
                .background(PlayerTheme.deepBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityIdentifier(identifier)
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

/// Both staves, one above the other, with their columns lined up. Each note goes on the staff it belongs to.
struct GrandStaffView: View {
    let steps: [ReadingStep]
    let accidentals: [[Accidental?]]
    let results: [ReadingStepResult]
    let current: Int
    let keySignature: Int
    var wrongPitch: Pitch? = nil
    var listeningStep: Int? = nil
    var showsAllNames: Bool = false
    var timeSignature: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            staffView(.treble)
            staffView(.bass)
        }
    }

    private func staffView(_ staff: Staff) -> some View {
        // A wrong key is drawn on the staff that would write it
        let wrong: Pitch? = wrongPitch.flatMap { pitch -> Pitch? in
            (staff == .treble) == (pitch.midiNoteNumber >= 60) ? pitch : nil
        }
        return ReadingStaffView(
            steps: steps.map { step in
                ReadingStep(measureIndex: step.measureIndex, measureNumber: step.measureNumber, beat: step.beat,
                            globalBeat: step.globalBeat, notes: step.notes.filter { $0.staff == staff }, heldBeats: step.heldBeats)
            },
            accidentals: zip(steps, accidentals).map { step, marks in
                zip(step.notes, marks).filter { $0.0.staff == staff }.map { $0.1 }
            },
            results: results,
            current: current,
            staff: staff,
            keySignature: keySignature,
            wrongPitch: wrong,
            listeningStep: listeningStep,
            showsAllNames: showsAllNames,
            timeSignature: timeSignature
        )
    }
}
