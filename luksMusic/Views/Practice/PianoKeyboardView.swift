import SwiftUI

// MARK: - Piano Key Model

/// Represents a single key on the piano keyboard.
struct PianoKey: Identifiable, Equatable {
    let id: Int // MIDI note number
    let noteName: String
    let octave: Int
    let isBlack: Bool
    
    /// Solfège label for the key.
    var solfegeLabel: String {
        switch noteName {
        case "C": return "Do"
        case "D": return "Re"
        case "E": return "Mi"
        case "F": return "Fa"
        case "G": return "Sol"
        case "A": return "La"
        case "B": return "Si"
        default: return noteName
        }
    }
    
    /// Full display name including octave.
    var fullName: String {
        "\(noteName)\(octave)"
    }
}

// MARK: - Key Label Style

/// Controls how note labels are displayed on piano keys.
enum KeyLabelStyle: String, CaseIterable {
    case hidden = "Hidden"
    case letter = "C, D, E"
    case solfege = "Do, Re, Mi"
}

// MARK: - Piano Keyboard View Model

/// View model managing the interactive piano keyboard state.
@MainActor
@Observable
final class PianoKeyboardViewModel {
    /// Colors matching Synthesia screenshot
    static let neonGreen = Color(red: 0.22, green: 0.95, blue: 0.38)
    static let electricCyan = Color(red: 0.0, green: 0.88, blue: 1.0)

    /// All keys in the current keyboard range.
    var keys: [PianoKey] = []
    /// Set of currently pressed MIDI note numbers (by touch).
    var pressedKeys: Set<Int> = []
    /// Set of MIDI note numbers currently active from external MIDI or falling notes hit line.
    var midiActiveKeys: Set<Int> = []
    /// Set of MIDI note numbers that are target notes to press next.
    var targetNoteKeys: Set<Int> = []
    /// Hand mapping for active notes (left hand = bass, right hand = treble).
    var bassActiveKeys: Set<Int> = []
    var trebleActiveKeys: Set<Int> = []
    /// Custom beat colors per note number
    var keyColorsByNote: [Int: Color] = [:]
    /// Set of correctly played MIDI notes (green glow).
    var correctKeys: Set<Int> = []
    /// Set of incorrectly played MIDI notes (red flash).
    var incorrectKeys: Set<Int> = []
    /// Whether sustain pedal is active.
    var isSustainActive: Bool = false
    /// Key label display style.
    var labelStyle: KeyLabelStyle = .letter
    /// Starting MIDI note of the keyboard range.
    var rangeStart: Int = 48 // C3
    /// Ending MIDI note of the keyboard range.
    var rangeEnd: Int = 84 // C6
    
    /// Haptic feedback generator.
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let errorImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    init(rangeStart: Int = 48, rangeEnd: Int = 84) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        buildKeys()
        lightImpact.prepare()
        errorImpact.prepare()
    }
    
    /// Builds the array of keys for the current range.
    func buildKeys() {
        keys = (rangeStart...rangeEnd).compactMap { midi in
            let octave = (midi / 12) - 1
            let noteIndex = midi % 12
            let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
            let blackIndices: Set<Int> = [1, 3, 6, 8, 10]
            return PianoKey(
                id: midi,
                noteName: noteNames[noteIndex],
                octave: octave,
                isBlack: blackIndices.contains(noteIndex)
            )
        }
    }
    
    /// White keys only.
    var whiteKeys: [PianoKey] {
        keys.filter { !$0.isBlack }
    }
    
    /// Black keys only.
    var blackKeys: [PianoKey] {
        keys.filter { $0.isBlack }
    }
    
    /// Called when a key is pressed by touch.
    func keyPressed(_ key: PianoKey) {
        pressedKeys.insert(key.id)
        lightImpact.impactOccurred()
        
        if targetNoteKeys.contains(key.id) {
            correctKeys.insert(key.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.correctKeys.remove(key.id)
            }
        } else if !targetNoteKeys.isEmpty {
            incorrectKeys.insert(key.id)
            errorImpact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.incorrectKeys.remove(key.id)
            }
        }
    }
    
    /// Called when a key is released by touch.
    func keyReleased(_ key: PianoKey) {
        if !isSustainActive {
            pressedKeys.remove(key.id)
        }
    }
    
    /// Returns the visual state color for a given key, exactly matching the Synthesia screenshot.
    func keyColor(for key: PianoKey) -> Color? {
        if correctKeys.contains(key.id) {
            return Self.neonGreen
        }
        if incorrectKeys.contains(key.id) {
            return .red
        }
        
        let isActive = pressedKeys.contains(key.id) || midiActiveKeys.contains(key.id)
        if isActive, let customColor = keyColorsByNote[key.id] {
            return customColor
        }
        let isLeftHand = bassActiveKeys.contains(key.id) || (key.id < 60 && !trebleActiveKeys.contains(key.id))
        
        if isActive {
            return isLeftHand ? Self.neonGreen : Self.electricCyan
        }
        
        if targetNoteKeys.contains(key.id) {
            let guideColor = isLeftHand ? Self.neonGreen : Self.electricCyan
            return key.isBlack ? guideColor.opacity(0.55) : guideColor.opacity(0.35)
        }
        return nil
    }
}

// MARK: - Piano Keyboard View

/// An interactive piano keyboard with realistic proportions, multi-touch support,
/// visual feedback, and configurable note labels.
struct PianoKeyboardView: View {
    @Bindable var viewModel: PianoKeyboardViewModel
    var onKeyPress: ((Int) -> Void)? = nil
    var onKeyRelease: ((Int) -> Void)? = nil
    
    /// Ratio of black key width to white key width.
    private let blackKeyWidthRatio: CGFloat = 0.6
    /// Ratio of black key height to white key height.
    private let blackKeyHeightRatio: CGFloat = 0.62
    
    var body: some View {
        GeometryReader { geometry in
            let whiteKeys = viewModel.whiteKeys
            let whiteKeyCount = CGFloat(whiteKeys.count)
            let whiteKeyWidth = geometry.size.width / max(whiteKeyCount, 1)
            let whiteKeyHeight = geometry.size.height
            let blackKeyWidth = whiteKeyWidth * blackKeyWidthRatio
            let blackKeyHeight = whiteKeyHeight * blackKeyHeightRatio
            
            ZStack(alignment: .topLeading) {
                // White keys layer
                HStack(spacing: 0) {
                    ForEach(whiteKeys) { key in
                        WhiteKeyView(
                            key: key,
                            width: whiteKeyWidth,
                            height: whiteKeyHeight,
                            highlightColor: viewModel.keyColor(for: key),
                            labelStyle: viewModel.labelStyle,
                            isSustainActive: viewModel.isSustainActive,
                            onPress: {
                                viewModel.keyPressed(key)
                                onKeyPress?(key.id)
                            },
                            onRelease: {
                                viewModel.keyReleased(key)
                                onKeyRelease?(key.id)
                            }
                        )
                    }
                }
                
                // Black keys layer
                ForEach(viewModel.blackKeys) { key in
                    let xOffset = blackKeyXOffset(
                        for: key,
                        whiteKeys: whiteKeys,
                        whiteKeyWidth: whiteKeyWidth,
                        blackKeyWidth: blackKeyWidth
                    )
                    
                    BlackKeyView(
                        key: key,
                        width: blackKeyWidth,
                        height: blackKeyHeight,
                        highlightColor: viewModel.keyColor(for: key),
                        labelStyle: viewModel.labelStyle,
                        onPress: {
                            viewModel.keyPressed(key)
                            onKeyPress?(key.id)
                        },
                        onRelease: {
                            viewModel.keyReleased(key)
                            onKeyRelease?(key.id)
                        }
                    )
                    .offset(x: xOffset)
                }
                
                // Sustain pedal indicator
                if viewModel.isSustainActive {
                    sustainIndicator
                        .position(x: geometry.size.width - 40, y: whiteKeyHeight - 20)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    // MARK: - Black Key Positioning
    
    /// Calculates the X offset for a black key relative to its neighboring white keys.
    private func blackKeyXOffset(
        for key: PianoKey,
        whiteKeys: [PianoKey],
        whiteKeyWidth: CGFloat,
        blackKeyWidth: CGFloat
    ) -> CGFloat {
        // Find the white key just before this black key
        guard let whiteIndex = whiteKeys.lastIndex(where: { $0.id < key.id }) else {
            return 0
        }
        // Black key sits at the boundary between two white keys
        let baseX = CGFloat(whiteIndex + 1) * whiteKeyWidth
        return baseX - (blackKeyWidth / 2)
    }
    
    /// Sustain pedal active indicator.
    private var sustainIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "pedal.sustain.fill")
                .font(.caption2)
            Text("SUS")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.indigo)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.indigo.opacity(0.2), in: Capsule())
    }
}

// MARK: - White Key View

/// A single white piano key with touch interaction and visual feedback.
struct WhiteKeyView: View {
    let key: PianoKey
    let width: CGFloat
    let height: CGFloat
    let highlightColor: Color?
    let labelStyle: KeyLabelStyle
    let isSustainActive: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Key shape
            RoundedRectangle(cornerRadius: 3)
                .fill(keyFillGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(
                    color: highlightColor?.opacity(0.6) ?? .clear,
                    radius: highlightColor != nil ? 8 : 0
                )
            
            // Note label
            if labelStyle != .hidden {
                Text(labelStyle == .solfege ? key.solfegeLabel : key.noteName)
                    .font(.system(size: min(width * 0.35, 14), weight: .medium, design: .rounded))
                    .foregroundStyle(highlightColor ?? .gray)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: width, height: height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onRelease()
                }
        )
    }
    
    private var keyFillGradient: LinearGradient {
        if let color = highlightColor {
            return LinearGradient(
                colors: [color, color.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(white: 0.98),
                Color(white: 0.93),
                Color(white: 0.88)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Black Key View

/// A single black piano key with touch interaction and visual feedback.
struct BlackKeyView: View {
    let key: PianoKey
    let width: CGFloat
    let height: CGFloat
    let highlightColor: Color?
    let labelStyle: KeyLabelStyle
    let onPress: () -> Void
    let onRelease: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(keyFillGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.black.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(
                    color: highlightColor?.opacity(0.8) ?? .black.opacity(0.4),
                    radius: highlightColor != nil ? 10 : 3,
                    y: highlightColor != nil ? 0 : 2
                )
            
            if labelStyle != .hidden {
                Text(labelStyle == .solfege ? key.solfegeLabel : key.noteName)
                    .font(.system(size: min(width * 0.3, 10), weight: .semibold, design: .rounded))
                    .foregroundStyle(highlightColor ?? .gray)
                    .padding(.bottom, 6)
            }
        }
        .frame(width: width, height: height)
        .zIndex(1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onRelease()
                }
        )
    }
    
    private var keyFillGradient: LinearGradient {
        if let color = highlightColor {
            return LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(white: 0.22),
                Color(white: 0.12),
                Color(white: 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview("Piano Keyboard - 3 Octaves") {
    let vm = PianoKeyboardViewModel(rangeStart: 48, rangeEnd: 84)
    
    VStack {
        Spacer()
        PianoKeyboardView(viewModel: vm)
            .frame(height: 200)
            .padding(.horizontal, 4)
    }
    .background(Color(white: 0.08))
    .onAppear {
        vm.targetNoteKeys = [60, 64, 67] // C Major chord targets
        vm.pressedKeys = [60] // C pressed
        vm.correctKeys = [60]
    }
}

#Preview("Piano Keyboard - Labels") {
    let vm = PianoKeyboardViewModel(rangeStart: 60, rangeEnd: 84)
    
    VStack {
        Picker("Labels", selection: Binding(get: { vm.labelStyle }, set: { vm.labelStyle = $0 })) {
            ForEach(KeyLabelStyle.allCases, id: \.self) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        
        PianoKeyboardView(viewModel: vm)
            .frame(height: 180)
            .padding(.horizontal, 4)
    }
    .background(Color(white: 0.08))
}
