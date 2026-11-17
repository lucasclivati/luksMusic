// TunerView.swift
// luksMusic
//
// The tuner tab: listens to the microphone and shows the nearest note, its octave and how many cents off it is on a
// needle, green within ±5 cents. Guitar mode tunes the six strings (chosen by ear or by hand) and says whether to
// tighten or loosen; piano mode names any key from A0 to C8. The reference A and the mode are remembered.

import SwiftUI

struct TunerView: View {
    @AppStorage("tuner.mode") private var modeRaw = TunerMode.guitar.rawValue
    @AppStorage("tuner.a4") private var a4 = Tuning.defaultA4

    @State private var mic = MicrophonePitchService.shared
    /// The string picked by hand; nil follows the string closest to what is heard
    @State private var manualString: Int?
    /// Screenshots run on a simulator with no instrument: a fixed pitch per mode stands in for the microphone
    @State private var isDemo = false
    /// Whether this screen turned the microphone on, and so turns it off when it goes away
    @State private var startedListening = false
    /// The last note read, which the reference button plays in piano mode
    @State private var lastNote: Int?

    private var mode: TunerMode { TunerMode(rawValue: modeRaw) ?? .guitar }

    private var heardFrequency: Double? {
        guard isDemo else { return mic.tunerFrequency }
        // A2 a little flat on the guitar, middle C in tune on the piano (at A4 = 440)
        return mode == .guitar ? 108.0 : 262.0
    }

    /// The string tuned now: the one picked, or the closest to the pitch heard
    private var activeString: Int? {
        if let manualString { return manualString }
        return heardFrequency.flatMap { Tuning.nearestGuitarString(to: $0, a4: a4) }
    }

    private var reading: TuningReading? {
        guard let frequency = heardFrequency else { return nil }
        switch mode {
        case .guitar:
            return activeString.flatMap { Tuning.reading(for: frequency, string: $0, a4: a4) }
        case .piano:
            return Tuning.nearestNote(to: frequency, a4: a4)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                modePicker
                noteDisplay
                TunerGauge(cents: reading?.cents)
                    .frame(height: 170)
                    .padding(.horizontal, 8)
                status
                frequencies
                if mode == .guitar {
                    stringPicker
                }
                referenceControls
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PlayerTheme.background.ignoresSafeArea())
        .toolbarBackground(PlayerTheme.panel, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
        .onChange(of: modeRaw) {
            mic.setTuner(isDemo ? nil : TunerPitchTracker.Settings(mode: mode))
        }
        .onChange(of: reading?.midi) { _, midi in
            if let midi { lastNote = midi }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Afinador")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(PlayerTheme.text)
            Spacer()
            LevelMeter(level: isDemo ? 0.6 : Double(mic.inputLevel), isListening: isDemo || mic.isListening)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(TunerMode.allCases) { option in
                Button {
                    modeRaw = option.rawValue
                } label: {
                    Label(option.title, systemImage: option == .guitar ? "guitars" : "pianokeys")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(mode == option ? PlayerTheme.text : PlayerTheme.muted)
                        .background(mode == option ? PlayerTheme.deepBlue : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tunerMode.\(option.rawValue)")
                .accessibilityAddTraits(mode == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(PlayerTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PlayerTheme.border, lineWidth: 1))
    }

    // MARK: - Note

    private var noteColor: Color {
        guard let reading else { return PlayerTheme.muted }
        return reading.isInTune ? PlayerTheme.green : PlayerTheme.text
    }

    private var noteDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let reading {
                Text(verbatim: Tuning.noteName(reading.midi))
                    .font(.system(size: 92, weight: .bold, design: .rounded))
                Text(verbatim: "\(Tuning.octave(reading.midi))")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(PlayerTheme.muted)
            } else {
                Text(verbatim: "--")
                    .font(.system(size: 92, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(noteColor)
        .frame(height: 110)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tunerNote")
    }

    // MARK: - Status

    private var statusColor: Color {
        guard let reading else { return PlayerTheme.muted }
        if reading.isInTune { return PlayerTheme.green }
        return abs(reading.cents) <= 20 ? PlayerTheme.beat : PlayerTheme.downbeat
    }

    private var statusText: String {
        guard let reading else {
            if let error = mic.errorMessage, !isDemo { return error }
            return mode == .guitar ? String(localized: "Toque uma corda") : String(localized: "Toque uma nota")
        }
        if reading.isInTune { return String(localized: "Afinado") }
        switch mode {
        case .guitar:
            return reading.isFlat ? String(localized: "Aperte a corda") : String(localized: "Afrouxe a corda")
        case .piano:
            return reading.isFlat ? String(localized: "Abaixo da nota") : String(localized: "Acima da nota")
        }
    }

    private var statusIcon: String? {
        guard let reading else { return nil }
        if reading.isInTune { return "checkmark.circle.fill" }
        return reading.isFlat ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var centsText: String {
        guard let reading else { return " " }
        let cents = Int(reading.cents.rounded())
        return cents > 0 ? "+\(cents) cents" : "\(cents) cents"
    }

    private var status: some View {
        VStack(spacing: 6) {
            Text(verbatim: centsText)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(statusColor)
            HStack(spacing: 6) {
                if let statusIcon {
                    Image(systemName: statusIcon)
                }
                Text(statusText)
                    .multilineTextAlignment(.center)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(reading == nil ? PlayerTheme.muted : statusColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tunerStatus")
    }

    private var frequencies: some View {
        HStack(spacing: 12) {
            frequencyCard(title: String(localized: "Ouvido"), value: reading?.frequency ?? heardFrequency)
            frequencyCard(title: String(localized: "Alvo"), value: reading?.targetFrequency)
        }
    }

    private func frequencyCard(title: String, value: Double?) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PlayerTheme.muted)
            Text(verbatim: value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) Hz" } ?? "-- Hz")
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(PlayerTheme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PlayerTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Guitar strings

    private var stringPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Corda")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PlayerTheme.muted)
            HStack(spacing: 6) {
                Button {
                    manualString = nil
                } label: {
                    Text("Auto")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(manualString == nil ? PlayerTheme.text : PlayerTheme.muted)
                        .background(manualString == nil ? PlayerTheme.deepBlue : PlayerTheme.raised,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tunerString.auto")
                .accessibilityAddTraits(manualString == nil ? .isSelected : [])

                ForEach(Tuning.guitarStrings.indices, id: \.self) { index in
                    stringButton(index)
                }
            }
        }
    }

    private func stringButton(_ index: Int) -> some View {
        let midi = Tuning.guitarStrings[index]
        let isActive = activeString == index
        let isPicked = manualString == index
        let isTuned = isActive && reading?.isInTune == true
        return Button {
            manualString = isPicked ? nil : index
        } label: {
            VStack(spacing: 0) {
                Text(verbatim: Tuning.noteName(midi))
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: "\(Tuning.octave(midi))")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(isActive ? PlayerTheme.text : PlayerTheme.muted)
            .background(isPicked ? PlayerTheme.deepBlue : PlayerTheme.raised,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isTuned ? PlayerTheme.green : (isActive ? PlayerTheme.cyan : Color.clear), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tunerString.\(index)")
        .accessibilityLabel(Text(verbatim: "\(Tuning.noteName(midi))\(Tuning.octave(midi))"))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    // MARK: - Reference A and tone

    private var referenceControls: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lá de referência")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PlayerTheme.text)
                    Text(verbatim: "\(Tuning.noteName(69))4")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PlayerTheme.muted)
                }
                Spacer()
                roundButton("minus", label: String(localized: "Diminuir o lá de referência"), identifier: "tunerA4Down") {
                    a4 = Tuning.clampedA4(a4 - 1)
                }
                .disabled(a4 <= Tuning.a4Range.lowerBound)
                Button {
                    a4 = Tuning.defaultA4
                } label: {
                    Text(verbatim: "\(Int(a4.rounded())) Hz")
                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(a4 == Tuning.defaultA4 ? PlayerTheme.text : PlayerTheme.cyan)
                        .frame(minWidth: 76)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tunerA4Value")
                .accessibilityHint(Text("Voltar para 440 Hz"))
                roundButton("plus", label: String(localized: "Aumentar o lá de referência"), identifier: "tunerA4Up") {
                    a4 = Tuning.clampedA4(a4 + 1)
                }
                .disabled(a4 >= Tuning.a4Range.upperBound)
            }
            .padding(14)
            .background(PlayerTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: playReference) {
                Label("Tocar referência", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(PlayerTheme.text)
                    .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tunerReferenceButton")
        }
    }

    private func roundButton(_ symbol: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PlayerTheme.text)
                .frame(width: 36, height: 36)
                .background(PlayerTheme.raised, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }

    /// Plays the string being tuned, or the last note read (A4 before any), at the chosen reference A. The
    /// microphone is deaf meanwhile, so the tuner doesn't read its own tone.
    private func playReference() {
        let midi: Int
        if mode == .guitar {
            midi = Tuning.guitarStrings[activeString ?? 0]
        } else {
            midi = lastNote ?? 69
        }
        let duration = 2.0
        mic.ignoreInput(for: duration + 0.6)
        AudioEngineService.shared.ensureRunning()
        AudioEngineService.shared.playReferenceTone(midiNote: UInt8(midi), a4: a4, duration: duration)
    }

    // MARK: - Microphone

    private func startListening() {
        if UserDefaults.standard.bool(forKey: "tuner.demo") {
            isDemo = true
            return
        }
        mic.setTuner(TunerPitchTracker.Settings(mode: mode))
        guard !mic.isListening else { return }
        startedListening = true
        Task {
            try? await mic.startListening()
        }
    }

    private func stopListening() {
        guard !isDemo else { return }
        mic.setTuner(nil)
        if startedListening {
            startedListening = false
            mic.stopListening()
        }
    }
}

// MARK: - Gauge

/// A needle over an arc from -50 to +50 cents, with the green "in tune" band of ±5 cents in the middle.
struct TunerGauge: View {
    /// Nil rests the needle in the middle, dimmed
    let cents: Double?

    private static let range = 50.0
    /// The arc's half-width, in degrees from the vertical
    private static let sweep = 62.0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let pivot = CGPoint(x: size.width / 2, y: size.height - 8)
            let radius = min(size.width / 2 - 12, size.height - 24)
            ZStack {
                arc(from: -Self.range, to: Self.range, pivot: pivot, radius: radius)
                    .stroke(PlayerTheme.raised, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                arc(from: -20, to: 20, pivot: pivot, radius: radius)
                    .stroke(PlayerTheme.beat.opacity(0.25), style: StrokeStyle(lineWidth: 16))
                arc(from: -TuningReading.inTuneCents, to: TuningReading.inTuneCents, pivot: pivot, radius: radius)
                    .stroke(PlayerTheme.green, style: StrokeStyle(lineWidth: 16))
                ticks(pivot: pivot, radius: radius)
                    .stroke(PlayerTheme.muted.opacity(0.7), lineWidth: 1.5)
                ForEach([-50, -25, 0, 25, 50], id: \.self) { value in
                    Text(verbatim: value > 0 ? "+\(value)" : "\(value)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PlayerTheme.muted)
                        .position(point(cents: Double(value), pivot: pivot, distance: radius - 30))
                }
                needle(pivot: pivot, radius: radius)
                Circle()
                    .fill(needleColor)
                    .frame(width: 16, height: 16)
                    .position(pivot)
            }
        }
        .accessibilityElement()
        .accessibilityIdentifier("tunerGauge")
        .accessibilityValue(Text(verbatim: cents.map { "\(Int($0.rounded())) cents" } ?? "--"))
    }

    private var needleColor: Color {
        guard let cents else { return PlayerTheme.border }
        if abs(cents) <= TuningReading.inTuneCents { return PlayerTheme.green }
        return abs(cents) <= 20 ? PlayerTheme.beat : PlayerTheme.downbeat
    }

    private func needle(pivot: CGPoint, radius: CGFloat) -> some View {
        let shown = max(-Self.range, min(Self.range, cents ?? 0))
        return Capsule()
            .fill(needleColor)
            .frame(width: 4, height: radius + 6)
            .offset(y: -(radius + 6) / 2)
            .rotationEffect(.degrees(shown / Self.range * Self.sweep), anchor: .center)
            .position(pivot)
            .animation(.easeOut(duration: 0.18), value: shown)
    }

    /// Where `cents` falls on a circle of `distance` around the pivot.
    private func point(cents: Double, pivot: CGPoint, distance: CGFloat) -> CGPoint {
        let angle = cents / Self.range * Self.sweep * .pi / 180
        return CGPoint(x: pivot.x + distance * CGFloat(sin(angle)), y: pivot.y - distance * CGFloat(cos(angle)))
    }

    private func arc(from start: Double, to end: Double, pivot: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            let steps = 48
            for step in 0...steps {
                let value = start + (end - start) * Double(step) / Double(steps)
                let location = point(cents: value, pivot: pivot, distance: radius)
                if step == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
        }
    }

    private func ticks(pivot: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for value in stride(from: -50, through: 50, by: 5) {
                let long = value % 25 == 0
                path.move(to: point(cents: Double(value), pivot: pivot, distance: radius - 12))
                path.addLine(to: point(cents: Double(value), pivot: pivot, distance: radius - (long ? 22 : 16)))
            }
        }
    }
}

// MARK: - Level meter

/// Five bars that light with the microphone's level.
private struct LevelMeter: View {
    let level: Double
    let isListening: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isListening ? PlayerTheme.cyan : PlayerTheme.muted)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<5, id: \.self) { bar in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Double(bar) < level * 5 ? PlayerTheme.cyan : PlayerTheme.raised)
                        .frame(width: 4, height: CGFloat(6 + bar * 3))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PlayerTheme.panel, in: Capsule())
        .accessibilityElement()
        .accessibilityLabel(isListening ? Text("Ouvindo") : Text("Microfone desligado"))
    }
}
