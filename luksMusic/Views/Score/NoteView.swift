// NoteView.swift
// luksMusic
//
// SwiftUI view rendering a musical note or rest on the staff with stems, flags, and accidentals.

import SwiftUI

struct NoteView: View {
    let note: Note
    var playbackState: NotePlaybackState = .upcoming
    var lineSpacing: CGFloat = 12.0
    var useBeatColors: Bool = true
    
    var body: some View {
        ZStack {
            if note.isRest {
                renderRest()
            } else {
                renderNote()
            }
        }
    }
    
    // MARK: - Rest Rendering
    
    @ViewBuilder
    private func renderRest() -> some View {
        Text(restSymbol(for: note.duration))
            .font(.system(size: lineSpacing * 2.2))
            .foregroundColor(noteColor.opacity(0.8))
    }
    
    // MARK: - Note Rendering
    
    @ViewBuilder
    private func renderNote() -> some View {
        let isFilled = note.duration != .whole && note.duration != .half
        let hasStem = note.duration != .whole
        let stemUp = note.stemUp
        
        ZStack {
            // Ledger lines if outside staff
            renderLedgerLines()
            
            HStack(spacing: 2) {
                // Accidental
                if note.pitch.accidental != .natural {
                    Text(note.pitch.accidental.symbol)
                        .font(.system(size: lineSpacing * 1.5, weight: .semibold))
                        .foregroundColor(noteColor)
                        .offset(y: verticalOffset)
                }
                
                // Notehead + Stem
                ZStack(alignment: stemUp ? .bottomTrailing : .topLeading) {
                    // Note Head
                    Ellipse()
                        .fill(isFilled ? noteColor : Color.clear)
                        .overlay(
                            Ellipse()
                                .stroke(noteColor, lineWidth: 2)
                        )
                        .frame(width: lineSpacing * 1.35, height: lineSpacing * 0.95)
                        .rotationEffect(.degrees(-20))
                        .offset(y: verticalOffset)
                    
                    // Stem
                    if hasStem {
                        Rectangle()
                            .fill(noteColor)
                            .frame(width: 1.5, height: lineSpacing * 3.2)
                            .offset(
                                x: stemUp ? (lineSpacing * 0.55) : (-lineSpacing * 0.55),
                                y: verticalOffset + (stemUp ? (-lineSpacing * 1.6) : (lineSpacing * 1.6))
                            )
                    }
                    
                    // Flags for 8th / 16th notes
                    if note.duration == .eighth || note.duration == .sixteenth {
                        renderFlag(stemUp: stemUp)
                    }
                }
                
                // Dot
                if note.duration == .dottedHalf || note.duration == .dottedQuarter || note.duration == .dottedEighth {
                    Circle()
                        .fill(noteColor)
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: verticalOffset)
                }
            }
            
            // Finger number annotation
            if let finger = note.fingerNumber {
                Text("\(finger)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .offset(y: verticalOffset + (stemUp ? (-lineSpacing * 3.5) : (lineSpacing * 2.5)))
            }
        }
    }
    
    // MARK: - Flag Rendering
    
    @ViewBuilder
    private func renderFlag(stemUp: Bool) -> some View {
        let flagSymbol = note.duration == .sixteenth ? "𝅘𝅥𝅯" : "𝅘𝅥𝅮"
        Text(flagSymbol)
            .font(.system(size: lineSpacing * 2.0))
            .foregroundColor(noteColor)
            .offset(
                x: stemUp ? (lineSpacing * 0.6) : (-lineSpacing * 0.6),
                y: verticalOffset + (stemUp ? (-lineSpacing * 2.8) : (lineSpacing * 2.8))
            )
    }
    
    // MARK: - Ledger Lines
    
    @ViewBuilder
    private func renderLedgerLines() -> some View {
        let linesAbove = note.ledgerLinesAbove
        let linesBelow = note.ledgerLinesBelow
        
        if linesAbove > 0 {
            ForEach(1...linesAbove, id: \.self) { i in
                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: lineSpacing * 2.0, height: 1)
                    .offset(y: -CGFloat(2 + i) * lineSpacing)
            }
        }
        
        if linesBelow > 0 {
            ForEach(1...linesBelow, id: \.self) { i in
                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: lineSpacing * 2.0, height: 1)
                    .offset(y: CGFloat(2 + i) * lineSpacing)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var verticalOffset: CGFloat {
        // Each step on staff is half lineSpacing
        -CGFloat(note.staffPosition) * (lineSpacing * 0.5)
    }
    
    private var noteColor: Color {
        switch playbackState {
        case .upcoming:
            return useBeatColors ? Color.colorForBeat(note.position.beat) : Color.primary
        case .current:
            return useBeatColors ? Color.colorForBeat(note.position.beat) : Color.accentColor
        case .correct:
            return Color(red: 0.22, green: 0.95, blue: 0.38)
        case .incorrect:
            return Color.red
        case .played:
            return Color.secondary.opacity(0.4)
        }
    }
    
    private func restSymbol(for duration: NoteDuration) -> String {
        switch duration {
        case .whole: return "𝄻"
        case .half, .dottedHalf: return "𝄼"
        case .quarter, .dottedQuarter: return "𝄽"
        case .eighth, .dottedEighth: return "𝄾"
        case .sixteenth, .dottedSixteenth, .thirtySecond: return "𝄿"
        }
    }
}
