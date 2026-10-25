// ScannerView.swift
// luksMusic
//
// The Music OCR scanner screen allowing users to photograph physical sheet music
// or choose an image from their photo library to convert it into playable piano scores.

import SwiftUI
import PhotosUI

@MainActor
struct ScannerView: View {
    @State private var viewModel = ScannerViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Description
                    headerCard()
                    
                    // Main Action Cards
                    actionCards()
                    
                    // Processing / Loading State
                    if case .processing(let step) = viewModel.status {
                        processingCard(step: step)
                    }
                    
                    // Error State
                    if case .failure(let errorMsg) = viewModel.status {
                        errorCard(message: errorMsg)
                    }
                    
                    // Best Results Guide
                    tipsCard()
                }
                .padding(20)
            }
            .navigationTitle("Score Scanner (OCR)")
            .sheet(isPresented: $viewModel.showCamera) {
                CameraView { capturedImage in
                    viewModel.processImage(capturedImage)
                }
            }
            .sheet(isPresented: $viewModel.showScanResult) {
                if case .success(let result) = viewModel.status {
                    ScanResultView(viewModel: viewModel, scanResult: result)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.processImage(image)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Card
    
    @ViewBuilder
    private func headerCard() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
                .padding(.bottom, 4)
            
            Text("Convert Sheet Music to Piano Score")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Take a photo of printed piano sheet music or choose from your gallery. Our AI recognizes notes and loads them directly into practice mode.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Action Cards
    
    @ViewBuilder
    private func actionCards() -> some View {
        VStack(spacing: 14) {
            // Camera Scan Button
            Button {
                viewModel.showCamera = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Take Photo with Camera")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Point camera at paper sheet music")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
            
            // Photo Library Picker Button
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.purple)
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose from Photo Library")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Select a screenshot or scanned image")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
            
            // Test with Sample Sheet
            Button {
                testWithSampleSheet()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "doc.text.image")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.teal)
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Try Sample Sheet Music")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Test OCR instantly with built-in piece")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Processing Card
    
    @ViewBuilder
    private func processingCard(step: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(step)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Error Card
    
    @ViewBuilder
    private func errorCard(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scan Error")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Tips Card
    
    @ViewBuilder
    private func tipsCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tips for Accurate Music OCR", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 6) {
                tipRow(text: "Ensure good lighting and avoid cast shadows.")
                tipRow(text: "Keep the page flat to prevent curved staff lines.")
                tipRow(text: "Hold camera parallel to the paper.")
                tipRow(text: "Standard printed notation gives the highest accuracy.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
    
    @ViewBuilder
    private func tipRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.accentColor)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Sample Test Generator
    
    private func testWithSampleSheet() {
        // Create an in-memory sample sheet image to test the OCR pipeline
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
        let sampleImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
            
            // Draw staff lines
            UIColor.black.setStroke()
            ctx.cgContext.setLineWidth(2.0)
            
            for system in 0..<2 {
                let startY = 150 + system * 200
                for line in 0..<5 {
                    let y = CGFloat(startY + line * 20)
                    ctx.cgContext.move(to: CGPoint(x: 60, y: y))
                    ctx.cgContext.addLine(to: CGPoint(x: 740, y: y))
                    ctx.cgContext.strokePath()
                }
            }
            
            // Draw title text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.black
            ]
            "Ode to Joy (Piano Theme)".draw(at: CGPoint(x: 250, y: 50), withAttributes: attrs)
        }
        
        viewModel.processImage(sampleImage)
    }
}
