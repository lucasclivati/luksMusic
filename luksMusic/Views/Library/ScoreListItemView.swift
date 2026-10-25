// ScoreListItemView.swift
// luksMusic
//
// Reusable card / row component for displaying a score in the library.

import SwiftUI
import SwiftData

/// Layout variant for the score item.
enum ScoreItemLayout {
    case grid
    case list
}

/// Displays a single score entry as either a grid card or a list row.
struct ScoreListItemView: View {
    let score: Score
    var layout: ScoreItemLayout = .grid

    // MARK: Body

    var body: some View {
        switch layout {
        case .grid:
            gridCard
        case .list:
            listRow
        }
    }

    // MARK: - Grid Card

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area
            thumbnailView
                .frame(height: 140)
                .clipped()

            // Info area
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(score.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    if score.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    difficultyBadge

                    Spacer()

                    Image(systemName: score.source.iconName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastPracticed = score.lastPracticed {
                    Text(lastPracticed, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    // MARK: - List Row

    private var listRow: some View {
        HStack(spacing: 14) {
            // Small thumbnail
            thumbnailView
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(score.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    if score.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    difficultyBadge

                    if score.estimatedDuration > 0 {
                        Label(durationString, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: score.source.iconName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right side info
            VStack(alignment: .trailing, spacing: 4) {
                if let lastPracticed = score.lastPracticed {
                    Text(lastPracticed, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Components

    /// Thumbnail preview of the sheet music, or a placeholder.
    @ViewBuilder
    private var thumbnailView: some View {
        if let data = score.thumbnailData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            // Placeholder with decorative staff lines and music note
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.systemGray5),
                        Color(.systemGray6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Faux staff lines
                VStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray3).opacity(0.5))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 12)

                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundStyle(.indigo.opacity(0.6))
            }
        }
    }

    /// Color-coded difficulty badge.
    private var difficultyBadge: some View {
        Text(score.difficulty.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(difficultyColor.opacity(0.2), in: Capsule())
            .foregroundStyle(difficultyColor)
    }

    /// The SwiftUI Color matching the score's difficulty.
    private var difficultyColor: Color {
        switch score.difficulty {
        case .beginner:     return .green
        case .intermediate: return .yellow
        case .advanced:     return .orange
        case .expert:       return .red
        }
    }

    /// Formatted duration string (e.g. "3:45").
    private var durationString: String {
        let minutes = Int(score.estimatedDuration) / 60
        let seconds = Int(score.estimatedDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview("Grid Card") {
    let container = try! ModelContainer(for: Score.self, configurations: .init(isStoredInMemoryOnly: true))
    let score = Score(
        title: "Moonlight Sonata",
        composer: "Ludwig van Beethoven",
        difficulty: .advanced,
        source: .imported,
        estimatedDuration: 345
    )
    score.isFavorite = true
    score.lastPracticed = Date().addingTimeInterval(-172800) // 2 days ago
    container.mainContext.insert(score)

    return ScoreListItemView(score: score, layout: .grid)
        .frame(width: 180)
        .modelContainer(container)
        .preferredColorScheme(.dark)
        .padding()
}

#Preview("List Row") {
    let container = try! ModelContainer(for: Score.self, configurations: .init(isStoredInMemoryOnly: true))
    let score = Score(
        title: "Für Elise",
        composer: "Beethoven",
        difficulty: .intermediate,
        source: .manual,
        estimatedDuration: 210
    )
    score.lastPracticed = Date().addingTimeInterval(-86400)
    container.mainContext.insert(score)

    return ScoreListItemView(score: score, layout: .list)
        .modelContainer(container)
        .preferredColorScheme(.dark)
        .padding()
}
