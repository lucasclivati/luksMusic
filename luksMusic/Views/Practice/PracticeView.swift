// PracticeView.swift
// luksMusic
//
// The central piano training screen combining sheet music, falling notes,
// on-screen interactive piano keyboard, MIDI connectivity, and real-time feedback.

import SwiftUI
import SwiftData

struct PracticeView: View {
    let score: Score

    /// Built once, when the screen appears. The player re-creates this view every time it redraws, and building
    /// the practice session each time (it reads every note of the score) kept the app busy.
    @State private var viewModel: PracticeViewModel?
    @State private var keyboardVM: PianoKeyboardViewModel?

    init(score: Score) {
        self.score = score
    }

    var body: some View {
        Group {
            if let viewModel, let keyboardVM {
                PracticeScreen(viewModel: viewModel, keyboardVM: keyboardVM)
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let midiPitches = score.measures
                .flatMap { $0.notes }
                .filter { !$0.isRest }
                .map { Int($0.midiNote) }
            let minPitch = midiPitches.min() ?? 48
            let maxPitch = midiPitches.max() ?? 84
            let startOctaveC = max(24, min(48, (minPitch / 12) * 12))
            let endOctaveC = min(108, max(84, Int(ceil(Double(maxPitch + 1) / 12.0)) * 12))
            let practice = PracticeViewModel(score: score)
            practice.fallingNotes.keyboardRangeStart = startOctaveC
            practice.fallingNotes.keyboardRangeEnd = endOctaveC
            keyboardVM = PianoKeyboardViewModel(rangeStart: startOctaveC, rangeEnd: endOctaveC)
            viewModel = practice
        }
    }
}

private struct PracticeScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var viewModel: PracticeViewModel
    @Bindable var keyboardVM: PianoKeyboardViewModel
    @State private var showStats: Bool = false

    // Engraved score source for the staff strip, in each hand's clef from the score player's settings
    @State private var musicXML: String = ""
    @AppStorage(ClefChoice.rightHandKey) private var rightClef: ClefChoice = .score
    @AppStorage(ClefChoice.leftHandKey) private var leftClef: ClefChoice = .score
    @AppStorage(ClefChoice.automaticUsesAltoKey) private var automaticUsesAlto: Bool = true

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    practiceHUD()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // 1. Engraved score on one line, its cursor on the notes to play
                    sheetMusicTopSection
                        .frame(height: 150)
                        .background(Color.white)
                    
                    Divider()
                    
                    // 2. Falling Notes cascading down in matching beat colors
                    fallingNotesSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Divider()
                    
                    // 3. Piano Keyboard illuminating in beat colors
                    keyboardSection(height: geo.size.height * 0.33)
                    
                    practiceToolbar()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle("Modo Estudo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Concluir") {
                        viewModel.stopPractice(modelContext: modelContext)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.toggleMicrophoneListening()
                        } label: {
                            Image(systemName: viewModel.isMicrophoneEnabled ? "mic.fill" : "mic.slash")
                                .foregroundColor(viewModel.isMicrophoneEnabled ? .green : .primary)
                        }
                        
                        modeMenu
                    }
                }
            }
            .sheet(isPresented: $showStats) {
                statsSheet
            }
            .onAppear {
                musicXML = MusicXMLExporter.export(viewModel.score)
                viewModel.startMetronomeIfOn()
            }
            // Closing with "Concluir" or by swiping the sheet down
            .onDisappear {
                viewModel.stopMetronome()
            }
            .onChange(of: viewModel.practiceMode) { _, _ in
                viewModel.practiceSettingsChanged()
            }
            .onChange(of: viewModel.tempoBPM) { _, _ in
                viewModel.practiceSettingsChanged()
            }
            .onChange(of: viewModel.activeTargetMidiNotes, initial: true) { _, targets in
                keyboardVM.targetNoteKeys = targets
            }
            .onChange(of: viewModel.correctKeyFeedback) { _, correct in
                keyboardVM.correctKeys = correct
            }
            .onChange(of: viewModel.incorrectKeyFeedback) { _, incorrect in
                keyboardVM.incorrectKeys = incorrect
            }
            .onChange(of: viewModel.sessionCompleted) { _, completed in
                if completed {
                    showStats = true
                }
            }
        }
    }
    
    // MARK: - Sections
    
    /// OpenSheetMusicDisplay line scaled to the strip; tapping a note moves practice there.
    @ViewBuilder
    private var sheetMusicTopSection: some View {
        ScoreWebView(
            title: "",
            composer: "",
            musicXML: musicXML,
            measureIndex: viewModel.currentMeasureIndex,
            cursorBeat: viewModel.cursorBeat,
            rightClef: rightClef,
            leftClef: leftClef,
            automaticUsesAlto: automaticUsesAlto,
            horizontal: true,
            fitsHeight: true,
            topInset: 0,
            bottomInset: 0
        ) { measure, beat in
            viewModel.seek(toMeasure: measure, beat: beat)
        }
    }
    
    @ViewBuilder
    private var fallingNotesSection: some View {
        FallingNotesView(
            viewModel: viewModel.fallingNotes,
            onActiveKeysChanged: { activeKeys, bassKeys, trebleKeys, keyColors in
                keyboardVM.midiActiveKeys = activeKeys
                keyboardVM.bassActiveKeys = bassKeys
                keyboardVM.trebleActiveKeys = trebleKeys
                keyboardVM.keyColorsByNote = keyColors
            }
        )
    }
    
    @ViewBuilder
    private func keyboardSection(height: CGFloat) -> some View {
        PianoKeyboardView(
            viewModel: keyboardVM,
            onKeyPress: { midiNote in
                viewModel.notePlayed(midiNote: midiNote)
            },
            onKeyRelease: { midiNote in
                viewModel.noteReleased(midiNote: midiNote)
            }
        )
        .frame(height: height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practiceKeyboard")
    }
    
    @ViewBuilder
    private var modeMenu: some View {
        Menu {
            Picker("Modo de estudo", selection: $viewModel.practiceMode) {
                ForEach(PracticeMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            
            Divider()
            
            Button {
                viewModel.toggleMicrophoneListening()
            } label: {
                Label(
                    viewModel.isMicrophoneEnabled ? "Desligar o microfone" : "Ouvir o piano pelo microfone",
                    systemImage: viewModel.isMicrophoneEnabled ? "mic.slash" : "mic"
                )
            }
            
            Button {
                showStats = true
            } label: {
                Label("Resumo do estudo", systemImage: "chart.bar")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
    }
    
    @ViewBuilder
    private var statsSheet: some View {
        if let session = viewModel.latestSession {
            PracticeStatsView(session: session)
        } else {
            PracticeStatsView(session: PracticeSession(
                scoreId: viewModel.score.id,
                scoreTitle: viewModel.score.title,
                startTime: viewModel.sessionStartTime,
                endTime: Date(),
                totalNotesPlayed: viewModel.totalNotesPlayed,
                correctNotes: viewModel.correctNotes,
                incorrectNotes: viewModel.incorrectNotes,
                missedNotes: viewModel.missedNotes,
                tempoUsed: viewModel.tempoBPM,
                sectionsCompleted: viewModel.currentMeasureIndex + 1,
                longestStreak: viewModel.longestStreak,
                practiceMode: viewModel.practiceMode
            ))
        }
    }
    
    // MARK: - HUD
    
    @ViewBuilder
    private func practiceHUD() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Precisão")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f%%", viewModel.accuracyPercentage))
                    .font(.headline)
                    .foregroundColor(viewModel.accuracyPercentage >= 80 ? .green : .orange)
            }
            
            Spacer()
            
            if viewModel.isMicrophoneEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Microfone: \(viewModel.microphoneService.detectedNoteName)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.15), in: Capsule())
                
                Spacer()
            }
            
            VStack(alignment: .center, spacing: 2) {
                Text("Sequência")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(viewModel.currentStreak)")
                        .font(.headline)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Modo")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(viewModel.practiceMode.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Bottom Practice Controls
    
    @ViewBuilder
    private func practiceToolbar() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if viewModel.isMetronomeSilent {
                Label("Com o microfone sem fone de ouvido, o metrônomo fica em silêncio e marca o pulso na tela",
                      systemImage: "headphones")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("practiceMetronomeSilent")
            }
            practiceControls()
        }
    }
    
    @ViewBuilder
    private func practiceControls() -> some View {
        HStack(spacing: 12) {
            Button {
                if viewModel.isRunning {
                    if viewModel.isPaused {
                        viewModel.resumePractice()
                    } else {
                        viewModel.pausePractice()
                    }
                } else {
                    viewModel.startPractice()
                }
            } label: {
                Image(systemName: viewModel.isRunning && !viewModel.isPaused ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("practicePlayButton")
            
            Button {
                viewModel.stopPractice(modelContext: modelContext)
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            
            Button {
                viewModel.toggleMicrophoneListening()
            } label: {
                Image(systemName: viewModel.isMicrophoneEnabled ? "mic.fill" : "mic.slash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(viewModel.isMicrophoneEnabled ? .white : .primary)
                    .frame(width: 36, height: 36)
                    .background(viewModel.isMicrophoneEnabled ? Color.green : Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            
            PracticeMetronomeButton(viewModel: viewModel)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Andamento:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.tempoBPM) BPM")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.tempoBPM) },
                        set: { viewModel.tempoBPM = Int($0) }
                    ),
                    in: 40...200,
                    step: 5
                )
            }
            
            // Label over value, so the row leaves the slider room beside the metronome
            VStack(alignment: .trailing, spacing: 2) {
                Text("Compasso")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(viewModel.currentMeasureIndex + 1)/\(max(1, viewModel.score.measureCount))")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
    }
}

// MARK: - Metronome

/// Clicks at the tempo of the slider, apart from the practice cursor; its light flashes red on the first beat of the
/// measure and yellow on the others, like the score player's metronome. A view of its own, so each beat redraws only
/// the button, not the score, the falling notes and the keyboard.
private struct PracticeMetronomeButton: View {
    @Bindable var viewModel: PracticeViewModel
    // On for a moment at each beat
    @State private var light: Color?
    
    var body: some View {
        Button {
            viewModel.toggleMetronome()
        } label: {
            Image(systemName: viewModel.isMetronomeOn ? "metronome.fill" : "metronome")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(viewModel.isMetronomeOn ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(viewModel.isMetronomeOn ? Color.accentColor : Color(.tertiarySystemFill))
                .clipShape(Circle())
        }
        .accessibilityLabel("Metrônomo")
        .accessibilityIdentifier("practiceMetronomeButton")
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(light ?? Color.clear)
                .frame(width: 9, height: 9)
                .shadow(color: light ?? Color.clear, radius: 4)
                .allowsHitTesting(false)
        }
        .onChange(of: viewModel.metronomeClicks) { _, clicks in
            light = viewModel.metronomeAccent ? PlayerTheme.downbeat : PlayerTheme.beat
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if viewModel.metronomeClicks == clicks {
                    light = nil
                }
            }
        }
    }
}
