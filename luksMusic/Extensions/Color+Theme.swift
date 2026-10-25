// Color+Theme.swift
// luksMusic
//
// App-wide theme colors optimized for a dark piano-centric design.

import SwiftUI

extension Color {

    // MARK: - Piano Colors

    /// Deep black used for piano black keys and dark backgrounds.
    static let pianoBlack = Color(red: 0.08, green: 0.08, blue: 0.10)

    /// Ivory white used for piano white keys.
    static let pianoWhite = Color(red: 0.95, green: 0.93, blue: 0.90)

    // MARK: - Staff Colors

    /// Color for staff lines drawn on the score.
    static let staffLine = Color(red: 0.55, green: 0.55, blue: 0.60)

    // MARK: - Note State Colors

    /// Default note color (light gray).
    static let noteDefault = Color(red: 0.85, green: 0.85, blue: 0.88)

    /// Green for correctly played notes.
    static let noteCorrect = Color(red: 0.30, green: 0.85, blue: 0.45)

    /// Red for incorrectly played notes.
    static let noteIncorrect = Color(red: 0.92, green: 0.30, blue: 0.30)

    /// Orange for missed notes.
    static let noteMissed = Color(red: 0.95, green: 0.60, blue: 0.20)

    /// Dim color for upcoming notes.
    static let noteUpcoming = Color(red: 0.45, green: 0.45, blue: 0.50)

    // MARK: - Accent

    /// Primary indigo accent used throughout the app.
    static let accentIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)

    // MARK: - Backgrounds

    /// Primary dark background.
    static let backgroundPrimary = Color(red: 0.07, green: 0.07, blue: 0.09)

    /// Secondary slightly lighter background for cards & sections.
    static let backgroundSecondary = Color(red: 0.12, green: 0.12, blue: 0.15)

    // MARK: - Confidence Colors (OCR)

    /// High confidence (green).
    static let confidenceHigh = Color(red: 0.30, green: 0.85, blue: 0.45)

    /// Medium confidence (yellow).
    static let confidenceMedium = Color(red: 0.95, green: 0.80, blue: 0.25)

    /// Low confidence (red).
    static let confidenceLow = Color(red: 0.92, green: 0.30, blue: 0.30)

    /// Returns a confidence color based on a 0–1 value.
    static func confidenceColor(for value: Double) -> Color {
        if value >= 0.8 { return .confidenceHigh }
        if value >= 0.5 { return .confidenceMedium }
        return .confidenceLow
    }
}

// MARK: - ShapeStyle Convenience

extension ShapeStyle where Self == Color {

    /// Gradient used on accent buttons.
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentIndigo, Color.accentIndigo.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
