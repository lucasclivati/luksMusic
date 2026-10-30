// MeasureView.swift
// luksMusic
//
// SwiftUI view rendering a complete musical measure with authentic MuseScore engraving:
// connected horizontal beams for triplets/eighths, triplet brackets ("3"), lyrics, and smooth cursor.

import SwiftUI

/// Authentic MuseScore teardrop droplet handle pointing upward to cursor line
struct TeardropDropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midX = rect.midX
        let radius = w / 2.0
        
        // Start at top sharp apex point
        path.move(to: CGPoint(x: midX, y: 0))
        // Curve down to right rounded bulb
        path.addCurve(
            to: CGPoint(x: w, y: h - radius),
            control1: CGPoint(x: midX + w * 0.25, y: h * 0.35),
            control2: CGPoint(x: w, y: h * 0.6)
        )
        // Arc around the bottom bulb
        path.addArc(
            center: CGPoint(x: midX, y: h - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        // Curve back up to top apex point
        path.addCurve(
            to: CGPoint(x: midX, y: 0),
            control1: CGPoint(x: 0, y: h * 0.6),
            control2: CGPoint(x: midX - w * 0.25, y: h * 0.35)
        )
        path.closeSubpath()
        return path
    }
}

struct MeasureView: View {
    let measure: Measure
    var isCurrent: Bool = false
    var currentBeat: Double = 1.0
    var lineSpacing: CGFloat = 6.4
    var measureWidth: CGFloat = 300.0
    var showMeasureNumber: Bool = true
    var showTempoAndDynamics: Bool = false
    var tempo: Int = 70
    
    private var usableWidth: CGFloat {
        max(50.0, measureWidth - 28.0)
    }
    
    /// Notes under the cursor, matching what the keyboard dock highlights.
    private var activeNoteIds: Set<UUID> {
        guard isCurrent else { return [] }
        return Set(measure.soundingNotes(at: measure.cursorBeat(at: currentBeat)).map(\.id))
    }
    
    /// Beat under a horizontal position inside the measure (inverse of the note layout).
    static func beat(atX x: CGFloat, measureWidth: CGFloat) -> Double {
        let usable = max(50.0, measureWidth - 28.0)
        return 1.0 + Double(max(0.0, min(1.0, (x - 14.0) / usable))) * 4.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Measure Header: Tempo marking & measure number
            HStack(alignment: .bottom) {
                if showMeasureNumber && measure.number > 1 {
                    Text("\(measure.number)")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundColor(Color.black.opacity(0.75))
                        .padding(.leading, 2)
                } else if showTempoAndDynamics {
                    HStack(spacing: 3) {
                        Text("♩ = \(tempo)")
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .foregroundColor(.black)
                    }
                    .padding(.leading, 8)
                }
                Spacer()
            }
            .frame(height: 14)
            
            ZStack(alignment: .leading) {
                // Background paper white
                Rectangle()
                    .fill(Color.white)
                    .frame(width: measureWidth, height: lineSpacing * 14.5)
                
                // Continuous 5-line staff backdrop for both staves
                VStack(spacing: lineSpacing * 3.5) {
                    staffFiveLines()
                    staffFiveLines()
                }
                .frame(width: measureWidth)
                
                // Treble staff notes and beams (centered on Treble Line 3)
                staffNotesWithBeams(notes: measure.trebleNotes)
                    .offset(y: -lineSpacing * 3.75)
                
                // Dynamic marking (e.g. mp on measure 1)
                if showTempoAndDynamics {
                    Text("mp")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(.black)
                        .offset(x: 16, y: -lineSpacing * 1.1)
                }
                
                // Bass staff notes and beams (centered on Bass Line 3)
                staffNotesWithBeams(notes: measure.bassNotes)
                    .offset(y: lineSpacing * 3.75)
                
                // Piano Sustain Pedal Bracket Line below bass staff
                Path { path in
                    let pedY = lineSpacing * 7.4
                    path.move(to: CGPoint(x: 8, y: pedY - 4))
                    path.addLine(to: CGPoint(x: 8, y: pedY))
                    path.addLine(to: CGPoint(x: measureWidth - 4, y: pedY))
                    path.addLine(to: CGPoint(x: measureWidth - 4, y: pedY - 4))
                }
                .stroke(Color.black.opacity(0.85), lineWidth: 1.0)
                
                // Right barline connecting top of treble staff to bottom of bass staff continuously
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 1.5, height: lineSpacing * 11.0)
                    .offset(x: measureWidth - 1.5)
                
                // Authentic MuseScore Playback Cursor with blue teardrop droplet handle
                if isCurrent {
                    let beatOffset = max(0.0, min(1.0, (measure.cursorBeat(at: currentBeat) - 1.0) / 4.0))
                    let cursorX = 14.0 + CGFloat(beatOffset) * usableWidth
                    let cursorColor = Color(red: 0.15, green: 0.55, blue: 0.98)
                    let dropletColor = Color(red: 0.56, green: 0.77, blue: 0.99)
                    
                    ZStack(alignment: .top) {
                        // Vertical cursor line spanning top of treble to bottom of bass
                        Rectangle()
                            .fill(cursorColor)
                            .frame(width: 2.2, height: lineSpacing * 11.6)
                        
                        // Teardrop droplet handle at bottom
                        TeardropDropletShape()
                            .fill(dropletColor)
                            .overlay(
                                TeardropDropletShape()
                                    .stroke(cursorColor, lineWidth: 1.4)
                            )
                            .frame(width: 15, height: 21)
                            .offset(y: lineSpacing * 11.4)
                    }
                    // Zero-width frame centers the line on cursorX, like the noteheads
                    .frame(width: 0)
                    .offset(x: cursorX)
                }
            }
            .frame(width: measureWidth, height: lineSpacing * 14.5)
        }
        .frame(width: measureWidth)
        .background(Color.white)
    }
    
    // MARK: - 5 Lines Staff Backdrop
    
    @ViewBuilder
    private func staffFiveLines() -> some View {
        VStack(spacing: lineSpacing) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 1.1)
            }
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Notes and Beams
    
    @ViewBuilder
    private func staffNotesWithBeams(notes: [Note]) -> some View {
        // Group notes that should be beamed together by beat
        let beamedGroups = findBeamedGroups(in: notes)
        let beamedNoteIds = Set(beamedGroups.flatMap { $0.map(\.id) })
        let activeIds = activeNoteIds
        
        ZStack(alignment: .leading) {
            // 1. Individual Notes
            ForEach(notes) { note in
                let beatOffset = max(0.0, min(1.0, (note.position.beat - 1.0) / 4.0))
                let xPos = 14.0 + CGFloat(beatOffset) * usableWidth
                let isNoteActive = activeIds.contains(note.id)
                let isBeamed = beamedNoteIds.contains(note.id)
                
                NoteView(
                    note: note,
                    playbackState: isNoteActive ? .current : .upcoming,
                    lineSpacing: lineSpacing,
                    useBeatColors: false,
                    isBeamed: isBeamed
                )
                // Zero-width frame centers the notehead on xPos regardless of lyric/accidental width;
                // fixedSize keeps the lyric from being squeezed into that zero width
                .fixedSize()
                .frame(width: 0)
                .offset(x: xPos)
            }
            
            // 2. Beams and Triplet "3" Labels
            ForEach(Array(beamedGroups.enumerated()), id: \.offset) { _, group in
                renderBeam(for: group)
            }
        }
        // Leading alignment: x offsets are measured from the measure's left edge, not from a centered stack
        .frame(width: measureWidth, height: lineSpacing * 4, alignment: .leading)
    }
    
    private func findBeamedGroups(in notes: [Note]) -> [[Note]] {
        let soundNotes = notes.filter { !$0.isRest && ($0.duration == .eighth || $0.duration == .sixteenth) }
        let byBeat = Dictionary(grouping: soundNotes) { Int(floor($0.position.beat)) }
        var groups: [[Note]] = []
        for beatKey in byBeat.keys.sorted() {
            if let beatGroup = byBeat[beatKey], beatGroup.count >= 2 {
                let sorted = beatGroup.sorted { $0.position.beat < $1.position.beat }
                groups.append(sorted)
            }
        }
        return groups
    }
    
    private struct BeamGeometry {
        let xStart: CGFloat
        let beamWidth: CGFloat
        let beamY: CGFloat
        let labelX: CGFloat
        let labelY: CGFloat
        let showTriplet: Bool
    }
    
    private func computeBeamGeometry(for group: [Note]) -> BeamGeometry? {
        guard let firstNote = group.first, let lastNote = group.last else { return nil }
        let firstOffset = CGFloat(max(0.0, min(1.0, (firstNote.position.beat - 1.0) / 4.0)))
        let lastOffset = CGFloat(max(0.0, min(1.0, (lastNote.position.beat - 1.0) / 4.0)))
        
        let stemUp = (firstNote.staff == .treble && firstNote.isTriplet) ? false : firstNote.stemUp
        let stemXOffset: CGFloat = stemUp ? (lineSpacing * 0.6) : (-lineSpacing * 0.6)
        let xStart = 14.0 + firstOffset * usableWidth + stemXOffset
        let xEnd = 14.0 + lastOffset * usableWidth + stemXOffset
        let beamWidth = max(8.0, xEnd - xStart)
        
        let positions = group.map { CGFloat($0.staffPosition) }
        let maxPos: CGFloat = positions.max() ?? 0.0
        let minPos: CGFloat = positions.min() ?? 0.0
        let stemHeight = lineSpacing * 3.2
        
        let beamY: CGFloat
        let labelY: CGFloat
        if stemUp {
            beamY = -maxPos * (lineSpacing * 0.5) - stemHeight
            labelY = beamY - 11.0
        } else {
            beamY = -minPos * (lineSpacing * 0.5) + stemHeight
            labelY = beamY + 3.0
        }
        
        let labelX = (xStart + xEnd) * 0.5 - 4.0
        let showTriplet = group.count == 3 || firstNote.isTriplet
        
        return BeamGeometry(
            xStart: xStart,
            beamWidth: beamWidth,
            beamY: beamY,
            labelX: labelX,
            labelY: labelY,
            showTriplet: showTriplet
        )
    }
    
    @ViewBuilder
    private func renderBeam(for group: [Note]) -> some View {
        if let geom = computeBeamGeometry(for: group) {
            ZStack(alignment: .leading) {
                // Horizontal black beam bar connecting stems
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geom.beamWidth, height: 3.0)
                    .offset(x: geom.xStart, y: geom.beamY)
                
                // Triplet "3" notation above or below the beam
                if geom.showTriplet {
                    Text("3")
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(Color.black)
                        .offset(x: geom.labelX, y: geom.labelY)
                }
            }
        }
    }
    
    // MARK: - Barline
    
    @ViewBuilder
    private func endBarline() -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.85))
            .frame(width: 1.5)
    }
}
