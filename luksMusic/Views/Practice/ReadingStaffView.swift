// ReadingStaffView.swift
// luksMusic
//
// The sight-reading drill's staff: one clef (treble for the right hand, bass for the left), the key signature and
// the segment's notes, each colored by how it was read. A wrong key shows faintly where it would be written, and
// a note's name appears under it once it was found.

import CoreText
import SwiftUI
import UIKit

struct ReadingStaffView: View {
    let steps: [ReadingStep]
    let accidentals: [[Accidental?]]
    let results: [ReadingStepResult]
    /// Index of the step being read; `steps.count` when the segment is done
    let current: Int
    let staff: Staff
    let keySignature: Int
    var wrongPitch: Pitch? = nil
    var listeningStep: Int? = nil
    /// Writes every note's name from the start (lessons, while a note is being introduced)
    var showsAllNames: Bool = false
    /// Beats per measure, drawn as a time signature over 4
    var timeSignature: Int? = nil

    static let ink = Color(red: 0.07, green: 0.09, blue: 0.13)
    static let currentColor = Color(red: 0.14, green: 0.42, blue: 0.94)
    static let rightColor = Color(red: 0.09, green: 0.62, blue: 0.27)
    /// Found after a wrong key or a hint
    static let fixedColor = Color(red: 0.90, green: 0.50, blue: 0.04)
    static let wrongColor = Color(red: 0.86, green: 0.15, blue: 0.15)

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("readingStaff")
    }

    // MARK: - Layout

    /// Pitch positions are diatonic steps from the staff's middle line (+1 is one step up).
    private struct Layout {
        let unit: CGFloat
        let topPosition: Int
        let originY: CGFloat

        var space: CGFloat { unit * 2 }

        func y(_ position: Int) -> CGFloat {
            originY + CGFloat(topPosition - position) * unit
        }
    }

    private struct Column {
        let x: CGFloat
        let positions: [Int]
        let displaced: [Bool]
        let stemUp: Bool
        let stemTip: Int
    }

    private var keyAccidentalSteps: [Int] {
        // Steps above the bottom line, in key-signature order
        switch (staff, keySignature > 0) {
        case (.treble, true): return [8, 5, 9, 6, 3, 7, 4]
        case (.treble, false): return [4, 7, 3, 6, 2, 5, 1]
        case (.bass, true): return [6, 3, 7, 4, 1, 5, 2]
        case (.bass, false): return [2, 5, 1, 4, 0, 3, -1]
        }
    }

    private func position(of pitch: Pitch) -> Int {
        Note(pitch: pitch, staff: staff).staffPosition
    }

    private func hasStem(_ duration: NoteDuration) -> Bool {
        duration != .whole
    }

    private func column(for step: ReadingStep, x: CGFloat) -> Column {
        let positions = step.notes.map { $0.isRest ? 0 : position(of: $0.pitch) }
        var displaced = Array(repeating: false, count: positions.count)
        for index in positions.indices.dropFirst() where positions[index] - positions[index - 1] == 1 && !displaced[index - 1] {
            displaced[index] = true
        }
        let low = positions.min() ?? 0
        let high = positions.max() ?? 0
        let stemUp = low + high < 0
        // Stems are three and a half spaces long (four with two flags) and reach at least the middle line
        let duration = step.notes.first?.duration ?? .quarter
        let length = [NoteDuration.sixteenth, .dottedSixteenth, .thirtySecond].contains(duration) ? 8 : 7
        let stemTip = stemUp ? max(high + length, 0) : min(low - length, 0)
        return Column(x: x, positions: positions, displaced: displaced, stemUp: stemUp, stemTip: stemTip)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 40, size.height > 40 else { return }

        // Vertical room: the staff, every note, ledger line and stem of the segment, the wrong key
        var positions = [-10, 10]
        for step in steps {
            let probe = self.column(for: step, x: 0)
            positions += probe.positions
            if hasStem(step.notes.first?.duration ?? .quarter) {
                positions.append(probe.stemTip)
            }
        }
        if let wrongPitch {
            positions.append(position(of: wrongPitch))
        }
        let highest = (positions.max() ?? 10) + 2
        let lowest = (positions.min() ?? -10) - 2
        let namedLines = steps.indices.filter(showsName).map { steps[$0].notes.count }.max() ?? 0
        let topPad: CGFloat = 16
        let bottomPad: CGFloat = CGFloat(max(1, namedLines)) * 13 + 6
        let unit = min(9, max(3, (size.height - topPad - bottomPad) / CGFloat(highest - lowest)))
        let usedHeight = CGFloat(highest - lowest) * unit
        let originY = topPad + max(0, (size.height - topPad - bottomPad - usedHeight) / 2)
        let layout = Layout(unit: unit, topPosition: highest, originY: originY)
        let space = layout.space

        // Columns
        let left: CGFloat = 10
        let right = size.width - 10
        let clefWidth = space * 3.2
        let keyCount = min(7, abs(keySignature))
        let timeWidth = timeSignature == nil ? 0 : space * 1.8
        let notesStart = left + clefWidth + CGFloat(keyCount) * space * 0.95 + timeWidth + space * 1.2
        // Room after the last column for an eighth's flag
        let columnWidth = steps.isEmpty ? 0 : min((right - notesStart - space * 0.9) / CGFloat(steps.count), space * 7)
        let columns = steps.enumerated().map { index, step in
            column(for: step, x: notesStart + columnWidth * (CGFloat(index) + 0.5))
        }

        // Highlight behind the step being read (or heard)
        for (index, _) in steps.enumerated() where index == current || index == listeningStep {
            let rect = CGRect(x: notesStart + columnWidth * CGFloat(index) + 2, y: layout.y(highest) ,
                              width: columnWidth - 4, height: usedHeight)
            let tint = index == listeningStep ? Color.yellow.opacity(0.22) : Self.currentColor.opacity(0.09)
            context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(tint))
        }

        // Staff lines
        for line in stride(from: -4, through: 4, by: 2) {
            var path = Path()
            path.move(to: CGPoint(x: left, y: layout.y(line)))
            path.addLine(to: CGPoint(x: right, y: layout.y(line)))
            context.stroke(path, with: .color(Self.ink.opacity(0.85)), lineWidth: 1.1)
        }

        // Clef, sized and placed by its ink as an engraving font would: the treble clef's curl around the G line,
        // the bass clef's dots around the F line
        if staff == .treble {
            drawSymbol("𝄞", in: &context, inkHeight: space * 7.0, left: left + space * 0.3,
                       bottom: layout.y(-7) + unit * 0.3)
        } else {
            drawSymbol("𝄢", in: &context, inkHeight: space * 3.6, left: left + space * 0.3,
                       bottom: layout.y(-3) + unit * 0.1)
        }
        let keySymbol = keySignature > 0 ? "♯" : "♭"
        for index in 0..<keyCount {
            let position = keyAccidentalSteps[index] - 4
            let lift = keySignature < 0 ? space * 0.3 : 0
            context.draw(Text(keySymbol).font(.system(size: space * 1.45, weight: .bold)).foregroundColor(Self.ink),
                         at: CGPoint(x: left + clefWidth + space * (0.45 + 0.95 * CGFloat(index)), y: layout.y(position) - lift),
                         anchor: .center)
        }

        if let timeSignature {
            let x = left + clefWidth + CGFloat(keyCount) * space * 0.95 + space * 0.9
            for (digit, position) in [(timeSignature, 2), (4, -2)] {
                context.draw(Text("\(digit)").font(.system(size: space * 2.1, weight: .bold, design: .serif)).foregroundColor(Self.ink),
                             at: CGPoint(x: x, y: layout.y(position)), anchor: .center)
            }
        }

        // Barlines and measure numbers
        for (index, step) in steps.enumerated() {
            let boundary = notesStart + columnWidth * CGFloat(index)
            if index == 0 || steps[index - 1].measureIndex != step.measureIndex {
                if index > 0 {
                    var bar = Path()
                    bar.move(to: CGPoint(x: boundary, y: layout.y(4)))
                    bar.addLine(to: CGPoint(x: boundary, y: layout.y(-4)))
                    context.stroke(bar, with: .color(Self.ink.opacity(0.85)), lineWidth: 1.1)
                }
                // A pickup (measure 0) has no number
                if step.measureNumber > 0 {
                    context.draw(Text("\(step.measureNumber)").font(.system(size: 10, weight: .semibold)).foregroundColor(.gray),
                                 at: CGPoint(x: boundary + 3, y: 2), anchor: .topLeading)
                }
            }
        }

        // Notes
        let headWidth = space * 1.3
        let headHeight = space * 0.95
        for (index, step) in steps.enumerated() {
            let column = columns[index]
            let result = index < results.count ? results[index] : ReadingStepResult()
            let duration = step.notes.first?.duration ?? .quarter
            let isHollow = duration == .whole || duration == .half || duration == .dottedHalf
            let isDotted = [NoteDuration.dottedHalf, .dottedQuarter, .dottedEighth, .dottedSixteenth].contains(duration)
            let stepColor = color(for: index, result: result, midi: nil)
            var accidentalSlot = 0

            for (noteIndex, note) in step.notes.enumerated().reversed() {
                if note.isRest {
                    drawRest(note.duration, in: &context, layout: layout, x: column.x)
                    continue
                }
                let position = column.positions[noteIndex]
                let x = column.x + (column.displaced[noteIndex] ? headWidth * 0.95 : 0)
                let noteColor = color(for: index, result: result, midi: Int(note.midiNote))

                drawLedgerLines(in: &context, layout: layout, position: position, x: x, headWidth: headWidth)
                drawHead(in: &context, at: CGPoint(x: x, y: layout.y(position)), width: headWidth, height: headHeight,
                         hollow: isHollow, color: noteColor, lineWidth: unit * 0.38)

                if isDotted {
                    let dotY = layout.y(position % 2 == 0 ? position + 1 : position)
                    let dotX = x + headWidth * 0.95
                    context.fill(Path(ellipseIn: CGRect(x: dotX - unit * 0.3, y: dotY - unit * 0.3, width: unit * 0.6, height: unit * 0.6)),
                                 with: .color(noteColor))
                }

                if noteIndex < accidentals[safe: index]?.count ?? 0, let accidental = accidentals[index][noteIndex] {
                    let lift = (accidental == .flat || accidental == .doubleFlat) ? space * 0.3 : 0
                    let ax = column.x - headWidth * 1.15 - CGFloat(accidentalSlot) * space * 0.85
                    context.draw(Text(accidental.symbol).font(.system(size: space * 1.6, weight: .bold)).foregroundColor(noteColor),
                                 at: CGPoint(x: ax, y: layout.y(position) - lift), anchor: .center)
                    accidentalSlot += 1
                }
            }

            if hasStem(duration), !step.isRest, let low = column.positions.min(), let high = column.positions.max() {
                let stemX = column.stemUp ? column.x + headWidth / 2 - 0.7 : column.x - headWidth / 2 + 0.7
                var stem = Path()
                stem.move(to: CGPoint(x: stemX, y: layout.y(column.stemUp ? low : high)))
                stem.addLine(to: CGPoint(x: stemX, y: layout.y(column.stemTip)))
                context.stroke(stem, with: .color(stepColor), lineWidth: 1.5)

                let flags: Int
                switch duration {
                case .eighth, .dottedEighth: flags = 1
                case .sixteenth, .dottedSixteenth, .thirtySecond: flags = 2
                default: flags = 0
                }
                for flag in 0..<flags {
                    let tip = CGPoint(x: stemX, y: layout.y(column.stemTip))
                    context.fill(flagPath(at: tip, space: space, stemUp: column.stemUp, index: flag), with: .color(stepColor))
                }
            }

            // The note's name once it was found, or when the answer was shown
            if showsName(index) {
                let nameColor = result.isDone ? stepColor : (showsAllNames ? Self.ink : Self.fixedColor)
                for (line, note) in step.notes.reversed().enumerated() where !note.isRest {
                    context.draw(Text(ReadingDrill.name(of: note.pitch)).font(.system(size: 11, weight: .bold)).foregroundColor(nameColor),
                                 at: CGPoint(x: column.x, y: layout.y(lowest) + 4 + CGFloat(line) * 13), anchor: .top)
                }
            }
        }

        // The wrong key, faint, beside the note being read
        if let wrongPitch, current < columns.count {
            let wrongPosition = self.position(of: wrongPitch)
            let x = columns[current].x + headWidth * 1.15
            drawLedgerLines(in: &context, layout: layout, position: wrongPosition, x: x, headWidth: headWidth, color: Self.wrongColor.opacity(0.5))
            drawHead(in: &context, at: CGPoint(x: x, y: layout.y(wrongPosition)), width: headWidth, height: headHeight,
                     hollow: false, color: Self.wrongColor.opacity(0.6), lineWidth: unit * 0.38)
        }
    }

    private func showsName(_ index: Int) -> Bool {
        guard index < results.count else { return showsAllNames }
        return showsAllNames || results[index].isDone || (index == current && results[index].revealed)
    }

    private func color(for index: Int, result: ReadingStepResult, midi: Int?) -> Color {
        if result.isDone {
            return result.isClean ? Self.rightColor : Self.fixedColor
        }
        if index == current {
            if let midi, result.played.contains(midi) {
                return Self.rightColor
            }
            return Self.currentColor
        }
        return Self.ink
    }

    private func drawRest(_ duration: NoteDuration, in context: inout GraphicsContext, layout: Layout, x: CGFloat) {
        let space = layout.space
        func place(_ path: Path, width: CGFloat, height: CGFloat) -> Path {
            path.offsetBy(dx: x - width / 2, dy: layout.y(0) - height / 2)
        }
        let ink = GraphicsContext.Shading.color(Self.ink)
        switch duration {
        case .whole:
            // Hangs from the fourth line
            context.fill(Path(CGRect(x: x - space * 0.7, y: layout.y(2), width: space * 1.4, height: space * 0.5)), with: ink)
        case .half, .dottedHalf:
            // Sits on the middle line
            context.fill(Path(CGRect(x: x - space * 0.7, y: layout.y(0) - space * 0.5, width: space * 1.4, height: space * 0.5)), with: ink)
        case .quarter, .dottedQuarter:
            let width = space * 1.05
            let height = space * 3.0
            context.fill(place(QuarterRestShape().path(in: CGRect(x: 0, y: 0, width: width, height: height)), width: width, height: height), with: ink)
        case .eighth, .dottedEighth:
            let width = space * 1.1
            let height = space * 2.2
            context.fill(place(EighthRestShape().path(in: CGRect(x: 0, y: 0, width: width, height: height)), width: width, height: height), with: ink)
        case .sixteenth, .dottedSixteenth, .thirtySecond:
            let width = space * 1.1
            let height = space * 2.8
            context.fill(place(SixteenthRestShape().path(in: CGRect(x: 0, y: 0, width: width, height: height)), width: width, height: height), with: ink)
        }
    }

    /// An engraved flag hanging from the stem's tip toward the notehead: thick at the stem, tapering to a point.
    /// `index` 1 is the second flag of a sixteenth, three quarters of a space nearer the notehead.
    private func flagPath(at tip: CGPoint, space: CGFloat, stemUp: Bool, index: Int) -> Path {
        // Drawn for a stem going up (the flag goes down from the tip); mirrored for a stem going down
        let direction: CGFloat = stemUp ? 1 : -1
        let start = tip.y + direction * CGFloat(index) * space * 0.8
        func point(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: tip.x + dx * space, y: start + direction * dy * space)
        }
        var path = Path()
        path.move(to: point(0, 0))
        path.addCurve(to: point(0.95, 2.5), control1: point(0.15, 0.95), control2: point(1.3, 1.3))
        path.addCurve(to: point(0, 0.8), control1: point(0.95, 1.6), control2: point(0.4, 1.15))
        path.closeSubpath()
        return path
    }

    /// Draws a music symbol from the system fonts with its ink `inkHeight` points tall, the ink's left edge at
    /// `left` and its lowest point at `bottom`. A Text's frame follows the font's line height, not the glyph,
    /// so music symbols drawn as Text land off their staff lines.
    private func drawSymbol(_ symbol: String, in context: inout GraphicsContext, inkHeight: CGFloat, left: CGFloat, bottom: CGFloat) {
        func line(size: CGFloat) -> CTLine {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size),
                NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): UIColor(Self.ink).cgColor
            ]
            return CTLineCreateWithAttributedString(NSAttributedString(string: symbol, attributes: attributes))
        }
        let probe = CTLineGetBoundsWithOptions(line(size: 100), .useGlyphPathBounds)
        guard probe.height > 0 else { return }
        let drawn = line(size: 100 * inkHeight / probe.height)
        let ink = CTLineGetBoundsWithOptions(drawn, .useGlyphPathBounds)
        context.withCGContext { cg in
            cg.saveGState()
            // Core Text draws with y up from the baseline
            cg.translateBy(x: left - ink.minX, y: bottom + ink.minY)
            cg.scaleBy(x: 1, y: -1)
            cg.textMatrix = .identity
            cg.textPosition = .zero
            CTLineDraw(drawn, cg)
            cg.restoreGState()
        }
    }

    private func drawHead(in context: inout GraphicsContext, at center: CGPoint, width: CGFloat, height: CGFloat,
                          hollow: Bool, color: Color, lineWidth: CGFloat) {
        let ellipse = Path(ellipseIn: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
            .applying(CGAffineTransform(rotationAngle: -.pi / 9))
            .applying(CGAffineTransform(translationX: center.x, y: center.y))
        if hollow {
            context.stroke(ellipse, with: .color(color), lineWidth: lineWidth)
        } else {
            context.fill(ellipse, with: .color(color))
        }
    }

    private func drawLedgerLines(in context: inout GraphicsContext, layout: Layout, position: Int, x: CGFloat,
                                 headWidth: CGFloat, color: Color = ReadingStaffView.ink.opacity(0.8)) {
        let lines: [Int]
        if position >= 6 {
            lines = Array(stride(from: 6, through: position, by: 2))
        } else if position <= -6 {
            lines = Array(stride(from: -6, through: position, by: -2))
        } else {
            lines = []
        }
        for line in lines {
            var path = Path()
            path.move(to: CGPoint(x: x - headWidth * 0.8, y: layout.y(line)))
            path.addLine(to: CGPoint(x: x + headWidth * 0.8, y: layout.y(line)))
            context.stroke(path, with: .color(color), lineWidth: 1.3)
        }
    }

    private var accessibilityText: String {
        let clef = staff == .treble ? "Clave de sol" : "Clave de fá"
        return "\(clef), \(steps.count) notas"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
