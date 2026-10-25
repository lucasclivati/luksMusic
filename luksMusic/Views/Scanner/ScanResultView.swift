// ScanResultView.swift
// luksMusic
//
// Screen displaying OCR conversion results with image-to-score side-by-side comparison,
// confidence indicators, metadata editing, and immediate practice launch.

import SwiftUI
import SwiftData

struct ScanResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var viewModel: ScannerViewModel
    let scanResult: ScanResult
    
    @State private var showImmediatePractice: Bool = false
    @State private var savedScore: Score? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Confidence Banner
                    confidenceBanner()
                    
                    // Original Photo vs Converted Score Preview
                    comparisonSection()
                    
                    // Metadata Editing Card
                    metadataForm()
                    
                    // Action Buttons
                    actionButtons()
                }
                .padding(16)
            }
            .navigationTitle("Conversion Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let score = viewModel.saveScannedScore(modelContext: modelContext) {
                            savedScore = score
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showImmediatePractice) {
                if let score = savedScore {
                    PracticeView(score: score)
                }
            }
        }
    }
    
    // MARK: - Confidence Banner
    
    @ViewBuilder
    private func confidenceBanner() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Music Converted Successfully")
                    .font(.headline)
                Text(String(format: "Recognition Confidence: %.0f%%", scanResult.confidence * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.green.opacity(0.12))
        .cornerRadius(12)
    }
    
    // MARK: - Comparison Section
    
    @ViewBuilder
    private func comparisonSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Original Captured Image")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Image with detected bounding box overlays
            ZStack {
                Image(uiImage: scanResult.originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .cornerRadius(10)
                
                // Detected overlays
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
            }
            
            Text("Converted Sheet Music Preview")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            // Converted Measures Preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    StaffView(
                        lineSpacing: 10,
                        keySignatureValue: scanResult.score.keySignatureValue,
                        timeSignatureTop: scanResult.score.timeSignatureTop,
                        timeSignatureBottom: scanResult.score.timeSignatureBottom,
                        showClefsAndSignatures: true
                    )
                    
                    ForEach(scanResult.score.measures) { measure in
                        MeasureView(
                            measure: measure,
                            isCurrent: false,
                            lineSpacing: 10,
                            measureWidth: 150
                        )
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Metadata Form
    
    @ViewBuilder
    private func metadataForm() -> some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Piece Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Title", text: $viewModel.editedTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Composer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Composer", text: $viewModel.editedComposer)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tempo (BPM)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Tempo", value: $viewModel.editedTempo, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Difficulty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Difficulty", selection: $viewModel.editedDifficulty) {
                        ForEach(Difficulty.allCases) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private func actionButtons() -> some View {
        VStack(spacing: 12) {
            Button {
                if let score = viewModel.saveScannedScore(modelContext: modelContext) {
                    savedScore = score
                    showImmediatePractice = true
                }
            } label: {
                Label("Save & Practice on Piano Now", systemImage: "pianokeys")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            
            Button {
                if let score = viewModel.saveScannedScore(modelContext: modelContext) {
                    savedScore = score
                    dismiss()
                }
            } label: {
                Text("Save to Library Only")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }
}
