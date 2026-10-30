// PlayerKeyboard.swift
// luksMusic
//
// The score player's keyboard, drawn like the web player's: keys under the cursor light up cyan for the right
// hand and green for the left, the keyboard slides to keep them in sight, and touching a key plays it.

import SwiftUI

struct PlayerKeyboard: View {
    var trebleKeys: Set<Int>
    var bassKeys: Set<Int>
    var range: ClosedRange<Int> = 36...96

    @State private var pressed: Set<Int> = []
    @State private var offset: CGFloat = 0
    @State private var positioned = false

    private static let blackPitchClasses: Set<Int> = [1, 3, 6, 8, 10]
    private static let whiteGradient = [Color.white, Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)]
    private static let rightHandGradient = [PlayerTheme.cyan, Color(red: 2 / 255, green: 132 / 255, blue: 199 / 255)]
    private static let leftHandGradient = [PlayerTheme.green, Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255)]
    private static let touchGradient = [Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255), Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)]

    private var whiteKeys: [Int] {
        range.filter { !Self.isBlack($0) }
    }

    private var blackKeys: [Int] {
        range.filter { Self.isBlack($0) }
    }

    private static func isBlack(_ midi: Int) -> Bool {
        blackPitchClasses.contains(((midi % 12) + 12) % 12)
    }

    var body: some View {
        GeometryReader { geometry in
            // About three octaves on a phone, wider keys on bigger screens
            let keyWidth = max(18, geometry.size.width / 21)
            let keyHeight = geometry.size.height - 10
            let totalWidth = CGFloat(whiteKeys.count) * keyWidth
            let whiteIndex = Dictionary(uniqueKeysWithValues: whiteKeys.enumerated().map { ($1, $0) })

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whiteKeys, id: \.self) { midi in
                        whiteKey(midi, width: keyWidth, height: keyHeight)
                    }
                }

                ForEach(blackKeys, id: \.self) { midi in
                    if let index = whiteIndex[midi - 1] {
                        blackKey(midi, width: keyWidth * 0.62, height: keyHeight * 0.62)
                            .offset(x: CGFloat(index + 1) * keyWidth - keyWidth * 0.31)
                    }
                }
            }
            .frame(width: totalWidth, height: keyHeight, alignment: .topLeading)
            .offset(x: -offset)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
            .onChange(of: trebleKeys.union(bassKeys), initial: true) { _, keys in
                follow(keys, keyWidth: keyWidth, viewWidth: geometry.size.width, totalWidth: totalWidth, whiteIndex: whiteIndex)
            }
            .onChange(of: geometry.size.width) { _, width in
                positioned = false
                follow(trebleKeys.union(bassKeys), keyWidth: max(18, width / 21), viewWidth: width,
                       totalWidth: CGFloat(whiteKeys.count) * max(18, width / 21), whiteIndex: whiteIndex)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .background(
            LinearGradient(colors: [PlayerTheme.panel, Color(red: 8 / 255, green: 13 / 255, blue: 26 / 255)],
                           startPoint: .top, endPoint: .bottom)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerKeyboard")
    }

    // MARK: - Keys

    private func whiteKey(_ midi: Int, width: CGFloat, height: CGFloat) -> some View {
        let colors = gradient(for: midi) ?? Self.whiteGradient
        let lit = gradient(for: midi) != nil
        return UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay(
                UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
                    .stroke(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255), lineWidth: 0.5)
            )
            .overlay(alignment: .bottom) {
                if midi % 12 == 0 {
                    Text("Dó\(midi / 12 - 1)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(lit ? Color.white : Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
                        .padding(.bottom, 4)
                }
            }
            .shadow(color: lit ? colors[0].opacity(0.8) : .clear, radius: 6)
            .frame(width: width, height: height)
            .zIndex(lit ? 1 : 0)
            .contentShape(Rectangle())
            .gesture(touch(midi))
            .accessibilityElement()
            .accessibilityLabel(Self.name(midi))
            .accessibilityAddTraits(.isButton)
    }

    private func blackKey(_ midi: Int, width: CGFloat, height: CGFloat) -> some View {
        let colors = gradient(for: midi).map { [$0[1], $0[1]] }
            ?? [Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255), Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)]
        let lit = gradient(for: midi) != nil
        return UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay(
                UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)
                    .stroke(Color.black, lineWidth: 1)
            )
            .shadow(color: lit ? colors[0].opacity(0.9) : .black.opacity(0.6), radius: lit ? 6 : 2, x: lit ? 0 : 1, y: lit ? 0 : 2)
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(touch(midi))
            .accessibilityElement()
            .accessibilityLabel(Self.name(midi))
            .accessibilityAddTraits(.isButton)
    }

    /// The key's colors when it is lit: touched, right hand or left hand; nil when it is up.
    private func gradient(for midi: Int) -> [Color]? {
        if pressed.contains(midi) { return Self.touchGradient }
        if trebleKeys.contains(midi) { return Self.rightHandGradient }
        if bassKeys.contains(midi) { return Self.leftHandGradient }
        return nil
    }

    private func touch(_ midi: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !pressed.contains(midi) else { return }
                pressed.insert(midi)
                AudioEngineService.shared.playNote(midiNote: UInt8(midi), velocity: 90)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .onEnded { _ in
                pressed.remove(midi)
                AudioEngineService.shared.stopNote(midiNote: UInt8(midi))
            }
    }

    private static let names = ["Dó", "Dó♯", "Ré", "Ré♯", "Mi", "Fá", "Fá♯", "Sol", "Sol♯", "Lá", "Lá♯", "Si"]

    private static func name(_ midi: Int) -> String {
        "\(names[((midi % 12) + 12) % 12])\(midi / 12 - 1)"
    }

    // MARK: - Following the Cursor

    /// Slides the keyboard so the lit keys are in sight, staying put while they already are.
    private func follow(_ keys: Set<Int>, keyWidth: CGFloat, viewWidth: CGFloat, totalWidth: CGFloat, whiteIndex: [Int: Int]) {
        guard totalWidth > viewWidth else {
            offset = 0
            return
        }
        // A black key sits on the line after its white neighbour
        let xs = keys.compactMap { midi -> CGFloat? in
            if let index = whiteIndex[midi] { return (CGFloat(index) + 0.5) * keyWidth }
            if let index = whiteIndex[midi - 1] { return CGFloat(index + 1) * keyWidth }
            return nil
        }
        let target: CGFloat
        if let low = xs.min(), let high = xs.max() {
            if positioned && low >= offset + keyWidth && high <= offset + viewWidth - keyWidth { return }
            target = (low + high) / 2 - viewWidth / 2
        } else if !positioned, let middleC = whiteIndex[60] {
            target = (CGFloat(middleC) + 0.5) * keyWidth - viewWidth / 2
        } else {
            return
        }
        let clamped = min(max(0, target), totalWidth - viewWidth)
        if positioned {
            withAnimation(.easeInOut(duration: 0.25)) { offset = clamped }
        } else {
            offset = clamped
            positioned = true
        }
    }
}
