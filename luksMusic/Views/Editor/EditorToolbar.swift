// EditorToolbar.swift
// luksMusic
//
// MuseScore-style composition palette with note durations, accidentals, rests, and undo/redo.

import SwiftUI

struct EditorToolbar: View {
    @Bindable var viewModel: EditorViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Top Row: Staff / Voice / Undo / Redo
            HStack(spacing: 12) {
                // Staff Selector (Treble or Bass)
                Picker("Staff", selection: $viewModel.selectedStaff) {
                    Text("Sol 𝄞").tag(Staff.treble)
                    Text("Fá 𝄢").tag(Staff.bass)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                
                Spacer()
                
                // Undo / Redo
                Button {
                    viewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)
                
                Button {
                    viewModel.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)
                
                // Delete
                Button(role: .destructive) {
                    viewModel.deleteLastNote()
                } label: {
                    Image(systemName: "delete.left")
                        .foregroundColor(.red)
                }
                
                // Add Measure
                Button {
                    viewModel.addNewMeasure()
                } label: {
                    Label("Compasso", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Bottom Row: Durations and Accidentals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Duration Buttons
                    durationButton(duration: .whole, symbol: "𝅝", label: "Whole")
                    durationButton(duration: .half, symbol: "𝅗𝅥", label: "Half")
                    durationButton(duration: .quarter, symbol: "♩", label: "1/4")
                    durationButton(duration: .eighth, symbol: "♪", label: "1/8")
                    durationButton(duration: .sixteenth, symbol: "𝅘𝅥𝅯", label: "1/16")
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Rest Toggle
                    toggleButton(
                        isActive: viewModel.isRestSelected,
                        symbol: "𝄽",
                        label: "Rest",
                        onTap: { viewModel.isRestSelected.toggle() }
                    )
                    
                    // Dot Toggle
                    toggleButton(
                        isActive: viewModel.isDottedSelected,
                        symbol: "•",
                        label: "Dot",
                        onTap: { viewModel.isDottedSelected.toggle() }
                    )
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Accidentals
                    accidentalButton(accidental: .sharp, symbol: "♯")
                    accidentalButton(accidental: .flat, symbol: "♭")
                    accidentalButton(accidental: .natural, symbol: "♮")
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func durationButton(duration: NoteDuration, symbol: String, label: String) -> some View {
        Button {
            viewModel.selectedDuration = duration
        } label: {
            VStack(spacing: 2) {
                Text(symbol)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(width: 44, height: 44)
            .background(viewModel.selectedDuration == duration ? Color.accentColor : Color(.tertiarySystemFill))
            .foregroundColor(viewModel.selectedDuration == duration ? .white : .primary)
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func toggleButton(isActive: Bool, symbol: String, label: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(symbol)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(width: 44, height: 44)
            .background(isActive ? Color.accentColor : Color(.tertiarySystemFill))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func accidentalButton(accidental: Accidental, symbol: String) -> some View {
        Button {
            viewModel.selectedAccidental = (viewModel.selectedAccidental == accidental) ? .natural : accidental
        } label: {
            Text(symbol)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 36, height: 44)
                .background(viewModel.selectedAccidental == accidental ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundColor(viewModel.selectedAccidental == accidental ? .white : .primary)
                .cornerRadius(8)
        }
    }
}
