// LessonIntro.swift
// luksMusic
//
// Scripted motion-graphics introductions for lessons: timed chapters, progressive staff construction,
// animated key presses across a two-octave keyboard, and bilingual subtitles following AppLanguage.

import Foundation

enum LessonIntro: String, Equatable, CaseIterable, Identifiable {
    /// How sheet music begins: the 5 lines, 4 spaces, middle C two steps below line 1, and climbing one octave.
    case trebleOctave

    var id: String { rawValue }
}

/// One timed subtitle chapter shown above the animated staff.
struct LessonIntroCue: Equatable {
    let startTime: Double
    let endTime: Double
    let phaseNumber: Int
    let phaseLabel: String
    let title: String
    let subtitle: String
}

/// One key press in the scripted choreography, spawning or highlighting a note on the staff.
struct LessonIntroPress: Equatable, Identifiable {
    let id: Int
    /// Pitch token such as "C4"
    let token: String
    let midi: Int
    /// Diatonic staff position in treble clef (-6 = middle C ledger line, -4 = line 1, +1 = space 3)
    let staffPosition: Int
    /// Column index on the staff (0...7 for C4...C5)
    let staffColumn: Int
    /// Time in seconds when the key is struck
    let onset: Double
    /// How long the key stays held down
    let holdDuration: Double
    /// Whether this strike spawns the note on the staff for the first time (false during the finale replay)
    let spawnsNote: Bool
    /// Short callout tag shown by the staff line or space while this note is introduced
    let positionCallout: String
}

/// Complete state of the intro animation at a given timestamp `time` (0...duration).
struct LessonIntroSnapshot: Equatable {
    struct VisibleNote: Equatable, Identifiable {
        let id: Int // staffColumn 0...7
        let midi: Int
        let staffPosition: Int
        let name: String
        /// 0...1 spring-in progress when the note first materializes
        let appearProgress: Double
        /// 0...1 highlight while being introduced
        let activeGlow: Double
        /// 0...1 emerald highlight during the octave replay finale
        let finaleGlow: Double
        /// Stem points up below the middle line, down from B4 up
        var stemUp: Bool { staffPosition < 0 }
    }

    let time: Double
    let duration: Double
    let cue: LessonIntroCue
    let totalPhases: Int

    /// Draw progress (0...1) for each of the 5 staff lines, bottom (index 0, pos -4) to top (index 4, pos +4)
    let lineProgress: [Double]
    /// Highlight intensity (0...1) for each of the 5 staff lines when a note lands on that line
    let lineGlow: [Double]
    /// Highlight intensity (0...1) for each of the 4 spaces, bottom (index 0, pos -3) to top (index 3, pos +3)
    let spaceGlow: [Double]
    /// Highlight intensity (0...1) for the space right below line 1 (D4, pos -5)
    let belowLineSpaceGlow: Double
    /// Reveal progress (0...1) of the treble clef
    let clefProgress: Double
    /// Extra pulse (0...1) around the treble clef's G-line curl when G4 is introduced
    let clefLinePulse: Double
    /// Visibility (0...1) of the 2-steps-below guide leading from line 1 down to middle C
    let middleCGuideOpacity: Double
    /// Active callout label next to the current note's line/space, if any
    let activeCallout: (staffColumn: Int, staffPosition: Int, text: String, opacity: Double)?
    /// Visibility (0...1) of the "+1/2" step indicator between the previous note and the current note
    let stepUpIndicator: (fromColumn: Int, toColumn: Int, progress: Double)?
    /// Visibility (0...1) of the octave arch spanning from C4 (col 0) to C5 (col 7)
    let octaveArchProgress: Double
    /// Notes currently visible on the staff
    let notes: [VisibleNote]

    /// Highlight intensity (0...1) on the pairs of 2 black keys (showing how to find C)
    let twoBlackKeysGlow: Double
    /// Touch cursor visibility (0...1)
    let cursorOpacity: Double
    /// Continuous MIDI position of the gliding touch cursor on the two-octave keyboard
    let cursorMidiPosition: Double
    /// Key depression amount (0...1) at the cursor
    let cursorPressDepth: Double
    /// Expanding touch ripple anchored at the struck key, or nil when idle
    let ripple: (midi: Int, progress: Double)?
    /// MIDI key currently lit in cyan (learning strike)
    let activeCyanKey: Int?
    /// MIDI key currently lit in green (finale scale replay)
    let activeGreenKey: Int?
    /// Light beam rising from the struck key to the newly spawned note on the staff
    let beam: (midi: Int, staffColumn: Int, staffPosition: Int, progress: Double)?

    static func == (lhs: LessonIntroSnapshot, rhs: LessonIntroSnapshot) -> Bool {
        lhs.time == rhs.time && lhs.duration == rhs.duration && lhs.cue == rhs.cue
    }
}

enum LessonIntroScript {

    /// Two clean octaves from middle C (C4 = 60 to C6 = 84, 15 white keys), avoiding visual overload.
    static let keyboardRange: ClosedRange<Int> = 60...84

    static func duration(for intro: LessonIntro) -> Double {
        switch intro {
        case .trebleOctave: return 45.5
        }
    }

    /// All scripted piano strikes, in chronological order. Each `id` fires audio once when playback crosses `onset`.
    static func presses(for intro: LessonIntro, usesLetters: Bool = AppLanguage.usesLetterNames) -> [LessonIntroPress] {
        switch intro {
        case .trebleOctave:
            let steps: [(token: String, midi: Int, pos: Int, onset: Double, callout: String)] = [
                ("C4", 60, -6, 10.6, String(localized: "Linha curta (2 abaixo)")),
                ("D4", 62, -5, 14.6, String(localized: "Embaixo da 1ª linha")),
                ("E4", 64, -4, 18.0, String(localized: "1ª linha")),
                ("F4", 65, -3, 21.4, String(localized: "1º espaço")),
                ("G4", 67, -2, 24.8, String(localized: "2ª linha (Sol)")),
                ("A4", 69, -1, 28.2, String(localized: "2º espaço")),
                ("B4", 71,  0, 31.6, String(localized: "3ª linha (meio)")),
                ("C5", 72,  1, 35.0, String(localized: "3º espaço (1 oitava)")),
            ]
            var result: [LessonIntroPress] = steps.enumerated().map { index, item in
                LessonIntroPress(
                    id: index,
                    token: item.token,
                    midi: item.midi,
                    staffPosition: item.pos,
                    staffColumn: index,
                    onset: item.onset,
                    holdDuration: 1.35,
                    spawnsNote: true,
                    positionCallout: item.callout
                )
            }
            // Finale replay: smooth ascending C major scale across the whole octave
            let finaleStart = 39.4
            let stepGap = 0.48
            for (index, item) in steps.enumerated() {
                let isLast = index == steps.count - 1
                result.append(LessonIntroPress(
                    id: steps.count + index,
                    token: item.token,
                    midi: item.midi,
                    staffPosition: item.pos,
                    staffColumn: index,
                    onset: finaleStart + Double(index) * stepGap,
                    holdDuration: isLast ? 1.4 : 0.42,
                    spawnsNote: false,
                    positionCallout: ""
                ))
            }
            return result
        }
    }

    static func cues(for intro: LessonIntro, usesLetters: Bool = AppLanguage.usesLetterNames) -> [LessonIntroCue] {
        switch intro {
        case .trebleOctave:
            let phase1 = String(localized: "A PAUTA")
            let phase2 = String(localized: "O DÓ CENTRAL")
            let phase3 = String(localized: "SUBINDO A ESCADA")
            let phase4 = String(localized: "UMA OITAVA")

            return [
                LessonIntroCue(
                    startTime: 0.0,
                    endTime: 4.2,
                    phaseNumber: 1,
                    phaseLabel: phase1,
                    title: String(localized: "Como começa a partitura"),
                    subtitle: String(localized: "A partitura começa com 5 linhas horizontais, sempre contadas de baixo para cima.")
                ),
                LessonIntroCue(
                    startTime: 4.2,
                    endTime: 8.0,
                    phaseNumber: 1,
                    phaseLabel: phase1,
                    title: String(localized: "Linhas e espaços são degraus"),
                    subtitle: String(localized: "Entre as linhas ficam 4 espaços. Cada linha e cada espaço funciona como meio degrau de altura.")
                ),
                LessonIntroCue(
                    startTime: 8.0,
                    endTime: 14.3,
                    phaseNumber: 2,
                    phaseLabel: phase2,
                    title: String(localized: "Onde nasce o Dó"),
                    subtitle: String(localized: "À esquerda das 2 teclas pretas fica o Dó. Na pauta, ele começa 2 degraus abaixo da 1ª linha, numa linha curta.")
                ),
                LessonIntroCue(
                    startTime: 14.3,
                    endTime: 17.8,
                    phaseNumber: 3,
                    phaseLabel: phase3,
                    title: String(localized: "Ré: subindo meia linha"),
                    subtitle: String(localized: "Apertando a próxima tecla branca, a nota sobe meio degrau e encosta logo abaixo da 1ª linha.")
                ),
                LessonIntroCue(
                    startTime: 17.8,
                    endTime: 21.2,
                    phaseNumber: 3,
                    phaseLabel: phase3,
                    title: String(localized: "Mi: em cima da 1ª linha"),
                    subtitle: String(localized: "Mais uma tecla para a direita e a nota sobe mais meia linha, pousando na 1ª linha.")
                ),
                LessonIntroCue(
                    startTime: 21.2,
                    endTime: 24.6,
                    phaseNumber: 3,
                    phaseLabel: phase3,
                    title: String(localized: "Fá: no 1º espaço"),
                    subtitle: String(localized: "A próxima tecla leva a nota para dentro do 1º espaço entre as linhas.")
                ),
                LessonIntroCue(
                    startTime: 24.6,
                    endTime: 28.0,
                    phaseNumber: 3,
                    phaseLabel: phase3,
                    title: String(localized: "Sol: na 2ª linha"),
                    subtitle: String(localized: "É a linha que a curva da Clave de Sol abraça — por isso ela tem esse nome.")
                ),
                LessonIntroCue(
                    startTime: 28.0,
                    endTime: 34.8,
                    phaseNumber: 3,
                    phaseLabel: phase3,
                    title: String(localized: "Lá e Si: linha e espaço"),
                    subtitle: String(localized: "Seguindo uma tecla por vez, o Lá entra no 2º espaço e o Si pousa na 3ª linha, bem no meio da pauta.")
                ),
                LessonIntroCue(
                    startTime: 34.8,
                    endTime: 39.0,
                    phaseNumber: 4,
                    phaseLabel: phase4,
                    title: String(localized: "Dó de novo: 1 oitava!"),
                    subtitle: String(localized: "No 3º espaço chegamos a outro Dó! De um Dó até o próximo são 8 teclas brancas: uma oitava.")
                ),
                LessonIntroCue(
                    startTime: 39.0,
                    endTime: 45.5,
                    phaseNumber: 4,
                    phaseLabel: phase4,
                    title: String(localized: "Uma nota por tecla"),
                    subtitle: String(localized: "Viu como é simples? Cada tecla branca vizinha sobe meio degrau na pauta. Agora é a sua vez!")
                ),
            ]
        }
    }

    /// Note label without octave number ("Dó", "Ré"... in Portuguese; "C", "D"... in English).
    static func shortNoteName(token: String, usesLetters: Bool = AppLanguage.usesLetterNames) -> String {
        guard let pitch = LessonNotation.pitch(from: token) else { return token }
        if usesLetters {
            return pitch.noteName.rawValue
        }
        switch pitch.noteName {
        case .C: return "Dó"
        case .D: return "Ré"
        case .E: return "Mi"
        case .F: return "Fá"
        case .G: return "Sol"
        case .A: return "Lá"
        case .B: return "Si"
        }
    }

    static func snapshot(for intro: LessonIntro, at rawTime: Double, usesLetters: Bool = AppLanguage.usesLetterNames) -> LessonIntroSnapshot {
        let total = duration(for: intro)
        let t = min(max(0, rawTime), total)
        let allCues = cues(for: intro, usesLetters: usesLetters)
        let activeCue = allCues.last { t >= $0.startTime } ?? allCues[0]
        let allPresses = presses(for: intro, usesLetters: usesLetters)
        let introPresses = allPresses.filter(\.spawnsNote)
        let finalePresses = allPresses.filter { !$0.spawnsNote }

        // 1. Five staff lines draw bottom-to-top between 0.3s and 3.5s
        let lineProgress = (0..<5).map { index -> Double in
            let start = 0.35 + Double(index) * 0.55
            return easeOut(progress(t, from: start, duration: 0.65))
        }

        // 2. Four spaces pulse gently between 4.4s and 6.4s, and glow when their note is introduced
        var spaceGlow = (0..<4).map { index -> Double in
            let waveStart = 4.4 + Double(index) * 0.36
            return bellCurve(t, start: waveStart, duration: 1.4) * 0.85
        }

        var lineGlow = Array(repeating: 0.0, count: 5)
        var belowLineSpaceGlow = 0.0

        // 3. Treble clef enters at 6.0s
        let clefProgress = easeOut(progress(t, from: 5.9, duration: 1.1))
        var clefLinePulse = bellCurve(t, start: 6.3, duration: 1.6) * 0.65

        // 4. Two-steps-below guide for Middle C (8.3s to 14.3s)
        let middleCGuideOpacity = smoothWindow(t, fadeInStart: 8.3, fadeInEnd: 9.1, fadeOutStart: 13.5, fadeOutEnd: 14.3)
        let twoBlackKeysGlow = smoothWindow(t, fadeInStart: 8.1, fadeInEnd: 8.7, fadeOutStart: 10.3, fadeOutEnd: 11.1)

        // 5. Notes on the staff & line/space highlights
        var activeCallout: (staffColumn: Int, staffPosition: Int, text: String, opacity: Double)?
        var stepUpIndicator: (fromColumn: Int, toColumn: Int, progress: Double)?
        var beam: (midi: Int, staffColumn: Int, staffPosition: Int, progress: Double)?
        var activeCyanKey: Int?
        var activeGreenKey: Int?

        var visibleNotes: [LessonIntroSnapshot.VisibleNote] = []
        for press in introPresses where t >= press.onset {
            let age = t - press.onset
            let appear = min(1.0, age / 0.42)
            let active = smoothWindow(t, fadeInStart: press.onset, fadeInEnd: press.onset + 0.12,
                                      fadeOutStart: press.onset + 2.4, fadeOutEnd: press.onset + 3.1)

            // Finale glow if the replay scale is hitting or has just hit this column
            var finale = 0.0
            if let replay = finalePresses.first(where: { $0.staffColumn == press.staffColumn }), t >= replay.onset {
                finale = smoothWindow(t, fadeInStart: replay.onset, fadeInEnd: replay.onset + 0.08,
                                      fadeOutStart: replay.onset + replay.holdDuration, fadeOutEnd: replay.onset + replay.holdDuration + 0.6)
            }

            visibleNotes.append(LessonIntroSnapshot.VisibleNote(
                id: press.staffColumn,
                midi: press.midi,
                staffPosition: press.staffPosition,
                name: shortNoteName(token: press.token, usesLetters: usesLetters),
                appearProgress: appear,
                activeGlow: active,
                finaleGlow: finale
            ))

            // Highlight corresponding staff line or space while active
            if active > 0.01 {
                switch press.staffPosition {
                case -5:
                    belowLineSpaceGlow = max(belowLineSpaceGlow, active)
                case -4, -2, 0, 2, 4:
                    let lineIdx = (press.staffPosition + 4) / 2
                    if lineGlow.indices.contains(lineIdx) {
                        lineGlow[lineIdx] = max(lineGlow[lineIdx], active)
                    }
                    if press.staffPosition == -2 {
                        clefLinePulse = max(clefLinePulse, active)
                    }
                case -3, -1, 1, 3:
                    let spaceIdx = (press.staffPosition + 3) / 2
                    if spaceGlow.indices.contains(spaceIdx) {
                        spaceGlow[spaceIdx] = max(spaceGlow[spaceIdx], active)
                    }
                default:
                    break
                }

                activeCallout = (press.staffColumn, press.staffPosition, press.positionCallout, active)
            }

            if age >= 0, age <= 0.75 {
                beam = (press.midi, press.staffColumn, press.staffPosition, age / 0.75)
            }
            if press.staffColumn > 0, age >= 0, age <= 1.8 {
                stepUpIndicator = (press.staffColumn - 1, press.staffColumn, easeOut(min(1, age / 0.55)) * (1 - max(0, (age - 1.2) / 0.6)))
            }
            if age >= 0, age <= press.holdDuration {
                activeCyanKey = press.midi
            }
        }

        for replay in finalePresses {
            let age = t - replay.onset
            if age >= 0, age <= replay.holdDuration {
                activeGreenKey = replay.midi
            }
        }

        let octaveArchProgress = smoothWindow(t, fadeInStart: 35.4, fadeInEnd: 36.3, fadeOutStart: 44.8, fadeOutEnd: 45.5)

        // 6. Motion-capture touch cursor position, press depth, and ripple
        let cursor = cursorState(at: t, introPresses: introPresses, finalePresses: finalePresses)

        return LessonIntroSnapshot(
            time: t,
            duration: total,
            cue: activeCue,
            totalPhases: 4,
            lineProgress: lineProgress,
            lineGlow: lineGlow,
            spaceGlow: spaceGlow,
            belowLineSpaceGlow: belowLineSpaceGlow,
            clefProgress: clefProgress,
            clefLinePulse: clefLinePulse,
            middleCGuideOpacity: middleCGuideOpacity,
            activeCallout: activeCallout,
            stepUpIndicator: stepUpIndicator,
            octaveArchProgress: octaveArchProgress,
            notes: visibleNotes,
            twoBlackKeysGlow: twoBlackKeysGlow,
            cursorOpacity: cursor.opacity,
            cursorMidiPosition: cursor.midiPosition,
            cursorPressDepth: cursor.pressDepth,
            ripple: cursor.ripple,
            activeCyanKey: activeCyanKey,
            activeGreenKey: activeGreenKey,
            beam: beam
        )
    }

    // MARK: - Cursor Kinematics

    private static func cursorState(
        at t: Double,
        introPresses: [LessonIntroPress],
        finalePresses: [LessonIntroPress]
    ) -> (opacity: Double, midiPosition: Double, pressDepth: Double, ripple: (midi: Int, progress: Double)?) {
        let all = introPresses + finalePresses
        guard let first = all.first, let last = all.last else {
            return (0, 60, 0, nil)
        }

        let fadeInStart = first.onset - 1.2
        let fadeOutEnd = last.onset + last.holdDuration + 0.8
        let opacity = smoothWindow(t, fadeInStart: fadeInStart, fadeInEnd: first.onset - 0.3,
                                   fadeOutStart: last.onset + last.holdDuration + 0.1, fadeOutEnd: fadeOutEnd)
        guard opacity > 0.001 else {
            return (0, Double(first.midi), 0, nil)
        }

        // Smoothly glide between consecutive strikes
        var midiPos = Double(first.midi)
        if t <= first.onset {
            // Glide in slightly from the right toward Middle C
            let glide = easeInOut(progress(t, from: fadeInStart, duration: first.onset - fadeInStart))
            midiPos = 64.0 + (Double(first.midi) - 64.0) * glide
        } else {
            for index in all.indices {
                let current = all[index]
                if index + 1 < all.count {
                    let next = all[index + 1]
                    if t >= current.onset && t < next.onset {
                        let gap = next.onset - current.onset
                        let moveDuration = min(0.65, gap * 0.42)
                        let moveStart = next.onset - moveDuration
                        if t <= moveStart {
                            midiPos = Double(current.midi)
                        } else {
                            let glide = easeInOut(progress(t, from: moveStart, duration: moveDuration))
                            midiPos = Double(current.midi) + Double(next.midi - current.midi) * glide
                        }
                        break
                    }
                } else if t >= current.onset {
                    midiPos = Double(current.midi)
                }
            }
        }

        // Press depth and touch ripple anchored on the struck key
        var pressDepth = 0.0
        var ripple: (midi: Int, progress: Double)?
        if let active = all.last(where: { t >= $0.onset }) {
            let age = t - active.onset
            if age <= active.holdDuration + 0.18 {
                let attack = min(1.0, age / 0.07)
                let release = age <= active.holdDuration ? 1.0 : max(0.0, 1.0 - (age - active.holdDuration) / 0.18)
                pressDepth = attack * release
            }
            if age >= 0, age <= 0.55 {
                ripple = (active.midi, age / 0.55)
            }
        }

        return (opacity, midiPos, pressDepth, ripple)
    }

    // MARK: - Easing Helpers

    private static func progress(_ t: Double, from start: Double, duration: Double) -> Double {
        guard duration > 0 else { return t >= start ? 1 : 0 }
        return min(1, max(0, (t - start) / duration))
    }

    private static func easeOut(_ x: Double) -> Double {
        1 - pow(1 - x, 3)
    }

    private static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    private static func bellCurve(_ t: Double, start: Double, duration: Double) -> Double {
        let p = progress(t, from: start, duration: duration)
        guard p > 0, p < 1 else { return 0 }
        return sin(p * .pi)
    }

    private static func smoothWindow(_ t: Double, fadeInStart: Double, fadeInEnd: Double,
                                     fadeOutStart: Double, fadeOutEnd: Double) -> Double {
        if t <= fadeInStart || t >= fadeOutEnd { return 0 }
        if t < fadeInEnd { return easeOut(progress(t, from: fadeInStart, duration: fadeInEnd - fadeInStart)) }
        if t > fadeOutStart { return 1 - easeInOut(progress(t, from: fadeOutStart, duration: fadeOutEnd - fadeOutStart)) }
        return 1
    }
}
