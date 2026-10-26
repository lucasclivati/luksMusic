// NoteView.swift
// luksMusic
//
// SwiftUI view rendering a musical note or rest on the staff with stems, vector flags, and accidentals.

import SwiftUI

struct NoteView: View {
    let note: Note
    var playbackState: NotePlaybackState = .upcoming
    var lineSpacing: CGFloat = 8.5
    var useBeatColors: Bool = false
    var isBeamed: Bool = false
    
    var body: some View {
        ZStack {
            if note.isRest {
                renderRest()
            } else {
                renderNote()
            }
        }
    }
    
    // MARK: - Rest Rendering (Vector Paths, Zero Missing Glyphs)
    
    @ViewBuilder
    private func renderRest() -> some View {
        let restColor = noteColor.opacity(0.85)
        switch note.duration {
        case .whole:
            // Whole rest: rectangle hanging below line 4 (staffPosition = 2)
            Rectangle()
                .fill(restColor)
                .frame(width: lineSpacing * 1.4, height: lineSpacing * 0.45)
                .offset(y: -lineSpacing * 0.77)
                
        case .half, .dottedHalf:
            // Half rest: rectangle resting on line 3 (staffPosition = 0)
            Rectangle()
                .fill(restColor)
                .frame(width: lineSpacing * 1.4, height: lineSpacing * 0.45)
                .offset(y: -lineSpacing * 0.22)
                
        case .quarter, .dottedQuarter:
            QuarterRestShape()
                .fill(restColor)
                .frame(width: lineSpacing * 0.85, height: lineSpacing * 2.8)
                .offset(y: -lineSpacing * 0.1)
                
        case .eighth, .dottedEighth:
            EighthRestShape()
                .fill(restColor)
                .frame(width: lineSpacing * 0.9, height: lineSpacing * 2.2)
                .offset(y: -lineSpacing * 0.1)
                
        case .sixteenth, .dottedSixteenth, .thirtySecond:
            SixteenthRestShape()
                .fill(restColor)
                .frame(width: lineSpacing * 1.0, height: lineSpacing * 2.6)
                .offset(y: -lineSpacing * 0.1)
        }
    }
    
    // MARK: - Note Rendering
    
    @ViewBuilder
    private func renderNote() -> some View {
        let isFilled = note.duration != .whole && note.duration != .half && note.duration != .dottedHalf
        let hasStem = note.duration != .whole
        let stemUp = (note.staff == .treble && note.isTriplet) ? false : note.stemUp
        
        ZStack {
            // Ledger lines if outside 5-line staff
            renderLedgerLines()
            
            // Accidental (positioned to the left of the notehead without shifting the beat anchor)
            if note.pitch.accidental != .natural {
                Text(accidentalString)
                    .font(.system(size: lineSpacing * 1.6, weight: .bold))
                    .foregroundColor(noteColor)
                    .offset(x: -lineSpacing * 1.15, y: verticalOffset)
            }
            
            // Notehead
            Ellipse()
                .fill(isFilled ? noteColor : Color.clear)
                .overlay(
                    Ellipse()
                        .stroke(noteColor, lineWidth: 2.2)
                )
                .frame(width: lineSpacing * 1.35, height: lineSpacing * 0.95)
                .rotationEffect(.degrees(-20))
                .offset(y: verticalOffset)
            
            // Stem
            if hasStem {
                let stemHeight = lineSpacing * 3.2
                let stemX = stemUp ? (lineSpacing * 0.6) : (-lineSpacing * 0.6)
                let stemY = verticalOffset + (stemUp ? (-stemHeight * 0.5) : (stemHeight * 0.5))
                
                Rectangle()
                    .fill(noteColor)
                    .frame(width: 1.6, height: stemHeight)
                    .offset(x: stemX, y: stemY)
                
                // Vector Flag for single un-beamed 8th/16th notes
                if !isBeamed {
                    if note.duration == .eighth || note.duration == .dottedEighth {
                        NoteFlagShape(stemUp: stemUp, isSixteenth: false)
                            .fill(noteColor)
                            .frame(width: lineSpacing * 0.9, height: lineSpacing * 1.8)
                            .offset(
                                x: stemUp ? (stemX + lineSpacing * 0.45) : (stemX + lineSpacing * 0.45),
                                y: stemUp ? (verticalOffset - stemHeight + lineSpacing * 0.9) : (verticalOffset + stemHeight - lineSpacing * 0.9)
                            )
                    } else if note.duration == .sixteenth || note.duration == .dottedSixteenth {
                        NoteFlagShape(stemUp: stemUp, isSixteenth: true)
                            .fill(noteColor)
                            .frame(width: lineSpacing * 0.9, height: lineSpacing * 2.4)
                            .offset(
                                x: stemUp ? (stemX + lineSpacing * 0.45) : (stemX + lineSpacing * 0.45),
                                y: stemUp ? (verticalOffset - stemHeight + lineSpacing * 1.2) : (verticalOffset + stemHeight - lineSpacing * 1.2)
                            )
                    }
                }
            }
            
            // Lyrics syllable text below staff
            if let lyric = note.lyric {
                Text(lyric)
                    .font(.system(size: max(10, lineSpacing * 1.05), weight: .semibold, design: .serif))
                    .foregroundColor(Color.black.opacity(0.85))
                    .offset(y: lineSpacing * 4.6)
            }
            
            // Rhythmic Dot
            if note.duration == .dottedHalf || note.duration == .dottedQuarter || note.duration == .dottedEighth || note.duration == .dottedSixteenth {
                Circle()
                    .fill(noteColor)
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: lineSpacing * 1.15, y: verticalOffset)
            }
            
            // Finger annotation
            if let finger = note.fingerNumber {
                Text("\(finger)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .offset(y: verticalOffset + (stemUp ? (-lineSpacing * 3.6) : (lineSpacing * 2.6)))
            }
        }
    }
    
    // MARK: - Ledger Lines
    
    @ViewBuilder
    private func renderLedgerLines() -> some View {
        let linesAbove = note.ledgerLinesAbove
        let linesBelow = note.ledgerLinesBelow
        
        if linesAbove > 0 {
            ForEach(1...linesAbove, id: \.self) { i in
                let lineStep = 4 + (i * 2)
                Rectangle()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: lineSpacing * 2.2, height: 1.4)
                    .offset(y: -CGFloat(lineStep) * (lineSpacing * 0.5))
            }
        }
        
        if linesBelow > 0 {
            ForEach(1...linesBelow, id: \.self) { i in
                let lineStep = 4 + (i * 2)
                Rectangle()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: lineSpacing * 2.2, height: 1.4)
                    .offset(y: CGFloat(lineStep) * (lineSpacing * 0.5))
            }
        }
    }
    
    // MARK: - Offsets and Colors
    
    private var verticalOffset: CGFloat {
        -CGFloat(note.staffPosition) * (lineSpacing * 0.5)
    }
    
    private var accidentalString: String {
        switch note.pitch.accidental {
        case .natural: return "♮"
        case .sharp: return "♯"
        case .flat: return "♭"
        case .doubleSharp: return "𝄪"
        case .doubleFlat: return "𝄫"
        }
    }
    
    private var noteColor: Color {
        switch playbackState {
        case .upcoming:
            return useBeatColors ? Color.colorForBeat(note.position.beat) : Color.black
        case .current:
            return Color(red: 0.1, green: 0.45, blue: 0.95)
        case .correct:
            return Color(red: 0.22, green: 0.85, blue: 0.38)
        case .incorrect:
            return Color.red
        case .played:
            return useBeatColors ? Color.secondary.opacity(0.4) : Color.black.opacity(0.45)
        }
    }
}

// MARK: - Vector Shapes for Musical Engraving

/// Smooth vector flag attached to single eighth or sixteenth note stems.
struct NoteFlagShape: Shape {
    let stemUp: Bool
    let isSixteenth: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        if stemUp {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addCurve(
                to: CGPoint(x: w, y: h * 0.6),
                control1: CGPoint(x: w * 0.8, y: h * 0.1),
                control2: CGPoint(x: w * 1.1, y: h * 0.35)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: h * 0.4),
                control1: CGPoint(x: w * 0.6, y: h * 0.5),
                control2: CGPoint(x: w * 0.2, y: h * 0.45)
            )
            path.closeSubpath()
            
            if isSixteenth {
                path.move(to: CGPoint(x: 0, y: h * 0.35))
                path.addCurve(
                    to: CGPoint(x: w, y: h * 0.95),
                    control1: CGPoint(x: w * 0.8, y: h * 0.45),
                    control2: CGPoint(x: w * 1.1, y: h * 0.7)
                )
                path.addCurve(
                    to: CGPoint(x: 0, y: h * 0.75),
                    control1: CGPoint(x: w * 0.6, y: h * 0.85),
                    control2: CGPoint(x: w * 0.2, y: h * 0.8)
                )
                path.closeSubpath()
            }
        } else {
            path.move(to: CGPoint(x: 0, y: h))
            path.addCurve(
                to: CGPoint(x: w, y: h * 0.4),
                control1: CGPoint(x: w * 0.8, y: h * 0.9),
                control2: CGPoint(x: w * 1.1, y: h * 0.65)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: h * 0.6),
                control1: CGPoint(x: w * 0.6, y: h * 0.5),
                control2: CGPoint(x: w * 0.2, y: h * 0.55)
            )
            path.closeSubpath()
            
            if isSixteenth {
                path.move(to: CGPoint(x: 0, y: h * 0.65))
                path.addCurve(
                    to: CGPoint(x: w, y: h * 0.05),
                    control1: CGPoint(x: w * 0.8, y: h * 0.55),
                    control2: CGPoint(x: w * 1.1, y: h * 0.3)
                )
                path.addCurve(
                    to: CGPoint(x: 0, y: h * 0.25),
                    control1: CGPoint(x: w * 0.6, y: h * 0.15),
                    control2: CGPoint(x: w * 0.2, y: h * 0.2)
                )
                path.closeSubpath()
            }
        }
        
        return path
    }
}

/// Classical quarter rest shape (lightning zig-zag path).
struct QuarterRestShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.2, y: 0))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.75))
        path.addCurve(
            to: CGPoint(x: w * 0.1, y: h),
            control1: CGPoint(x: w * 0.6, y: h * 0.85),
            control2: CGPoint(x: w * 0.2, y: h * 0.92)
        )
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.78))
        path.addLine(to: CGPoint(x: 0, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.28))
        path.closeSubpath()
        return path
    }
}

/// Classical eighth rest shape.
struct EighthRestShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Circular head
        path.addEllipse(in: CGRect(x: 0, y: h * 0.1, width: w * 0.55, height: w * 0.55))
        // Hook and slanted stem
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.25))
        path.addCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.4),
            control1: CGPoint(x: w * 0.7, y: h * 0.2),
            control2: CGPoint(x: w * 0.85, y: h * 0.3)
        )
        path.addLine(to: CGPoint(x: w * 0.35, y: h))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.45))
        path.closeSubpath()
        return path
    }
}

/// Classical sixteenth rest shape (two hooks).
struct SixteenthRestShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Upper hook & head
        path.addEllipse(in: CGRect(x: 0, y: h * 0.05, width: w * 0.5, height: w * 0.5))
        // Lower hook & head
        path.addEllipse(in: CGRect(x: 0, y: h * 0.4, width: w * 0.5, height: w * 0.5))
        // Slanted stem
        path.move(to: CGPoint(x: w * 0.8, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 0.3, y: h))
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.2))
        path.closeSubpath()
        return path
    }
}
