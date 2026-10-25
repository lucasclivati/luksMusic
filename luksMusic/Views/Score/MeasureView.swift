// MeasureView.swift
// luksMusic
//
// SwiftUI view rendering a complete musical measure with notes for both staves and barlines.

import SwiftUI

struct MeasureView: View {
    let measure: Measure
    var isCurrent: Bool = false
    var currentBeat: Double = 1.0
    var lineSpacing: CGFloat = 12.0
    var measureWidth: CGFloat = 280.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Measure number badge
            Text("\(measure.number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isCurrent ? .accentColor : .secondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    isCurrent ? Color.accentColor.opacity(0.18) : Color.clear
                )
                .cornerRadius(4)
                .padding(.leading, 6)
            
            ZStack(alignment: .leading) {
                // Background highlight if measure is active during playback
                if isCurrent {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                        )
                        .frame(width: measureWidth, height: lineSpacing * 12.5)
                }
                
                // Continuous 5-line staff backdrop for both staves
                VStack(spacing: lineSpacing * 3.5) {
                    staffFiveLines()
                    staffFiveLines()
                }
                .frame(width: measureWidth)
                
                // Treble staff notes (centered on Treble Line 3)
                notesLayer(notes: measure.trebleNotes)
                    .offset(y: -lineSpacing * 3.75)
                
                // Bass staff notes (centered on Bass Line 3)
                notesLayer(notes: measure.bassNotes)
                    .offset(y: lineSpacing * 3.75)
                
                // Right barline connecting top of treble staff to bottom of bass staff
                endBarline()
                    .frame(width: 6, height: lineSpacing * 11.5)
                    .offset(x: measureWidth - 4)
            }
        }
        .frame(width: measureWidth)
    }
    
    // MARK: - 5 Lines Staff Backdrop
    
    @ViewBuilder
    private func staffFiveLines() -> some View {
        VStack(spacing: lineSpacing) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(height: 1.2)
            }
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Notes Layer
    
    @ViewBuilder
    private func notesLayer(notes: [Note]) -> some View {
        ZStack(alignment: .leading) {
            ForEach(notes) { note in
                // Proportional offset across 4 beats (beat 1.0 -> 0.0, beat 5.0 -> 1.0)
                let beatOffset = max(0.0, min(1.0, (note.position.beat - 1.0) / 4.0))
                let usableWidth = measureWidth - 48.0
                let xPos = 24.0 + CGFloat(beatOffset) * usableWidth
                let isNoteActive = isCurrent && abs(note.position.beat - currentBeat) < 0.28
                
                NoteView(
                    note: note,
                    playbackState: isNoteActive ? .current : .upcoming,
                    lineSpacing: lineSpacing
                )
                .offset(x: xPos)
            }
        }
        .frame(width: measureWidth, height: lineSpacing * 4)
    }
    
    // MARK: - Barline
    
    @ViewBuilder
    private func endBarline() -> some View {
        HStack(spacing: 2.5) {
            if measure.barlineType == .final {
                Rectangle()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 1.5)
                Rectangle()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 3.5)
            } else if measure.barlineType == .double {
                Rectangle()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 1.5)
                Rectangle()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 1.5)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 1.5)
            }
        }
    }
}
