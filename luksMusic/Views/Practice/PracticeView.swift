// PracticeView.swift
// luksMusic
//
// The central piano training screen combining sheet music, falling notes,
// on-screen interactive piano keyboard, MIDI connectivity, and real-time feedback.

import SwiftUI
import SwiftData

struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: PracticeViewModel
    @State private var keyboardVM = PianoKeyboardViewModel()
    @State private var showStats: Bool = false
    
    init(score: Score) {
        _viewModel = State(initialValue: PracticeViewModel(score: score))
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    practiceHUD()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    
                    Divider()
                    
                    fallingNotesSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Divider()
                    
                    keyboardSection(height: geo.size.height * 0.38)
                    
                    practiceToolbar()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle("Piano Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.stopPractice(modelContext: modelContext)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    modeMenu
                }
            }
            .sheet(isPresented: $showStats) {
                statsSheet
            }
            .onChange(of: viewModel.activeTargetMidiNotes) { _, targets in
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
    
    @ViewBuilder
    private var fallingNotesSection: some View {
        ZStack {
            FallingNotesView(
                notes: currentFallingNotes,
                tempo: viewModel.tempoBPM,
                isPlaying: viewModel.isRunning && !viewModel.isPaused,
                startKey: 48,
                keyCount: 36
            )
            
            VStack {
                Spacer()
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.accentColor.opacity(0.8), .indigo.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 3)
                    .shadow(color: .accentColor, radius: 4)
            }
        }
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
    }
    
    @ViewBuilder
    private var modeMenu: some View {
        Menu {
            Picker("Practice Mode", selection: $viewModel.practiceMode) {
                ForEach(PracticeMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            
            Divider()
            
            Button {
                showStats = true
            } label: {
                Label("Session Stats", systemImage: "chart.bar")
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
                Text("Accuracy")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f%%", viewModel.accuracyPercentage))
                    .font(.headline)
                    .foregroundColor(viewModel.accuracyPercentage >= 80 ? .green : .orange)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 2) {
                Text("Streak")
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
                Text("Mode")
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
        HStack(spacing: 20) {
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
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Tempo:")
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
            
            Text("M \(viewModel.currentMeasureIndex + 1)/\(max(1, viewModel.score.measureCount))")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Falling Notes Generator
    
    private var currentFallingNotes: [FallingNote] {
        var falling: [FallingNote] = []
        for (mIdx, measure) in viewModel.score.measures.enumerated() {
            for note in measure.notes where !note.isRest {
                let noteBeat = Double(mIdx * viewModel.score.timeSignatureTop) + note.position.beat
                falling.append(FallingNote(
                    midiNote: Int(note.midiNote),
                    startBeat: noteBeat,
                    durationBeats: note.duration.beats,
                    hand: note.staff == .treble ? .right : .left
                ))
            }
        }
        return falling
    }
}
