// PracticeStatsView.swift
// luksMusic
//
// Performance summary screen displayed after a piano practice session.

import SwiftUI

struct PracticeStatsView: View {
    @Environment(\.dismiss) private var dismiss
    let session: PracticeSession
    
    @State private var userRating: Int = 4
    @State private var userNotes: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Score Card
                    accuracyRingCard()
                        .padding(.top, 16)
                    
                    // Detailed Statistics Grid
                    statsGrid()
                    
                    // Session Details Card
                    sessionDetailsCard()
                    
                    // User Feedback / Rating
                    ratingSection()
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Practice Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Accuracy Ring Card
    
    @ViewBuilder
    private func accuracyRingCard() -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 14)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: CGFloat(session.accuracy / 100.0))
                    .stroke(
                        session.accuracy >= 80 ? Color.green : (session.accuracy >= 60 ? Color.orange : Color.red),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", session.accuracy))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 4) {
                Text(session.scoreTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(session.practiceMode.displayName)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Stats Grid
    
    @ViewBuilder
    private func statsGrid() -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statItem(title: "Correct Notes", value: "\(session.correctNotes)", icon: "checkmark.circle.fill", color: .green)
            statItem(title: "Incorrect", value: "\(session.incorrectNotes)", icon: "xmark.circle.fill", color: .red)
            statItem(title: "Max Streak", value: "\(session.longestStreak)", icon: "flame.fill", color: .orange)
            statItem(title: "Total Played", value: "\(session.totalNotesPlayed)", icon: "pianokeys", color: .blue)
        }
    }
    
    @ViewBuilder
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Session Details
    
    @ViewBuilder
    private func sessionDetailsCard() -> some View {
        VStack(spacing: 12) {
            detailRow(title: "Tempo Used", value: "\(session.tempoUsed) BPM")
            Divider()
            detailRow(title: "Sections Finished", value: "\(session.sectionsCompleted)")
            Divider()
            detailRow(title: "Duration", value: formatDuration(session.duration))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
    
    // MARK: - Rating
    
    @ViewBuilder
    private func ratingSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How did this practice feel?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= userRating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            userRating = star
                            session.difficultyRating = star
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02dm %02ds", mins, secs)
    }
}
