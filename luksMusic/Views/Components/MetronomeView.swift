import SwiftUI

// MARK: - Metronome View Model

/// View model managing metronome state and timing.
@Observable
final class MetronomeViewModel {
    /// Current tempo in BPM.
    var tempo: Double = 120.0
    /// Time signature numerator (beats per measure).
    var beatsPerMeasure: Int = 4
    /// Time signature denominator (beat unit value).
    var beatUnit: Int = 4
    /// Current beat number (1-indexed within the measure).
    var currentBeat: Int = 1
    /// Whether the metronome is actively ticking.
    var isActive: Bool = false
    /// Whether the beat flash is currently visible.
    var isFlashing: Bool = false
    
    /// Timestamps for tap tempo calculation.
    var tapTimestamps: [Date] = []
    
    /// Formatted time signature string.
    var timeSignature: String {
        "\(beatsPerMeasure)/\(beatUnit)"
    }
    
    /// Increments tempo by a given amount, clamped.
    func adjustTempo(by amount: Double) {
        tempo = min(max(tempo + amount, 40), 240)
    }
    
    /// Records a tap for tap-tempo and calculates BPM.
    func recordTap() {
        let now = Date()
        tapTimestamps.append(now)
        
        // Keep only last 6 taps
        if tapTimestamps.count > 6 {
            tapTimestamps.removeFirst()
        }
        
        // Need at least 2 taps to calculate tempo
        guard tapTimestamps.count >= 2 else { return }
        
        // Discard taps older than 3 seconds from the latest
        tapTimestamps = tapTimestamps.filter {
            now.timeIntervalSince($0) < 3.0
        }
        
        guard tapTimestamps.count >= 2 else { return }
        
        // Calculate average interval
        var totalInterval: TimeInterval = 0
        for i in 1..<tapTimestamps.count {
            totalInterval += tapTimestamps[i].timeIntervalSince(tapTimestamps[i - 1])
        }
        let avgInterval = totalInterval / Double(tapTimestamps.count - 1)
        
        // Convert to BPM
        let calculatedBPM = 60.0 / avgInterval
        tempo = min(max(calculatedBPM.rounded(), 40), 240)
    }
    
    /// Triggers the beat, advancing the current beat counter.
    func triggerBeat() {
        isFlashing = true
        currentBeat = (currentBeat % beatsPerMeasure) + 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isFlashing = false
        }
    }
}

// MARK: - Metronome View

/// Visual metronome component with animated beat indicators, tempo adjustment, and tap tempo.
struct MetronomeView: View {
    @Bindable var viewModel: MetronomeViewModel
    
    /// Timer for driving beats.
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            // Time signature
            timeSignatureDisplay
            
            // Beat dots
            beatIndicators
            
            // Pendulum animation
            pendulumView
            
            // Tempo display with +/- buttons
            tempoAdjuster
            
            // Tap tempo button
            tapTempoButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onChange(of: viewModel.isActive) { _, isActive in
            if isActive {
                startTimer()
            } else {
                stopTimer()
            }
        }
        .onChange(of: viewModel.tempo) { _, _ in
            if viewModel.isActive {
                restartTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Time Signature
    
    private var timeSignatureDisplay: some View {
        Text(viewModel.timeSignature)
            .font(.system(size: 20, weight: .bold, design: .serif))
            .foregroundStyle(.white.opacity(0.7))
    }
    
    // MARK: - Beat Indicators
    
    private var beatIndicators: some View {
        HStack(spacing: 10) {
            ForEach(1...viewModel.beatsPerMeasure, id: \.self) { beat in
                Circle()
                    .fill(beatDotColor(for: beat))
                    .frame(width: beat == 1 ? 18 : 14, height: beat == 1 ? 18 : 14)
                    .shadow(
                        color: viewModel.currentBeat == beat ? .indigo.opacity(0.7) : .clear,
                        radius: viewModel.currentBeat == beat ? 8 : 0
                    )
                    .scaleEffect(viewModel.currentBeat == beat && viewModel.isFlashing ? 1.3 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: viewModel.currentBeat)
                    .animation(.easeOut(duration: 0.1), value: viewModel.isFlashing)
            }
        }
    }
    
    /// Returns the color for a beat dot.
    private func beatDotColor(for beat: Int) -> Color {
        if viewModel.currentBeat == beat {
            return beat == 1 ? .orange : .indigo
        }
        return .white.opacity(0.15)
    }
    
    // MARK: - Pendulum
    
    private var pendulumView: some View {
        ZStack {
            // Track arc
            Arc(startAngle: .degrees(210), endAngle: .degrees(330), clockwise: false)
                .stroke(.white.opacity(0.08), lineWidth: 2)
                .frame(width: 100, height: 50)
            
            // Pendulum arm + bob
            PendulumArmView(
                isActive: viewModel.isActive,
                tempo: viewModel.tempo,
                isFlashing: viewModel.isFlashing,
                isAccent: viewModel.currentBeat == 1
            )
            .frame(width: 100, height: 60)
        }
        .frame(height: 60)
    }
    
    // MARK: - Tempo Adjuster
    
    private var tempoAdjuster: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.adjustTempo(by: -5)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonRepeatBehavior(.enabled)
            
            VStack(spacing: 2) {
                Text("\(Int(viewModel.tempo))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: viewModel.tempo)
                
                Text("BPM")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 80)
            
            Button {
                viewModel.adjustTempo(by: 5)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonRepeatBehavior(.enabled)
        }
    }
    
    // MARK: - Tap Tempo
    
    private var tapTempoButton: some View {
        Button {
            viewModel.recordTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 14))
                Text("Tap Tempo")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.indigo)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.indigo.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(.indigo.opacity(0.3), lineWidth: 1))
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        let interval = 60.0 / viewModel.tempo
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            viewModel.triggerBeat()
        }
        // Trigger the first beat immediately
        viewModel.triggerBeat()
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartTimer() {
        stopTimer()
        startTimer()
    }
}

// MARK: - Pendulum Arm View

/// Animated pendulum arm that swings with the beat.
struct PendulumArmView: View {
    let isActive: Bool
    let tempo: Double
    let isFlashing: Bool
    let isAccent: Bool
    
    @State private var swingRight: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let bottomY = geometry.size.height
            let armLength: CGFloat = geometry.size.height * 0.85
            let angle: Double = swingRight ? 30 : -30
            
            ZStack {
                // Arm
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: bottomY))
                    let endX = centerX + armLength * sin(angle * .pi / 180)
                    let endY = bottomY - armLength * cos(angle * .pi / 180)
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(.white.opacity(0.5), lineWidth: 2)
                .animation(
                    isActive
                        ? .easeInOut(duration: 60.0 / tempo)
                        : .easeOut(duration: 0.3),
                    value: swingRight
                )
                
                // Bob
                Circle()
                    .fill(isAccent && isFlashing ? .orange : .indigo)
                    .frame(width: 12, height: 12)
                    .shadow(color: .indigo.opacity(0.5), radius: 4)
                    .position(
                        x: centerX + armLength * sin(angle * .pi / 180),
                        y: bottomY - armLength * cos(angle * .pi / 180)
                    )
                    .animation(
                        isActive
                            ? .easeInOut(duration: 60.0 / tempo)
                            : .easeOut(duration: 0.3),
                        value: swingRight
                    )
                
                // Pivot point
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .position(x: centerX, y: bottomY)
            }
        }
        .onChange(of: isFlashing) { _, flashing in
            if flashing && isActive {
                swingRight.toggle()
            }
        }
        .onChange(of: isActive) { _, active in
            if !active {
                swingRight = false
            }
        }
    }
}

// MARK: - Arc Shape

/// A simple arc shape for the pendulum track.
struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        return path
    }
}

// MARK: - Compact Metronome View

/// A compact, inline metronome indicator for use in practice HUDs.
struct CompactMetronomeView: View {
    @Bindable var viewModel: MetronomeViewModel
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...viewModel.beatsPerMeasure, id: \.self) { beat in
                RoundedRectangle(cornerRadius: 2)
                    .fill(beatColor(for: beat))
                    .frame(width: beat == 1 ? 10 : 8, height: beat == 1 ? 14 : 10)
                    .scaleEffect(
                        viewModel.currentBeat == beat && viewModel.isFlashing ? 1.3 : 1.0
                    )
                    .animation(.easeOut(duration: 0.1), value: viewModel.isFlashing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.06), in: Capsule())
    }
    
    private func beatColor(for beat: Int) -> Color {
        if viewModel.currentBeat == beat {
            return beat == 1 ? .orange : .indigo
        }
        return .white.opacity(0.15)
    }
}

// MARK: - Previews

#Preview("Metronome") {
    MetronomeView(viewModel: MetronomeViewModel())
        .frame(width: 240)
        .padding()
        .background(Color(white: 0.08))
}

#Preview("Metronome - Active") {
    let vm = MetronomeViewModel()
    
    MetronomeView(viewModel: vm)
        .frame(width: 240)
        .padding()
        .background(Color(white: 0.08))
        .onAppear {
            vm.isActive = true
        }
}

#Preview("Compact Metronome") {
    CompactMetronomeView(viewModel: MetronomeViewModel())
        .padding()
        .background(Color(white: 0.08))
}
