// EditorView.swift
// luksMusic
//
// Full score editor view for composing and modifying piano sheet music.

import SwiftUI
import SwiftData

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: EditorViewModel
    
    init(score: Score) {
        _viewModel = State(initialValue: EditorViewModel(score: score))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Score Viewer in Edit Mode
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            // Left Clef
                            StaffView(
                                lineSpacing: 11,
                                keySignatureValue: viewModel.score.keySignatureValue,
                                timeSignatureTop: viewModel.score.timeSignatureTop,
                                timeSignatureBottom: viewModel.score.timeSignatureBottom,
                                showClefsAndSignatures: true
                            )
                            .padding(.leading, 16)
                            
                            // Editable Measures
                            ForEach(Array(viewModel.score.measures.enumerated()), id: \.element.id) { index, measure in
                                MeasureView(
                                    measure: measure,
                                    isCurrent: index == viewModel.selectedMeasureIndex,
                                    currentBeat: viewModel.selectedBeat,
                                    lineSpacing: 11,
                                    measureWidth: 170
                                )
                                .id(index)
                                .onTapGesture {
                                    viewModel.selectedMeasureIndex = index
                                    viewModel.selectedBeat = 1.0
                                }
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.vertical, 16)
                    }
                    .onChange(of: viewModel.selectedMeasureIndex) { _, newIndex in
                        withAnimation {
                            scrollProxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(maxHeight: 220)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Cursor & Position Indicator
                HStack {
                    Text("Measure \(viewModel.selectedMeasureIndex + 1) • Beat \(String(format: "%.1f", viewModel.selectedBeat))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Text("Staff: \(viewModel.selectedStaff == .treble ? "Treble (RH)" : "Bass (LH)")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                
                // Toolbar (Durations, Accidentals, Voice, Rest)
                EditorToolbar(viewModel: viewModel)
                
                Divider()
                
                // Step-input Keyboard
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap Piano Key to Insert Note")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    
                    NoteInputView(viewModel: viewModel)
                }
                .padding(.bottom, 8)
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle("Score Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
