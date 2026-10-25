import SwiftUI

// MARK: - Playback Controls View Model

/// View model for playback controls state.
@Observable
final class PlaybackControlsViewModel {
    /// Whether audio is currently playing.
    var isPlaying: Bool = false
    /// Current tempo in BPM.
    var tempo: Double = 120.0
    /// Whether loop mode is active.
    var isLooping: Bool = false
    /// Loop start measure (1-indexed).
    var loopStartMeasure: Int = 1
    /// Loop end measure (1-indexed).
    var loopEndMeasure: Int = 4
    /// Total number of measures in the piece.
    var totalMeasures: Int = 32
    /// Whether metronome click is enabled.
    var isMetronomeEnabled: Bool = true
    /// Master volume (0.0 - 1.0).
    var volume: Double = 0.8
    /// Current measure number.
    var currentMeasure: Int = 1
    /// Whether the controls are expanded (showing all options).
    var isExpanded: Bool = false
    
    // MARK: - Actions
    
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onStop: (() -> Void)?
    var onSkipForward: (() -> Void)?
    var onSkipBackward: (() -> Void)?
    
    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            onPlay?()
        } else {
            onPause?()
        }
    }
    
    func stop() {
        isPlaying = false
        currentMeasure = 1
        onStop?()
    }
    
    func skipForward() {
        currentMeasure = min(currentMeasure + 1, totalMeasures)
        onSkipForward?()
    }
    
    func skipBackward() {
        currentMeasure = max(currentMeasure - 1, 1)
        onSkipBackward?()
    }
}

// MARK: - Playback Controls View

/// Reusable playback controls with play/pause, stop, skip, tempo, loop, and metronome.
struct PlaybackControlsView: View {
    @Bindable var viewModel: PlaybackControlsViewModel
    
    init(viewModel: PlaybackControlsViewModel) {
        self.viewModel = viewModel
    }
    
    init(
        isPlaying: Bool,
        tempo: Int,
        currentMeasure: Int,
        totalMeasures: Int,
        onPlayPause: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onTempoChange: @escaping (Int) -> Void
    ) {
        let vm = PlaybackControlsViewModel()
        vm.isPlaying = isPlaying
        vm.tempo = Double(tempo)
        vm.currentMeasure = currentMeasure
        vm.totalMeasures = totalMeasures
        vm.onPlay = onPlayPause
        vm.onPause = onPlayPause
        vm.onStop = onStop
        vm.onSkipBackward = onPrevious
        vm.onSkipForward = onNext
        self.viewModel = vm
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary transport controls
            transportControls
            
            if viewModel.isExpanded {
                Divider()
                    .overlay(Color.white.opacity(0.1))
                
                // Tempo slider
                tempoControl
                
                // Volume slider
                volumeControl
                
                // Loop controls
                loopControls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Transport Controls
    
    private var transportControls: some View {
        HStack(spacing: 20) {
            // Expand/collapse button
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.isExpanded.toggle()
                }
            } label: {
                Image(systemName: viewModel.isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            
            Spacer()
            
            // Metronome toggle
            Button {
                viewModel.isMetronomeEnabled.toggle()
            } label: {
                Image(systemName: viewModel.isMetronomeEnabled ? "metronome.fill" : "metronome")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.isMetronomeEnabled ? .indigo : .secondary)
                    .frame(width: 36, height: 36)
            }
            
            // Skip backward
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            
            // Play/Pause (large)
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.indigo, in: Circle())
                    .shadow(color: .indigo.opacity(0.4), radius: 8)
            }
            
            // Skip forward
            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            
            // Stop
            Button {
                viewModel.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            
            Spacer()
            
            // Loop toggle
            Button {
                viewModel.isLooping.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.isLooping ? .indigo : .secondary)
                    .frame(width: 32, height: 32)
            }
        }
    }
    
    // MARK: - Tempo Control
    
    private var tempoControl: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "metronome")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tempo")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(viewModel.tempo)) BPM")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.indigo)
            }
            
            Slider(value: $viewModel.tempo, in: 40...240, step: 1)
                .tint(.indigo)
        }
    }
    
    // MARK: - Volume Control
    
    private var volumeControl: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Slider(value: $viewModel.volume, in: 0...1)
                .tint(.indigo)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Loop Controls
    
    private var loopControls: some View {
        HStack(spacing: 16) {
            Image(systemName: "repeat")
                .font(.caption)
                .foregroundStyle(viewModel.isLooping ? .indigo : .secondary)
            
            Text("Loop")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("M\(viewModel.loopStartMeasure)")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)
                
                Stepper("", value: $viewModel.loopStartMeasure, in: 1...viewModel.loopEndMeasure)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            
            Text("→")
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Text("M\(viewModel.loopEndMeasure)")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.white)
                
                Stepper("", value: $viewModel.loopEndMeasure, in: viewModel.loopStartMeasure...viewModel.totalMeasures)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
        }
        .opacity(viewModel.isLooping ? 1.0 : 0.4)
        .disabled(!viewModel.isLooping)
    }
}

// MARK: - Compact Playback Controls

/// A compact, single-row version of playback controls for use in tight layouts.
struct CompactPlaybackControlsView: View {
    @Bindable var viewModel: PlaybackControlsViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Button { viewModel.skipBackward() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
            
            Button { viewModel.togglePlayPause() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.indigo, in: Circle())
            }
            
            Button { viewModel.skipForward() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
            
            Divider()
                .frame(height: 20)
                .overlay(Color.white.opacity(0.1))
            
            Text("\(Int(viewModel.tempo))")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.indigo)
            + Text(" BPM")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button { viewModel.isMetronomeEnabled.toggle() } label: {
                Image(systemName: viewModel.isMetronomeEnabled ? "metronome.fill" : "metronome")
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.isMetronomeEnabled ? .indigo : .secondary)
            }
            
            Button { viewModel.isLooping.toggle() } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.isLooping ? .indigo : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Previews

#Preview("Playback Controls - Expanded") {
    let vm = PlaybackControlsViewModel()
    
    VStack {
        Spacer()
        PlaybackControlsView(viewModel: vm)
            .padding()
    }
    .background(Color(white: 0.08))
    .onAppear {
        vm.isExpanded = true
        vm.isLooping = true
    }
}

#Preview("Compact Controls") {
    let vm = PlaybackControlsViewModel()
    
    VStack {
        Spacer()
        CompactPlaybackControlsView(viewModel: vm)
            .padding()
    }
    .background(Color(white: 0.08))
}
