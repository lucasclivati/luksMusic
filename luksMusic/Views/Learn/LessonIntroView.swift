// LessonIntroView.swift
// luksMusic
//
// Full-screen vertical animated introduction for a lesson: builds the five staff lines and four spaces,
// shows middle C two steps below the first line, and presses one white key at a time up to the next C
// across a clean two-octave keyboard, with subtitles in the user's chosen language.

import CoreText
import QuartzCore
import SwiftUI
import UIKit

@MainActor
@Observable
final class LessonIntroController {
    let intro: LessonIntro
    let duration: Double

    private(set) var elapsed: Double = 0
    private(set) var isPlaying: Bool = true
    private(set) var isFinished: Bool = false
    private(set) var userTappedKey: Int?

    @ObservationIgnored private var loopToken: Int = 0
    @ObservationIgnored private var lastTimestamp: CFTimeInterval?
    @ObservationIgnored private var firedPressIDs: Set<Int> = []
    @ObservationIgnored private let presses: [LessonIntroPress]
    private let audioEngine = AudioEngineService.shared

    init(intro: LessonIntro) {
        self.intro = intro
        self.duration = LessonIntroScript.duration(for: intro)
        self.presses = LessonIntroScript.presses(for: intro)
    }

    var progress: Double {
        duration > 0 ? min(1, max(0, elapsed / duration)) : 0
    }

    var snapshot: LessonIntroSnapshot {
        LessonIntroScript.snapshot(for: intro, at: elapsed)
    }

    func start() {
        audioEngine.ensureRunning()
        startLoop()
    }

    func stop() {
        loopToken += 1
        lastTimestamp = nil
        audioEngine.stopAllNotes()
    }

    func togglePlayback() {
        if isFinished {
            replay()
            return
        }
        isPlaying.toggle()
        if isPlaying {
            lastTimestamp = CACurrentMediaTime()
            startLoop()
        } else {
            loopToken += 1
            lastTimestamp = nil
            audioEngine.stopAllNotes()
        }
    }

    func replay() {
        audioEngine.stopAllNotes()
        elapsed = 0
        firedPressIDs = []
        isFinished = false
        isPlaying = true
        lastTimestamp = CACurrentMediaTime()
        startLoop()
    }

    func seek(to fraction: Double) {
        let clamped = min(1, max(0, fraction))
        elapsed = clamped * duration
        firedPressIDs = Set(presses.filter { $0.onset <= elapsed }.map(\.id))
        isFinished = elapsed >= duration
        lastTimestamp = CACurrentMediaTime()
    }

    func tapPreviewKey(_ midi: Int) {
        audioEngine.ensureRunning()
        audioEngine.playNote(midiNote: UInt8(clamping: midi), velocity: 84, duration: 0.55)
        userTappedKey = midi
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 380_000_000)
            if self?.userTappedKey == midi {
                self?.userTappedKey = nil
            }
        }
    }

    private func startLoop() {
        loopToken += 1
        let token = loopToken
        lastTimestamp = CACurrentMediaTime()

        Task { @MainActor [weak self] in
            while let self, self.loopToken == token, self.isPlaying {
                let now = CACurrentMediaTime()
                let dt = min(0.1, max(0, now - (self.lastTimestamp ?? now)))
                self.lastTimestamp = now

                let previous = self.elapsed
                let next = min(self.duration, previous + dt)
                self.elapsed = next

                for press in self.presses where press.onset <= next && press.onset >= previous - 0.15 {
                    if self.firedPressIDs.insert(press.id).inserted {
                        let velocity: UInt8 = press.spawnsNote ? 86 : 78
                        self.audioEngine.playNote(
                            midiNote: UInt8(clamping: press.midi),
                            velocity: velocity,
                            duration: press.holdDuration * 0.92
                        )
                    }
                }

                if next >= self.duration {
                    self.isPlaying = false
                    self.isFinished = true
                    return
                }

                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
}

// MARK: - Main Vertical Stage View

struct LessonIntroView: View {
    let intro: LessonIntro
    var onContinue: () -> Void

    @State private var controller: LessonIntroController
    @State private var isScrubbing = false

    init(intro: LessonIntro, onContinue: @escaping () -> Void) {
        self.intro = intro
        self.onContinue = onContinue
        _controller = State(initialValue: LessonIntroController(intro: intro))
    }

    var body: some View {
        let snap = controller.snapshot

        GeometryReader { geo in
            let keyboardHeight = min(215, max(135, geo.size.height * 0.26))
            let controlsHeight: CGFloat = 54
            let subtitleSectionHeight: CGFloat = min(132, max(106, geo.size.height * 0.19))
            let staffCardHeight = max(145, geo.size.height - keyboardHeight - controlsHeight - subtitleSectionHeight - 22)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 8) {
                    subtitleHeader(snap)
                        .frame(height: subtitleSectionHeight)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    IntroStaffCard(snapshot: snap)
                        .frame(height: staffCardHeight)
                        .padding(.horizontal, 12)

                    transportBar(snap)
                        .frame(height: controlsHeight)
                        .padding(.horizontal, 12)

                    IntroTwoOctaveKeyboard(
                        snapshot: snap,
                        userTappedKey: controller.userTappedKey,
                        onTapKey: { midi in controller.tapPreviewKey(midi) }
                    )
                    .frame(height: keyboardHeight)
                }

                // Luminous connection beam from the struck white key up to its note on the staff
                if let beam = snap.beam {
                    IntroBeamOverlay(
                        beam: beam,
                        totalSize: geo.size,
                        staffTop: subtitleSectionHeight + 16,
                        staffHeight: staffCardHeight,
                        keyboardTop: geo.size.height - keyboardHeight
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .background(PlayerTheme.background)
        .onAppear {
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lessonIntroView")
    }

    // MARK: - Subtitle Card

    private func subtitleHeader(_ snap: LessonIntroSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(String(localized: "VÍDEO"), systemImage: "play.rectangle.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(PlayerTheme.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PlayerTheme.cyan.opacity(0.16), in: Capsule())
                    .accessibilityIdentifier("lessonStepBadge")

                Text("\(snap.cue.phaseNumber)/\(snap.totalPhases) · \(snap.cue.phaseLabel)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PlayerTheme.muted)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(snap.cue.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(PlayerTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(snap.cue.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PlayerTheme.muted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(snap.cue.title)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: snap.cue.title)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PlayerTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PlayerTheme.raised, lineWidth: 1)
        )
    }

    // MARK: - Transport & Action Bar

    private func transportBar(_ snap: LessonIntroSnapshot) -> some View {
        let readyToAdvance = controller.isFinished || snap.time >= snap.duration - 4.0

        return HStack(spacing: 10) {
            Button {
                controller.togglePlayback()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : (controller.isFinished ? "arrow.counterclockwise" : "play.fill"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PlayerTheme.text)
                    .frame(width: 38, height: 38)
                    .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .accessibilityLabel(controller.isPlaying ? String(localized: "Pausar") : String(localized: "Tocar"))
            .accessibilityIdentifier("introPlayPauseButton")

            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { controller.progress },
                        set: { value in controller.seek(to: value) }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                    }
                )
                .tint(PlayerTheme.cyan)

                HStack {
                    Text(Self.clock(snap.time))
                    Spacer()
                    Text(Self.clock(snap.duration))
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PlayerTheme.muted)
            }

            if controller.elapsed > 3 && !controller.isFinished {
                Button {
                    controller.replay()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PlayerTheme.text)
                        .frame(width: 34, height: 38)
                        .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .accessibilityLabel(String(localized: "Rever"))
                .accessibilityIdentifier("introReplayButton")
            }

            Button {
                controller.stop()
                onContinue()
            } label: {
                HStack(spacing: 5) {
                    Text(readyToAdvance ? String(localized: "Começar a tocar") : String(localized: "Pular"))
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(readyToAdvance ? .white : PlayerTheme.text)
                .padding(.horizontal, readyToAdvance ? 16 : 12)
                .frame(height: 38)
                .background(
                    readyToAdvance ? PlayerTheme.deepBlue : PlayerTheme.raised,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .shadow(color: readyToAdvance ? PlayerTheme.blue.opacity(0.45) : .clear, radius: 8)
            }
            .animation(.easeInOut(duration: 0.25), value: readyToAdvance)
            .accessibilityIdentifier("lessonContinueButton")
        }
    }

    private static func clock(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

// MARK: - Shared Staff Metrics

private struct IntroStaffMetrics {
    let size: CGSize
    let unit: CGFloat
    let originY: CGFloat
    let topPosition: Int = 6
    let left: CGFloat = 14
    let right: CGFloat
    let clefWidth: CGFloat
    let notesStart: CGFloat
    let columnWidth: CGFloat

    var space: CGFloat { unit * 2 }

    init(size: CGSize) {
        self.size = size
        let maxUnitByHeight = (size.height - 44) / 15.0
        let maxUnitByWidth = (size.width - 36) / 30.0
        self.unit = min(12.0, max(5.5, min(maxUnitByHeight, maxUnitByWidth)))
        let space = self.unit * 2
        let usedHeight = 14.0 * self.unit // positions +6 down to -8
        self.originY = 14 + max(0, (size.height - 38 - usedHeight) / 2)
        self.right = size.width - 28
        self.clefWidth = space * 2.95
        self.notesStart = left + clefWidth + space * 0.7
        self.columnWidth = max(14, (right - notesStart - space * 0.3) / 8.0)
    }

    func y(_ position: Int) -> CGFloat {
        originY + CGFloat(topPosition - position) * unit
    }

    func columnX(_ column: Int) -> CGFloat {
        notesStart + columnWidth * (CGFloat(column) + 0.5)
    }
}

// MARK: - Animated Staff Card

private struct IntroStaffCard: View {
    let snapshot: LessonIntroSnapshot

    private static let ink = ReadingStaffView.ink
    private static let activeBlue = ReadingStaffView.currentColor
    private static let cyan = Color(red: 14 / 255, green: 165 / 255, blue: 233 / 255)
    private static let green = ReadingStaffView.rightColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)

            Canvas { context, size in
                guard size.width > 60, size.height > 60 else { return }
                drawStaff(in: &context, size: size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func drawStaff(in context: inout GraphicsContext, size: CGSize) {
        let m = IntroStaffMetrics(size: size)
        let space = m.space

        // 1. Space bands (between lines, plus space below line 1 for D4)
        for spaceIdx in 0..<4 {
            let glow = snapshot.spaceGlow[spaceIdx]
            guard glow > 0.01 else { continue }
            let pos = -3 + spaceIdx * 2
            let bandRect = CGRect(
                x: m.left,
                y: m.y(pos + 1) + 1,
                width: m.right - m.left,
                height: max(2, space - 2)
            )
            context.fill(Path(roundedRect: bandRect, cornerRadius: 3), with: .color(Self.cyan.opacity(0.22 * glow)))
        }

        if snapshot.belowLineSpaceGlow > 0.01 {
            let bandRect = CGRect(
                x: m.left,
                y: m.y(-4) + 1,
                width: m.right - m.left,
                height: max(2, space - 2)
            )
            context.fill(
                Path(roundedRect: bandRect, cornerRadius: 3),
                with: .color(Self.cyan.opacity(0.22 * snapshot.belowLineSpaceGlow))
            )
        }

        // 2. Five staff lines (drawn progressively left-to-right, numbered 1 to 5 on the right)
        for lineIdx in 0..<5 {
            let progress = snapshot.lineProgress[lineIdx]
            guard progress > 0.005 else { continue }
            let pos = -4 + lineIdx * 2
            let y = m.y(pos)
            let endX = m.left + (m.right - m.left) * CGFloat(progress)
            let glow = snapshot.lineGlow[lineIdx]

            if glow > 0.01 {
                var glowPath = Path()
                glowPath.move(to: CGPoint(x: m.left, y: y))
                glowPath.addLine(to: CGPoint(x: endX, y: y))
                context.stroke(glowPath, with: .color(Self.activeBlue.opacity(0.35 * glow)), lineWidth: 5.0)
            }

            var path = Path()
            path.move(to: CGPoint(x: m.left, y: y))
            path.addLine(to: CGPoint(x: endX, y: y))
            let lineColor = glow > 0.1 ? Self.activeBlue : Self.ink.opacity(0.84)
            context.stroke(path, with: .color(lineColor), lineWidth: glow > 0.1 ? 2.0 : 1.3)

            // Line number badge on the right margin
            let numberOpacity = min(1.0, progress * 1.4)
            let numberColor = glow > 0.1 ? Self.activeBlue : Color.gray.opacity(0.75 * numberOpacity)
            context.draw(
                Text("\(lineIdx + 1)")
                    .font(.system(size: max(10, m.unit * 1.05), weight: .bold, design: .rounded))
                    .foregroundColor(numberColor),
                at: CGPoint(x: m.right + 12, y: y),
                anchor: .center
            )
        }

        // 3. Two-steps-below guide leading down to Middle C before/during C4
        if snapshot.middleCGuideOpacity > 0.01 {
            let alpha = snapshot.middleCGuideOpacity
            let cX = m.columnX(0)
            for (stepPos, label) in [(-5, "-1"), (-6, "-2")] {
                let y = m.y(stepPos)
                var dash = Path()
                dash.move(to: CGPoint(x: cX - space * 1.1, y: y))
                dash.addLine(to: CGPoint(x: cX + space * 1.1, y: y))
                context.stroke(
                    dash,
                    with: .color(Self.cyan.opacity(0.55 * alpha)),
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                )
                    context.draw(
                        Text(label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Self.cyan.opacity(0.9 * alpha)),
                        at: CGPoint(x: cX + space * 1.45, y: y),
                        anchor: .center
                    )
            }
        }

        // 4. Treble Clef (with G-line curl highlight when G4 plays)
        if snapshot.clefProgress > 0.01 {
            if snapshot.clefLinePulse > 0.01 {
                let curlCenter = CGPoint(x: m.left + space * 1.35, y: m.y(-2))
                let radius = space * (1.1 + 0.25 * CGFloat(snapshot.clefLinePulse))
                let ring = Path(ellipseIn: CGRect(x: curlCenter.x - radius, y: curlCenter.y - radius,
                                                  width: radius * 2, height: radius * 2))
                context.fill(ring, with: .color(Self.cyan.opacity(0.18 * snapshot.clefLinePulse)))
            }
            var clefContext = context
            clefContext.opacity = snapshot.clefProgress
            drawSymbol(
                "𝄞",
                in: &clefContext,
                inkHeight: space * 7.0,
                left: m.left + space * 0.2,
                bottom: m.y(-7) + m.unit * 0.3
            )
        }

        // 5. Step-up arrow (+1/2 line) between consecutive notes
        if let stepUp = snapshot.stepUpIndicator, stepUp.progress > 0.02 {
            let x1 = m.columnX(stepUp.fromColumn)
            let x2 = m.columnX(stepUp.toColumn)
            let pos1 = -6 + stepUp.fromColumn
            let pos2 = -6 + stepUp.toColumn
            let midX = (x1 + x2) / 2
            let y1 = m.y(pos1)
            let y2 = m.y(pos2)
            var arc = Path()
            arc.move(to: CGPoint(x: x1 + space * 0.45, y: y1 - m.unit * 0.8))
            arc.addQuadCurve(
                to: CGPoint(x: x2 - space * 0.45, y: y2 - m.unit * 0.9),
                control: CGPoint(x: midX, y: min(y1, y2) - space * 1.15)
            )
            context.stroke(
                arc,
                with: .color(Self.cyan.opacity(0.85 * stepUp.progress)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
        }

        // 6. Octave arch connecting C4 (column 0) and C5 (column 7)
        if snapshot.octaveArchProgress > 0.01 {
            let alpha = snapshot.octaveArchProgress
            let startX = m.columnX(0)
            let endX = m.columnX(7)
            let archTopY = m.y(5) - m.unit * 0.6
            var arch = Path()
            arch.move(to: CGPoint(x: startX, y: m.y(3)))
            arch.addQuadCurve(
                to: CGPoint(x: endX, y: m.y(3)),
                control: CGPoint(x: (startX + endX) / 2, y: archTopY - space * 0.9)
            )
            context.stroke(
                arch,
                with: .color(Self.green.opacity(0.75 * alpha)),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [5, 3])
            )
            let badgeText = String(localized: "1 oitava (8 notas)")
            context.draw(
                Text(badgeText)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(Self.green.opacity(alpha)),
                at: CGPoint(x: (startX + endX) / 2, y: archTopY - space * 0.35),
                anchor: .center
            )
        }

        // 7. Spawned notes (C4 through C5)
        let headWidth = space * 1.26
        let headHeight = space * 0.92
        let labelsY = m.y(-7) + m.unit * 1.05

        for note in snapshot.notes {
            let x = m.columnX(note.id)
            let y = m.y(note.staffPosition)
            let scale = springScale(note.appearProgress)
            let color: Color = note.finaleGlow > 0.15
                ? Self.green
                : (note.activeGlow > 0.15 ? Self.activeBlue : Self.ink)

            // Halo while active or during finale
            let haloStrength = max(note.activeGlow, note.finaleGlow)
            if haloStrength > 0.05 {
                let radius = headWidth * (0.85 + 0.25 * CGFloat(haloStrength))
                let haloColor = note.finaleGlow > 0.15 ? Self.green : Self.cyan
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(haloColor.opacity(0.20 * haloStrength))
                )
            }

            // Short ledger line for Middle C (position -6)
            if note.staffPosition <= -6 {
                let ledgerHalf = headWidth * 0.85 * scale
                var ledger = Path()
                ledger.move(to: CGPoint(x: x - ledgerHalf, y: m.y(-6)))
                ledger.addLine(to: CGPoint(x: x + ledgerHalf, y: m.y(-6)))
                let ledgerColor = note.activeGlow > 0.15 ? Self.activeBlue : Self.ink.opacity(0.88)
                context.stroke(ledger, with: .color(ledgerColor), lineWidth: note.activeGlow > 0.15 ? 2.2 : 1.6)
            }

            // Stem
            let stemTipPos = note.stemUp ? max(note.staffPosition + 7, 0) : min(note.staffPosition - 7, 0)
            let stemX = note.stemUp ? x + (headWidth * scale) / 2 - 0.8 : x - (headWidth * scale) / 2 + 0.8
            var stem = Path()
            stem.move(to: CGPoint(x: stemX, y: y))
            stem.addLine(to: CGPoint(x: stemX, y: y + (m.y(stemTipPos) - y) * scale))
            context.stroke(stem, with: .color(color.opacity(min(1, note.appearProgress * 1.4))), lineWidth: 1.6)

            // Notehead
            let ellipse = Path(ellipseIn: CGRect(
                x: -(headWidth * scale) / 2,
                y: -(headHeight * scale) / 2,
                width: headWidth * scale,
                height: headHeight * scale
            ))
            .applying(CGAffineTransform(rotationAngle: -.pi / 9))
            .applying(CGAffineTransform(translationX: x, y: y))
            context.fill(ellipse, with: .color(color))

            // Note name underneath
            context.draw(
                Text(note.name)
                    .font(.system(size: max(11, m.unit * 1.25), weight: .bold, design: .rounded))
                    .foregroundColor(color),
                at: CGPoint(x: x, y: labelsY),
                anchor: .top
            )
        }

        // 8. Position callout pill floating above the staff for the active note
        if let callout = snapshot.activeCallout, !callout.text.isEmpty, callout.opacity > 0.05 {
            let targetX = min(max(m.left + 72, m.columnX(callout.staffColumn)), m.right - 68)
            let pillY = max(14, m.y(5) - m.unit * 0.5)
            context.draw(
                Text(callout.text)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Self.activeBlue.opacity(callout.opacity)),
                at: CGPoint(x: targetX, y: pillY),
                anchor: .center
            )
        }
    }

    private func springScale(_ p: Double) -> CGFloat {
        guard p < 1 else { return 1 }
        if p < 0.65 {
            let t = p / 0.65
            return CGFloat(0.25 + 0.90 * (1 - pow(1 - t, 3)))
        }
        let t = (p - 0.65) / 0.35
        return CGFloat(1.15 - 0.15 * t)
    }

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
            cg.translateBy(x: left - ink.minX, y: bottom + ink.minY)
            cg.scaleBy(x: 1, y: -1)
            cg.textMatrix = .identity
            cg.textPosition = .zero
            CTLineDraw(drawn, cg)
            cg.restoreGState()
        }
    }
}

// MARK: - Beam Overlay Connecting Keyboard Key to Staff Note

private struct IntroBeamOverlay: View {
    let beam: (midi: Int, staffColumn: Int, staffPosition: Int, progress: Double)
    let totalSize: CGSize
    let staffTop: CGFloat
    let staffHeight: CGFloat
    let keyboardTop: CGFloat

    var body: some View {
        Canvas { context, _ in
            let staffCardWidth = totalSize.width - 24
            guard staffCardWidth > 60 else { return }
            let m = IntroStaffMetrics(size: CGSize(width: staffCardWidth, height: staffHeight))

            let endPoint = CGPoint(
                x: 12 + m.columnX(beam.staffColumn),
                y: staffTop + m.y(beam.staffPosition)
            )

            let whiteKeyWidth = (totalSize.width - 4) / 15.0
            let whiteIdx = IntroKeyboardGeometry.whiteSlot(forMidi: Double(beam.midi))
            let startPoint = CGPoint(
                x: 2 + (CGFloat(whiteIdx) + 0.5) * whiteKeyWidth,
                y: keyboardTop + 18
            )

            let p = beam.progress
            let headT = min(1.0, p * 1.45)
            let tailT = max(0.0, (p - 0.25) / 0.75)
            guard headT > tailT else { return }

            let control = CGPoint(
                x: startPoint.x + (endPoint.x - startPoint.x) * 0.35,
                y: (startPoint.y + endPoint.y) * 0.5
            )

            var fullPath = Path()
            fullPath.move(to: startPoint)
            fullPath.addQuadCurve(to: endPoint, control: control)
            let segment = fullPath.trimmedPath(from: CGFloat(tailT), to: CGFloat(headT))

            context.stroke(
                segment,
                with: .color(PlayerTheme.cyan.opacity(0.65 * (1 - p * 0.6))),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
            )

            let sparkPoint = quadBezierPoint(t: CGFloat(headT), p0: startPoint, p1: control, p2: endPoint)
            let sparkRadius: CGFloat = 5.5
            context.fill(
                Path(ellipseIn: CGRect(x: sparkPoint.x - sparkRadius, y: sparkPoint.y - sparkRadius,
                                       width: sparkRadius * 2, height: sparkRadius * 2)),
                with: .color(PlayerTheme.cyan.opacity(1 - p * 0.7))
            )
        }
    }

    private func quadBezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * p0.x + 2 * oneMinusT * t * p1.x + t * t * p2.x
        let y = oneMinusT * oneMinusT * p0.y + 2 * oneMinusT * t * p1.y + t * t * p2.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Two-Octave Animated Keyboard (C4 to C6, 15 White Keys)

private enum IntroKeyboardGeometry {
    /// Maps a continuous MIDI number in 60...84 to a continuous white-key slot index in 0...14.
    static func whiteSlot(forMidi midi: Double) -> Double {
        let clamped = min(84, max(60, midi))
        let rel = clamped - 60.0
        let octave = floor(rel / 12.0)
        let semitone = rel - octave * 12.0

        let anchors: [(semi: Double, slot: Double)] = [
            (0, 0), (2, 1), (4, 2), (5, 3), (7, 4), (9, 5), (11, 6), (12, 7)
        ]
        var localSlot = 0.0
        for idx in 0..<(anchors.count - 1) {
            let a = anchors[idx]
            let b = anchors[idx + 1]
            if semitone >= a.semi && semitone <= b.semi {
                let frac = (semitone - a.semi) / (b.semi - a.semi)
                localSlot = a.slot + (b.slot - a.slot) * frac
                break
            }
        }
        return octave * 7.0 + localSlot
    }
}

private struct IntroTwoOctaveKeyboard: View {
    let snapshot: LessonIntroSnapshot
    let userTappedKey: Int?
    let onTapKey: (Int) -> Void

    private static let allKeys: [PianoKey] = (60...84).map { midi in
        let octave = (midi / 12) - 1
        let noteIndex = midi % 12
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let blacks: Set<Int> = [1, 3, 6, 8, 10]
        return PianoKey(id: midi, noteName: names[noteIndex], octave: octave, isBlack: blacks.contains(noteIndex))
    }

    private var whiteKeys: [PianoKey] { Self.allKeys.filter { !$0.isBlack } }
    private var blackKeys: [PianoKey] { Self.allKeys.filter(\.isBlack) }

    var body: some View {
        let usesLetters = AppLanguage.usesLetterNames
        let labelStyle: KeyLabelStyle = usesLetters ? .letter : .solfege

        GeometryReader { geo in
            let wCount = CGFloat(whiteKeys.count) // 15 white keys (2 octaves)
            let wWidth = geo.size.width / max(1, wCount)
            let wHeight = geo.size.height
            let bWidth = wWidth * 0.60
            let bHeight = wHeight * 0.61

            ZStack(alignment: .topLeading) {
                // White keys
                HStack(spacing: 0) {
                    ForEach(whiteKeys) { key in
                        let highlight = whiteHighlight(for: key.id)
                        let isDepressed = (snapshot.activeCyanKey == key.id || snapshot.activeGreenKey == key.id) && snapshot.cursorPressDepth > 0.1
                        Button {
                            onTapKey(key.id)
                        } label: {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3.5)
                                    .fill(
                                        highlight.map {
                                            LinearGradient(colors: [$0, $0.opacity(0.84)], startPoint: .top, endPoint: .bottom)
                                        } ?? LinearGradient(
                                            colors: [Color(white: 0.98), Color(white: 0.93), Color(white: 0.88)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.white))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .strokeBorder(Color.gray.opacity(0.32), lineWidth: 0.5)
                                    )
                                    .shadow(color: highlight?.opacity(0.65) ?? .clear, radius: highlight != nil ? 9 : 0)

                                if let label = key.label(style: labelStyle, marksOctave: true) {
                                    Text(label)
                                        .font(.system(size: min(wWidth * 0.36, 13), weight: key.noteName == "C" ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(highlight == nil ? (key.noteName == "C" ? Color.black.opacity(0.75) : Color.gray) : Color.black.opacity(0.85))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.55)
                                        .padding(.bottom, 8)
                                }
                            }
                            .frame(width: wWidth, height: wHeight)
                            .offset(y: isDepressed ? 2.5 * CGFloat(snapshot.cursorPressDepth) : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Black keys (with highlight on pairs of 2 black keys when locating C)
                ForEach(blackKeys) { key in
                    let isPairOfTwo = [61, 63, 73, 75].contains(key.id)
                    let pairGlow = isPairOfTwo ? snapshot.twoBlackKeysGlow : 0
                    let tapped = userTappedKey == key.id
                    let xOffset = blackKeyOffset(for: key, whiteWidth: wWidth, blackWidth: bWidth)

                    Button {
                        onTapKey(key.id)
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                tapped
                                    ? LinearGradient(colors: [PianoKeyboardViewModel.electricCyan, PianoKeyboardViewModel.electricCyan.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                    : (pairGlow > 0.05
                                        ? LinearGradient(
                                            colors: [PlayerTheme.cyan.opacity(0.45 + 0.45 * pairGlow), Color(white: 0.14)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(
                                            colors: [Color(white: 0.22), Color(white: 0.12), Color(white: 0.05)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(pairGlow > 0.05 ? PlayerTheme.cyan.opacity(pairGlow) : Color.black.opacity(0.5), lineWidth: pairGlow > 0.05 ? 1.5 : 0.5)
                            )
                            .shadow(color: pairGlow > 0.05 ? PlayerTheme.cyan.opacity(0.6 * pairGlow) : .black.opacity(0.4), radius: pairGlow > 0.05 ? 8 : 3, y: 2)
                            .frame(width: bWidth, height: bHeight)
                    }
                    .buttonStyle(.plain)
                    .offset(x: xOffset)
                    .zIndex(1)
                }

                // Motion-capture touch orb gliding smoothly over the white keys
                if snapshot.cursorOpacity > 0.01 {
                    let slot = IntroKeyboardGeometry.whiteSlot(forMidi: snapshot.cursorMidiPosition)
                    let cursorX = (CGFloat(slot) + 0.5) * wWidth
                    let cursorY = wHeight * 0.72 + CGFloat(snapshot.cursorPressDepth) * 2.5
                    let isFinale = snapshot.activeGreenKey != nil
                    let orbColor = isFinale ? PianoKeyboardViewModel.neonGreen : PianoKeyboardViewModel.electricCyan

                    if let ripple = snapshot.ripple {
                        let rippleSlot = IntroKeyboardGeometry.whiteSlot(forMidi: Double(ripple.midi))
                        let rippleX = (CGFloat(rippleSlot) + 0.5) * wWidth
                        Circle()
                            .stroke(orbColor.opacity((1 - ripple.progress) * 0.85 * snapshot.cursorOpacity), lineWidth: 2.5)
                            .frame(width: 24 + CGFloat(ripple.progress) * 34, height: 24 + CGFloat(ripple.progress) * 34)
                            .position(x: rippleX, y: wHeight * 0.72 + 2.0)
                            .zIndex(2)
                            .allowsHitTesting(false)
                    }

                    ZStack {
                        Circle()
                            .fill(orbColor.opacity(0.28))
                            .frame(width: 34, height: 34)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, orbColor],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: 12
                                )
                            )
                            .frame(width: 20, height: 20)
                            .scaleEffect(1.0 - 0.14 * CGFloat(snapshot.cursorPressDepth))
                            .shadow(color: orbColor.opacity(0.9), radius: 8)
                    }
                    .opacity(snapshot.cursorOpacity)
                    .position(x: cursorX, y: cursorY)
                    .zIndex(2)
                    .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 2)
        .background(PlayerTheme.panel.ignoresSafeArea(edges: .bottom))
        .accessibilityIdentifier("introTwoOctaveKeyboard")
    }

    private func whiteHighlight(for midi: Int) -> Color? {
        if userTappedKey == midi {
            return PianoKeyboardViewModel.electricCyan
        }
        if snapshot.activeGreenKey == midi {
            return PianoKeyboardViewModel.neonGreen
        }
        if snapshot.activeCyanKey == midi {
            return PianoKeyboardViewModel.electricCyan
        }
        return nil
    }

    private func blackKeyOffset(for key: PianoKey, whiteWidth: CGFloat, blackWidth: CGFloat) -> CGFloat {
        guard let whiteIndex = whiteKeys.lastIndex(where: { $0.id < key.id }) else { return 0 }
        return CGFloat(whiteIndex + 1) * whiteWidth - (blackWidth / 2)
    }
}
