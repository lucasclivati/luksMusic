import Foundation
import SwiftData

// MARK: - PracticeMode

/// The type of practice the user engages in during a session.
enum PracticeMode: String, Codable, CaseIterable {
    /// Unrestricted free play without guidance.
    case freePlay
    /// Step-by-step guided practice with visual cues.
    case guided
    /// Practice the right hand part only.
    case handsSeparateRight = "handsSeparate_right"
    /// Practice the left hand part only.
    case handsSeparateLeft = "handsSeparate_left"
    /// Slow-tempo practice for building accuracy.
    case slowPractice

    /// A human-readable label for display.
    var displayName: String {
        switch self {
        case .freePlay:             return "Free Play"
        case .guided:               return "Guided"
        case .handsSeparateRight:   return "Right Hand"
        case .handsSeparateLeft:    return "Left Hand"
        case .slowPractice:         return "Slow Practice"
        }
    }

    /// The SF Symbol name associated with each practice mode.
    var iconName: String {
        switch self {
        case .freePlay:             return "pianokeys"
        case .guided:               return "music.note.list"
        case .handsSeparateRight:   return "hand.raised.fill"
        case .handsSeparateLeft:    return "hand.raised"
        case .slowPractice:         return "tortoise.fill"
        }
    }
}

// MARK: - PracticeSession

/// Records a single practice session for a specific score.
///
/// Tracks note accuracy, timing, streaks, and user-provided feedback.
/// Persisted with SwiftData for historical statistics and progress tracking.
@Model
final class PracticeSession {
    // MARK: - Stored Properties

    /// Unique identifier for this session.
    var id: UUID

    /// The identifier of the score that was practiced.
    var scoreId: UUID

    /// The title of the score (denormalized for display without loading the full score).
    var scoreTitle: String

    /// When the practice session began.
    var startTime: Date

    /// When the practice session ended. `nil` if still in progress.
    var endTime: Date?

    /// The total number of notes the user played during the session.
    var totalNotesPlayed: Int

    /// The number of notes played correctly.
    var correctNotes: Int

    /// The number of notes played incorrectly (wrong pitch or timing).
    var incorrectNotes: Int

    /// The number of notes that should have been played but were missed.
    var missedNotes: Int

    /// The tempo (BPM) used during practice.
    var tempoUsed: Int

    /// The number of score sections (e.g., phrases or pages) completed.
    var sectionsCompleted: Int

    /// The longest streak of consecutively correct notes.
    var longestStreak: Int

    /// The practice mode used during this session.
    var practiceModeRawValue: String

    /// An optional user-assigned difficulty rating (1–5) after the session.
    var difficultyRating: Int?

    /// Optional free-text notes the user wrote about the session.
    var notes: String?

    // MARK: - Computed Properties

    /// The practice mode enum value.
    var practiceMode: PracticeMode {
        get { PracticeMode(rawValue: practiceModeRawValue) ?? .freePlay }
        set { practiceModeRawValue = newValue.rawValue }
    }

    /// The accuracy percentage (0–100). Returns 0 if no notes were played.
    var accuracy: Double {
        guard totalNotesPlayed > 0 else { return 0 }
        return (Double(correctNotes) / Double(totalNotesPlayed)) * 100.0
    }

    /// The formatted accuracy string (e.g., "87.5%").
    var formattedAccuracy: String {
        String(format: "%.1f%%", accuracy)
    }

    /// The elapsed duration of the session. Returns 0 if the session hasn't ended.
    var duration: TimeInterval {
        guard let endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }

    /// The session duration formatted as "M:SS" or "H:MM:SS".
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Whether the session is still in progress.
    var isActive: Bool {
        endTime == nil
    }

    /// The ratio of correct to incorrect notes. Returns `nil` if there are no incorrect notes.
    var correctToIncorrectRatio: Double? {
        guard incorrectNotes > 0 else { return nil }
        return Double(correctNotes) / Double(incorrectNotes)
    }

    /// A qualitative performance label based on accuracy.
    var performanceLabel: String {
        switch accuracy {
        case 95...100: return "Perfect"
        case 85..<95:  return "Excellent"
        case 70..<85:  return "Good"
        case 50..<70:  return "Needs Practice"
        default:       return "Keep Trying"
        }
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        scoreId: UUID,
        scoreTitle: String,
        startTime: Date = .now,
        endTime: Date? = nil,
        totalNotesPlayed: Int = 0,
        correctNotes: Int = 0,
        incorrectNotes: Int = 0,
        missedNotes: Int = 0,
        tempoUsed: Int = 120,
        sectionsCompleted: Int = 0,
        longestStreak: Int = 0,
        practiceMode: PracticeMode = .freePlay,
        difficultyRating: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.scoreId = scoreId
        self.scoreTitle = scoreTitle
        self.startTime = startTime
        self.endTime = endTime
        self.totalNotesPlayed = totalNotesPlayed
        self.correctNotes = correctNotes
        self.incorrectNotes = incorrectNotes
        self.missedNotes = missedNotes
        self.tempoUsed = tempoUsed
        self.sectionsCompleted = sectionsCompleted
        self.longestStreak = longestStreak
        self.practiceModeRawValue = practiceMode.rawValue
        self.difficultyRating = difficultyRating.map { min(5, max(1, $0)) }
        self.notes = notes
    }

    /// Ends the current session, recording the finish time.
    func endSession() {
        guard isActive else { return }
        endTime = .now
    }

    /// Records a note event during practice.
    /// - Parameters:
    ///   - correct: Whether the note was played correctly.
    ///   - currentStreak: The current streak length to compare against `longestStreak`.
    func recordNote(correct: Bool, currentStreak: Int = 0) {
        totalNotesPlayed += 1
        if correct {
            correctNotes += 1
        } else {
            incorrectNotes += 1
        }
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    }
}
