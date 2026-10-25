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
        case right // Cyan / Electric Blue
        case left  // Green / Neon
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
    /// Palette matching Synthesia visual reference
    static let neonGreen = Color(red: 0.22, green: 0.95, blue: 0.38)
    static let electricCyan = Color(red: 0.0, green: 0.88, blue: 1.0)
    static let backgroundDark = Color(red: 0.07, green: 0.09, blue: 0.11)
    
    /// All notes to display.
    var notes: [FallingNote] = []
    /// Current playback position in beats.
    var currentBeat: Double = 0.0
    /// Tempo in beats per minute.
    var tempo: Double = 72.0
    /// Number of beats visible above the hit line.
    var visibleBeats: Double = 8.0
    /// Time signature numerator (beats per measure).
    var beatsPerMeasure: Int = 4
    /// Whether playback is active.
    var isPlaying: Bool = false
    /// Set of MIDI notes in the keyboard range for width calculations.
    var keyboardRangeStart: Int = 48
    var keyboardRangeEnd: Int = 84
    
    /// Active MIDI notes currently striking the hit line mapped to their beat colors
    var activeHitMidiNotes: Set<Int> = []
    var activeBassHitNotes: Set<Int> = []
    var activeTrebleHitNotes: Set<Int> = []
    var activeHitKeyColors: [Int: Color] = [:]
    
    /// Advances the current beat based on elapsed time.
    func advance(by deltaSeconds: Double) {
        guard isPlaying else { return }
        let deltaBeats = (tempo / 60.0) * deltaSeconds
        currentBeat += deltaBeats
        updateActiveHitNotes()
    }
    
    /// Calculates which notes are actively striking the hit line.
    private func updateActiveHitNotes() {
        var active: Set<Int> = []
        var bass: Set<Int> = []
        var treble: Set<Int> = []
        var colors: [Int: Color] = [:]
        
        for note in notes {
            let noteEnd = note.startBeat + note.durationBeats
            if currentBeat >= (note.startBeat - 0.05) && currentBeat <= (noteEnd + 0.05) {
                active.insert(note.midiNote)
                let beatColor = Color.colorForBeat(note.startBeat, beatsPerMeasure: beatsPerMeasure)
                colors[note.midiNote] = beatColor
                if note.hand == .left {
                    bass.insert(note.midiNote)
                } else {
                    treble.insert(note.midiNote)
                }
            }
        }
        
        activeHitMidiNotes = active
        activeBassHitNotes = bass
        activeTrebleHitNotes = treble
        activeHitKeyColors = colors
    }
    
    /// Returns notes that should be visible in the current window.
    var visibleNotes: [FallingNote] {
        let windowStart = currentBeat - 0.8
        let windowEnd = currentBeat + visibleBeats
        return notes.filter { note in
            let noteEnd = note.startBeat + note.durationBeats
            return noteEnd >= windowStart && note.startBeat <= windowEnd
        }
    }
}

// MARK: - Falling Notes View

/// Synthesia-style falling notes visualization rendered using Canvas for 60fps performance.
struct FallingNotesView: View {
    @Bindable var viewModel: FallingNotesViewModel
    var onActiveKeysChanged: ((Set<Int>, Set<Int>, Set<Int>, [Int: Color]) -> Void)? = nil
    
    init(viewModel: FallingNotesViewModel, onActiveKeysChanged: ((Set<Int>, Set<Int>, Set<Int>, [Int: Color]) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onActiveKeysChanged = onActiveKeysChanged
    }
    
    init(
        notes: [FallingNote],
        tempo: Int,
        isPlaying: Bool,
        startKey: Int = 48,
        keyCount: Int = 36,
        onActiveKeysChanged: ((Set<Int>, Set<Int>, Set<Int>, [Int: Color]) -> Void)? = nil
    ) {
        let vm = FallingNotesViewModel()
        vm.notes = notes
        vm.tempo = Double(tempo)
        vm.isPlaying = isPlaying
        vm.keyboardRangeStart = startKey
        vm.keyboardRangeEnd = startKey + keyCount
        self.viewModel = vm
        self.onActiveKeysChanged = onActiveKeysChanged
    }
    
    @State private var lastUpdate: Date = .now
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                drawKeyTracks(context: context, size: size)
                drawBeatGrid(context: context, size: size)
                drawHitZoneBar(context: context, size: size)
                drawNotes(context: context, size: size)
                drawImpactSparks(context: context, size: size)
                drawHitLine(context: context, size: size)
            }
            .onChange(of: timeline.date) { _, newDate in
                let delta = newDate.timeIntervalSince(lastUpdate)
                lastUpdate = newDate
                viewModel.advance(by: delta)
                onActiveKeysChanged?(
                    viewModel.activeHitMidiNotes,
                    viewModel.activeBassHitNotes,
                    viewModel.activeTrebleHitNotes,
                    viewModel.activeHitKeyColors
                )
            }
        }
        .background(FallingNotesViewModel.backgroundDark)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Drawing Subroutines
    
    /// Draws faint vertical tracks corresponding to key lanes.
    private func drawKeyTracks(context: GraphicsContext, size: CGSize) {
        let whiteKeyCount = (viewModel.keyboardRangeStart...viewModel.keyboardRangeEnd)
            .filter { !isBlackKey($0) }
            .count
        let whiteKeyWidth = size.width / CGFloat(max(whiteKeyCount, 1))
        
        // Draw track dividers
        for midiNote in viewModel.keyboardRangeStart...viewModel.keyboardRangeEnd {
            let x = xPosition(for: midiNote, size: size, whiteKeyWidth: whiteKeyWidth)
            let isBlack = isBlackKey(midiNote)
            
            var trackPath = Path()
            trackPath.move(to: CGPoint(x: x, y: 0))
            trackPath.addLine(to: CGPoint(x: x, y: size.height))
            
            let trackColor: Color = isBlack ? .black.opacity(0.18) : .white.opacity(0.02)
            context.stroke(
                trackPath,
                with: .color(trackColor),
                lineWidth: isBlack ? whiteKeyWidth * 0.6 : whiteKeyWidth
            )
        }
    }
    
    /// Draws horizontal measure divider lines with measure number labels.
    private func drawBeatGrid(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.88
        let pixelsPerBeat = hitLineY / viewModel.visibleBeats
        
        let startBeat = Int(floor(viewModel.currentBeat))
        let endBeat = Int(ceil(viewModel.currentBeat + viewModel.visibleBeats))
        
        for beat in startBeat...endBeat {
            let relativeBeat = Double(beat) - viewModel.currentBeat
            let y = hitLineY - (relativeBeat * pixelsPerBeat)
            
            guard y >= 0 && y <= size.height else { continue }
            
            let isMeasureLine = beat % viewModel.beatsPerMeasure == 0
            
            if isMeasureLine {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.28)),
                    lineWidth: 1.2
                )
                
                // Measure number text on left margin matching reference screenshot
                if beat >= 0 {
                    let measureNumber = (beat / viewModel.beatsPerMeasure) + 1
                    let text = Text("\(measureNumber)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    context.draw(
                        context.resolve(text),
                        at: CGPoint(x: 18, y: y - 10)
                    )
                }
            } else {
                // Subtle beat subdivision line
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.06)),
                    lineWidth: 0.5
                )
            }
        }
    }
    
    /// Translucent dark bar across the bottom hit zone.
    private func drawHitZoneBar(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.88
        let hitBarRect = CGRect(x: 0, y: hitLineY, width: size.width, height: size.height - hitLineY)
        context.fill(Path(hitBarRect), with: .color(.black.opacity(0.35)))
    }
    
    /// Draws the crisp impact line at the bottom.
    private func drawHitLine(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.88
        
        var linePath = Path()
        linePath.move(to: CGPoint(x: 0, y: hitLineY))
        linePath.addLine(to: CGPoint(x: size.width, y: hitLineY))
        
        context.stroke(
            linePath,
            with: .color(.white.opacity(0.35)),
            lineWidth: 1.5
        )
    }
    
    /// Draws all visible falling note rectangles with vibrant neon colors.
    private func drawNotes(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.88
        let pixelsPerBeat = hitLineY / viewModel.visibleBeats
        
        let whiteKeyCount = (viewModel.keyboardRangeStart...viewModel.keyboardRangeEnd)
            .filter { !isBlackKey($0) }
            .count
        let whiteKeyWidth = size.width / CGFloat(max(whiteKeyCount, 1))
        
        for note in viewModel.visibleNotes {
            let x = xPosition(for: note.midiNote, size: size, whiteKeyWidth: whiteKeyWidth)
            let isBlack = isBlackKey(note.midiNote)
            let noteWidth = isBlack ? whiteKeyWidth * 0.58 : whiteKeyWidth - 2.5
            
            let relativeBeat = note.startBeat - viewModel.currentBeat
            let noteTopY = hitLineY - ((relativeBeat + note.durationBeats) * pixelsPerBeat)
            let noteBottomY = hitLineY - (relativeBeat * pixelsPerBeat)
            let noteHeight = max(noteBottomY - noteTopY, 6)
            
            let rect = CGRect(
                x: x - noteWidth / 2,
                y: noteTopY,
                width: noteWidth,
                height: noteHeight
            )
            
            let roundedRect = RoundedRectangle(cornerRadius: 3.5).path(in: rect)
            let color = noteColor(for: note)
            
            // Note body fill with slight 3D gradient
            context.fill(
                roundedRect,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.95), color, color.opacity(0.85)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            
            // Crisp border
            context.stroke(
                roundedRect,
                with: .color(.white.opacity(0.4)),
                lineWidth: 0.75
            )
        }
    }
    
    /// Draws glowing impact flares and spark bursts where notes hit the piano keys.
    private func drawImpactSparks(context: GraphicsContext, size: CGSize) {
        let hitLineY = size.height * 0.88
        let whiteKeyCount = (viewModel.keyboardRangeStart...viewModel.keyboardRangeEnd)
            .filter { !isBlackKey($0) }
            .count
        let whiteKeyWidth = size.width / CGFloat(max(whiteKeyCount, 1))
        
        for note in viewModel.visibleNotes {
            let relativeBeat = note.startBeat - viewModel.currentBeat
            let noteEndBeat = note.startBeat + note.durationBeats - viewModel.currentBeat
            
            // Check if note is currently crossing the hit line
            if relativeBeat <= 0.05 && noteEndBeat >= -0.05 {
                let x = xPosition(for: note.midiNote, size: size, whiteKeyWidth: whiteKeyWidth)
                let noteColor = Color.colorForBeat(note.startBeat, beatsPerMeasure: viewModel.beatsPerMeasure)
                
                // 1. Soft wide outer glow
                let outerGlow = Path(ellipseIn: CGRect(x: x - 18, y: hitLineY - 12, width: 36, height: 24))
                context.fill(outerGlow, with: .color(noteColor.opacity(0.4)))
                
                // 2. Bright white-hot core
                let coreFlare = Path(ellipseIn: CGRect(x: x - 10, y: hitLineY - 7, width: 20, height: 14))
                context.fill(coreFlare, with: .color(.white.opacity(0.95)))
                
                // 3. Upward radiating spark particles
                let sparkOffsets: [(CGFloat, CGFloat, CGFloat)] = [
                    (-5, -16, 2.0),
                    (4, -22, 2.5),
                    (-10, -28, 1.8),
                    (8, -32, 2.2),
                    (-2, -38, 2.6),
                    (12, -18, 1.6),
                    (-7, -44, 2.0)
                ]
                
                for (dx, dy, radius) in sparkOffsets {
                    let sparkRect = CGRect(x: x + dx, y: hitLineY + dy, width: radius * 2, height: radius * 2)
                    let sparkColor = dy < -30 ? noteColor.opacity(0.7) : Color.white.opacity(0.85)
                    context.fill(Path(ellipseIn: sparkRect), with: .color(sparkColor))
                }
            }
        }
    }
    
    // MARK: - Position Helpers
    
    private func xPosition(for midiNote: Int, size: CGSize, whiteKeyWidth: CGFloat) -> CGFloat {
        let whiteKeysBefore = (viewModel.keyboardRangeStart..<midiNote)
            .filter { !isBlackKey($0) }
            .count
        
        if isBlackKey(midiNote) {
            return CGFloat(whiteKeysBefore) * whiteKeyWidth
        } else {
            return (CGFloat(whiteKeysBefore) + 0.5) * whiteKeyWidth
        }
    }
    
    private func isBlackKey(_ midiNote: Int) -> Bool {
        let blackIndices: Set<Int> = [1, 3, 6, 8, 10]
        return blackIndices.contains(midiNote % 12)
    }
    
    private func noteColor(for note: FallingNote) -> Color {
        switch note.state {
        case .upcoming, .active:
            return Color.colorForBeat(note.startBeat, beatsPerMeasure: viewModel.beatsPerMeasure)
        case .correct:
            return FallingNotesViewModel.neonGreen
        case .incorrect:
            return .red
        case .missed:
            return .red.opacity(0.5)
        case .passed:
            return .gray.opacity(0.3)
        }
    }
}
