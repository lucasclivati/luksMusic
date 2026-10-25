import SwiftUI

// MARK: - Falling Note Model

/// Represents a single note in the falling notes visualization.
struct FallingNote: Identifiable, Equatable {
    let id: UUID
    /// MIDI note number.
    let midiNote: Int
    /// Start time in beats from the beginning of the piece.
    let startBeat: Double
    /// Duration in beats.
    let durationBeats: Double
    /// Which hand plays this note.
    let hand: Hand
    /// Current play state of this note.
    var state: NoteState
    
    enum Hand: Equatable {
        case right
        case left
    }
    
    enum NoteState: Equatable {
        case upcoming
        case active
        case correct
        case incorrect
        case missed
        case passed
    }
    
    init(
        id: UUID = UUID(),
        midiNote: Int,
        startBeat: Double,
        durationBeats: Double,
        hand: Hand = .right,
        state: NoteState = .upcoming
    ) {
        self.id = id
        self.midiNote = midiNote
        self.startBeat = startBeat
        self.durationBeats = durationBeats
        self.hand = hand
        self.state = state
    }
}

// MARK: - Falling Notes View Model

/// View model managing the falling notes visualization state.
@Observable
final class FallingNotesViewModel {
    /// All notes to display.
    var notes: [FallingNote] = []
    /// Current playback position in beats.
    var currentBeat: Double = 0.0
    /// Tempo in beats per minute.
    var tempo: Double = 120.0
    /// Number of beats visible above the hit line.
    var visibleBeats: Double = 8.0
    /// Time signature numerator (beats per measure).
    var beatsPerMeasure: Int = 4
    /// Whether playback is active.
    var isPlaying: Bool = false
    /// Set of MIDI notes in the keyboard range for width calculations.
    var keyboardRangeStart: Int = 48
    var keyboardRangeEnd: Int = 84
    
    /// Advances the current beat based on elapsed time.
    func advance(by deltaSeconds: Double) {
        guard isPlaying else { return }
        let deltaBeats = (tempo / 60.0) * deltaSeconds
        currentBeat += deltaBeats
    }
    
    /// Returns notes that should be visible in the current window.
    var visibleNotes: [FallingNote] {
        let windowStart = currentBeat - 1.0 // Show slightly past hit line
        let windowEnd = currentBeat + visibleBeats
        return notes.filter { note in
            let noteEnd = note.startBeat + note.durationBeats
            return noteEnd >= windowStart && note.startBeat <= windowEnd
        }
    }
}

// MARK: - Falling Notes View

/// Synthesia-style falling notes visualization rendered using Canvas for performance.
struct FallingNotesView: View {
    @Bindable var viewModel: FallingNotesViewModel
    
    init(viewModel: FallingNotesViewModel) {
        self.viewModel = viewModel
    }
    
    init(notes: [FallingNote], tempo: Int, isPlaying: Bool, startKey: Int = 48, keyCount: Int = 36) {
        let vm = FallingNotesViewModel()
        vm.notes = notes
        vm.tempo = Double(tempo)
        vm.isPlaying = isPlaying
        vm.keyboardRangeStart = startKey
        vm.keyboardRangeEnd = startKey + keyCount
        self.viewModel = vm
    }
    
    /// Reference date for animation timing.
    @State private var lastUpdate: Date = .now
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                drawBeatGrid(context: context, size: size)
                drawHitLine(context: context, size: size)
                drawNotes(context: context, size: size)
            }
            .onChange(of: timeline.date) { _, newDate in
                let delta = newDate.timeIntervalSince(lastUpdate)
                lastUpdate = newDate
                viewModel.advance(by: delta)
            }
        }
        .background(Color(white: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Drawing
    
    /// Draws vertical beat division grid lines.
    private func drawBeatGrid(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.9
        let pixelsPerBeat = hitLineY / viewModel.visibleBeats
        
        let startBeat = Int(floor(viewModel.currentBeat))
        let endBeat = Int(ceil(viewModel.currentBeat + viewModel.visibleBeats))
        
        for beat in startBeat...endBeat {
            let relativeBeat = Double(beat) - viewModel.currentBeat
            let y = hitLineY - (relativeBeat * pixelsPerBeat)
            
            guard y >= 0 && y <= size.height else { continue }
            
            let isMeasureLine = beat % viewModel.beatsPerMeasure == 0
            let lineWidth: CGFloat = isMeasureLine ? 1.0 : 0.5
            let opacity: Double = isMeasureLine ? 0.25 : 0.1
            
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            
            context.stroke(
                path,
                with: .color(.white.opacity(opacity)),
                lineWidth: lineWidth
            )
            
            // Measure number labels
            if isMeasureLine && beat >= 0 {
                let measureNumber = (beat / viewModel.beatsPerMeasure) + 1
                let text = Text("\(measureNumber)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                context.draw(
                    context.resolve(text),
                    at: CGPoint(x: 14, y: y - 8)
                )
            }
        }
    }
    
    /// Draws the glowing hit line at the bottom.
    private func drawHitLine(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.9
        
        // Glow effect
        var glowPath = Path()
        glowPath.move(to: CGPoint(x: 0, y: hitLineY))
        glowPath.addLine(to: CGPoint(x: size.width, y: hitLineY))
        
        context.stroke(
            glowPath,
            with: .color(.indigo.opacity(0.4)),
            lineWidth: 6
        )
        
        // Crisp line
        context.stroke(
            glowPath,
            with: .linearGradient(
                Gradient(colors: [.indigo, .purple, .indigo]),
                startPoint: CGPoint(x: 0, y: hitLineY),
                endPoint: CGPoint(x: size.width, y: hitLineY)
            ),
            lineWidth: 2
        )
    }
    
    /// Draws all visible falling note rectangles.
    private func drawNotes(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.9
        let pixelsPerBeat = hitLineY / viewModel.visibleBeats
        let totalMidiRange = viewModel.keyboardRangeEnd - viewModel.keyboardRangeStart + 1
        
        // Calculate white key count for width mapping
        let whiteKeyCount = (viewModel.keyboardRangeStart...viewModel.keyboardRangeEnd)
            .filter { !isBlackKey($0) }
            .count
        let whiteKeyWidth = size.width / CGFloat(max(whiteKeyCount, 1))
        
        for note in viewModel.visibleNotes {
            let x = xPosition(for: note.midiNote, size: size, whiteKeyWidth: whiteKeyWidth)
            let noteWidth = isBlackKey(note.midiNote)
                ? whiteKeyWidth * 0.6
                : whiteKeyWidth - 1
            
            // Y position: hit line is current beat, notes fall down
            let relativeBeat = note.startBeat - viewModel.currentBeat
            let noteTopY = hitLineY - ((relativeBeat + note.durationBeats) * pixelsPerBeat)
            let noteBottomY = hitLineY - (relativeBeat * pixelsPerBeat)
            let noteHeight = max(noteBottomY - noteTopY, 4)
            
            let rect = CGRect(
                x: x - noteWidth / 2,
                y: noteTopY,
                width: noteWidth,
                height: noteHeight
            )
            
            let cornerRadius: CGFloat = 4
            let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
                .path(in: rect)
            
            let color = noteColor(for: note)
            
            // Shadow / glow for active notes
            if note.state == .active || note.state == .correct {
                context.fill(
                    roundedRect,
                    with: .color(color.opacity(0.3))
                )
            }
            
            // Fill
            context.fill(
                roundedRect,
                with: .linearGradient(
                    Gradient(colors: [color, color.opacity(0.8)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.minX, y: rect.maxY)
                )
            )
            
            // Border
            context.stroke(
                roundedRect,
                with: .color(color.opacity(0.6)),
                lineWidth: 1
            )
        }
    }
    
    // MARK: - Helpers
    
    /// Returns the X center position for a given MIDI note.
    private func xPosition(for midiNote: Int, size: CGSize, whiteKeyWidth: CGFloat) -> CGFloat {
        // Count how many white keys are before this note
        let whiteKeysBefore = (viewModel.keyboardRangeStart..<midiNote)
            .filter { !isBlackKey($0) }
            .count
        
        if isBlackKey(midiNote) {
            // Black key is between two white keys
            return CGFloat(whiteKeysBefore) * whiteKeyWidth
        } else {
            return (CGFloat(whiteKeysBefore) + 0.5) * whiteKeyWidth
        }
    }
    
    /// Whether a MIDI note is a black key.
    private func isBlackKey(_ midiNote: Int) -> Bool {
        let blackIndices: Set<Int> = [1, 3, 6, 8, 10]
        return blackIndices.contains(midiNote % 12)
    }
    
    /// Returns the display color for a falling note based on its state and hand.
    private func noteColor(for note: FallingNote) -> Color {
        switch note.state {
        case .upcoming:
            return note.hand == .right ? .indigo : .purple
        case .active:
            return note.hand == .right ? .blue : .purple
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .missed:
            return .red.opacity(0.5)
        case .passed:
            return .gray.opacity(0.4)
        }
    }
}

// MARK: - Preview

#Preview("Falling Notes") {
    let vm = FallingNotesViewModel()
    
    FallingNotesView(viewModel: vm)
        .frame(height: 400)
        .padding()
        .background(Color(white: 0.08))
        .onAppear {
            // Sample notes: C Major scale ascending
            let scale: [(Int, Double, Double, FallingNote.Hand)] = [
                (60, 0.0, 1.0, .right),  // C4
                (62, 1.0, 1.0, .right),  // D4
                (64, 2.0, 1.0, .right),  // E4
                (65, 3.0, 1.0, .right),  // F4
                (67, 4.0, 1.0, .right),  // G4
                (69, 5.0, 1.0, .right),  // A4
                (71, 6.0, 1.0, .right),  // B4
                (72, 7.0, 2.0, .right),  // C5 (whole note)
                // Left hand chords
                (48, 0.0, 2.0, .left),   // C3
                (52, 0.0, 2.0, .left),   // E3
                (55, 0.0, 2.0, .left),   // G3
                (48, 4.0, 2.0, .left),   // C3
                (53, 4.0, 2.0, .left),   // F3
                (57, 4.0, 2.0, .left),   // A3
            ]
            
            vm.notes = scale.map { midi, start, dur, hand in
                FallingNote(
                    id: UUID(),
                    midiNote: midi,
                    startBeat: start,
                    durationBeats: dur,
                    hand: hand,
                    state: .upcoming
                )
            }
            
            vm.isPlaying = true
            vm.tempo = 80
        }
}
