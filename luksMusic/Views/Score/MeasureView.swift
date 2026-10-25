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
    var measureWidth: CGFloat = 180.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Measure number
            Text("\(measure.number)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isCurrent ? .accentColor : .secondary)
                .padding(.leading, 4)
            
            ZStack(alignment: .leading) {
                // Background highlight if active
                if isCurrent {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: measureWidth, height: lineSpacing * 12)
                }
                
                // Staff lines background
                VStack(spacing: lineSpacing * 3.5) {
                    staffFiveLines()
                    staffFiveLines()
                }
                .frame(width: measureWidth)
                
                // Treble staff notes
                notesLayer(notes: measure.trebleNotes)
                    .offset(y: -lineSpacing * 3.75)
                
                // Bass staff notes
                notesLayer(notes: measure.bassNotes)
                    .offset(y: lineSpacing * 3.75)
                
                // End barline
                endBarline()
                    .frame(width: 4, height: lineSpacing * 11.5)
                    .offset(x: measureWidth - 4)
            }
        }
        .frame(width: measureWidth)
    }
    
    // MARK: - 5 Lines
    
    @ViewBuilder
    private func staffFiveLines() -> some View {
        VStack(spacing: lineSpacing) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(height: 1)
            }
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Notes Layer
    
    @ViewBuilder
    private func notesLayer(notes: [Note]) -> some View {
        ZStack(alignment: .leading) {
            ForEach(notes) { note in
                let beatOffset = (note.position.beat - 1.0) / 4.0 // proportional offset 0 to 1
                let xPos = 16.0 + CGFloat(beatOffset) * (measureWidth - 36.0)
                let isNoteActive = isCurrent && abs(note.position.beat - currentBeat) < 0.25
                
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
        HStack(spacing: 2) {
            if measure.barlineType == .final {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 1.5)
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 3.5)
            } else if measure.barlineType == .double {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 1.5)
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 1.5)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.8))
                    .frame(width: 1.5)
            }
        }
    }
}
