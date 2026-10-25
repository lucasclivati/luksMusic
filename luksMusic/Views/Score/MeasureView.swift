// MeasureView.swift
// luksMusic
//
// SwiftUI view rendering a complete musical measure with authentic MuseScore engraving:
// connected horizontal beams for triplets/eighths, triplet brackets ("3"), lyrics, and smooth cursor.

import SwiftUI

struct MeasureView: View {
    let measure: Measure
    var isCurrent: Bool = false
    var currentBeat: Double = 1.0
    var lineSpacing: CGFloat = 12.0
    var measureWidth: CGFloat = 280.0
    
    private var usableWidth: CGFloat {
        measureWidth - 48.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Measure number badge
            Text("\(measure.number)")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(isCurrent ? .accentColor : Color.black.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    isCurrent ? Color.accentColor.opacity(0.18) : Color.clear
                )
                .cornerRadius(4)
                .padding(.leading, 6)
            
            ZStack(alignment: .leading) {
                // Background paper white
                Rectangle()
                    .fill(Color.white)
                    .frame(width: measureWidth, height: lineSpacing * 14.0)
                
                // Continuous 5-line staff backdrop for both staves
                VStack(spacing: lineSpacing * 3.5) {
                    staffFiveLines()
                    staffFiveLines()
                }
                .frame(width: measureWidth)
                
                // Treble staff notes and beams (centered on Treble Line 3)
                staffNotesWithBeams(notes: measure.trebleNotes)
                    .offset(y: -lineSpacing * 3.75)
                
                // Bass staff notes and beams (centered on Bass Line 3)
                staffNotesWithBeams(notes: measure.bassNotes)
                    .offset(y: lineSpacing * 3.75)
                
                // Right barline connecting top of treble staff to bottom of bass staff
                endBarline()
                    .frame(width: 4, height: lineSpacing * 11.5)
                    .offset(x: measureWidth - 4)
                
                // Smooth Playback Cursor (like MuseScore blue cursor bar)
                if isCurrent {
                    let beatOffset = max(0.0, min(1.0, (currentBeat - 1.0) / 4.0))
                    let cursorX = 24.0 + CGFloat(beatOffset) * usableWidth
                    Rectangle()
                        .fill(Color.blue.opacity(0.35))
                        .frame(width: 3.5, height: lineSpacing * 12.0)
                        .offset(x: cursorX)
                }
            }
            .frame(width: measureWidth, height: lineSpacing * 14.0)
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
                    .frame(height: 1.2)
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
        
        ZStack(alignment: .leading) {
            // 1. Individual Notes
            ForEach(notes) { note in
                let beatOffset = max(0.0, min(1.0, (note.position.beat - 1.0) / 4.0))
                let xPos = 24.0 + CGFloat(beatOffset) * usableWidth
                let isNoteActive = isCurrent && abs(note.position.beat - currentBeat) < 0.22
                let isBeamed = beamedNoteIds.contains(note.id)
                
                NoteView(
                    note: note,
                    playbackState: isNoteActive ? .current : .upcoming,
                    lineSpacing: lineSpacing,
                    useBeatColors: false,
                    isBeamed: isBeamed
                )
                .offset(x: xPos)
            }
            
            // 2. Beams and Triplet "3" Labels
            ForEach(Array(beamedGroups.enumerated()), id: \.offset) { _, group in
                renderBeam(for: group)
            }
        }
        .frame(width: measureWidth, height: lineSpacing * 4)
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
        
        let stemUp = firstNote.stemUp
        let stemXOffset: CGFloat = stemUp ? (lineSpacing * 0.6) : (-lineSpacing * 0.6)
        let xStart = 24.0 + firstOffset * usableWidth + stemXOffset
        let xEnd = 24.0 + lastOffset * usableWidth + stemXOffset
        let beamWidth = max(8.0, xEnd - xStart)
        
        let positions = group.map { CGFloat($0.staffPosition) }
        let maxPos: CGFloat = positions.max() ?? 0.0
        let minPos: CGFloat = positions.min() ?? 0.0
        let stemHeight = lineSpacing * 3.2
        
        let beamY: CGFloat
        let labelY: CGFloat
        if stemUp {
            beamY = -maxPos * (lineSpacing * 0.5) - stemHeight
            labelY = beamY - 13.0
        } else {
            beamY = -minPos * (lineSpacing * 0.5) + stemHeight
            labelY = beamY + 4.0
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
                    .frame(width: geom.beamWidth, height: 3.5)
                    .offset(x: geom.xStart, y: geom.beamY)
                
                // Triplet "3" notation above or below the beam
                if geom.showTriplet {
                    Text("3")
                        .font(.system(size: 11, weight: .bold, design: .serif))
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
