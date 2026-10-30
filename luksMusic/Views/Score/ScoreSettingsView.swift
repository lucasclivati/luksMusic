// ScoreSettingsView.swift
// luksMusic
//
// The score's settings sheet: how the engraving is laid out, the piano's room sound, the keyboard,
// and transposition by semitones.

import SwiftUI

enum ScoreDisplayMode: String, CaseIterable {
    case verticalScroll = "Vertical Scroll"
    case singleLine = "Single Line"
    case portraitView = "Portrait View"
}

struct ScoreSettingsView: View {
    @Bindable var viewModel: ScoreViewModel
    @Binding var displayMode: ScoreDisplayMode
    @Binding var hqSoundEnabled: Bool
    @Binding var showKeyboard: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(PlayerTheme.border)
                .frame(width: 38, height: 4.5)
                .padding(.top, 10)
                .padding(.bottom, 12)

            Text("Configurações")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PlayerTheme.text)
                .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    section("EXIBIÇÃO") {
                        displayModeRow(mode: .verticalScroll, title: "Página", detail: "Dois compassos por linha", iconName: "doc.text")
                        displayModeRow(mode: .portraitView, title: "Ampliada", detail: "Um compasso por linha, notas maiores", iconName: "rectangle.portrait")
                        displayModeRow(mode: .singleLine, title: "Linha única", detail: "A partitura corre para o lado", iconName: "arrow.right.to.line")
                    }

                    section("SOM") {
                        toggleRow(title: "Sala de concerto", detail: "Reverberação no som do piano", isOn: $hqSoundEnabled)
                            .onChange(of: hqSoundEnabled) { _, isEnabled in
                                if isEnabled {
                                    AudioEngineService.shared.setReverb(0.25)
                                    AudioEngineService.shared.loadSoundFont(name: "Piano")
                                } else {
                                    AudioEngineService.shared.setReverb(0.0)
                                }
                            }
                    }

                    section("TECLADO") {
                        toggleRow(title: "Mostrar teclado", detail: "As teclas sob o cursor acendem", isOn: $showKeyboard)
                            .accessibilityIdentifier("displayKeyboardToggle")
                    }

                    section("TRANSPOSIÇÃO") {
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.transpositionKeyText)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PlayerTheme.text)
                                Text(transpositionDetail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PlayerTheme.muted)
                            }

                            Spacer()

                            stepButton("minus", label: "Meio tom abaixo") {
                                viewModel.transpositionSemitones -= 1
                            }
                            stepButton("plus", label: "Meio tom acima") {
                                viewModel.transpositionSemitones += 1
                            }

                            Button("Original") {
                                viewModel.transpositionSemitones = 0
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PlayerTheme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(PlayerTheme.raised, in: Capsule())
                            .disabled(viewModel.transpositionSemitones == 0)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .background(PlayerTheme.panel.ignoresSafeArea())
    }

    private var transpositionDetail: String {
        switch viewModel.transpositionSemitones {
        case 0: return "Tom original"
        case 1: return "1 semitom acima"
        case -1: return "1 semitom abaixo"
        case let n where n > 0: return "\(n) semitons acima"
        case let n: return "\(-n) semitons abaixo"
        }
    }

    // MARK: - Rows

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PlayerTheme.muted)
                .tracking(0.5)
            content()
        }
    }

    private func displayModeRow(mode: ScoreDisplayMode, title: String, detail: String, iconName: String) -> some View {
        Button {
            displayMode = mode
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(displayMode == mode ? PlayerTheme.blue : PlayerTheme.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if displayMode == mode {
                        Circle()
                            .fill(PlayerTheme.blue)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PlayerTheme.text)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(PlayerTheme.muted)
                }

                Spacer()

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PlayerTheme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PlayerTheme.text)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(PlayerTheme.muted)
            }
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(PlayerTheme.blue)
        }
    }

    private func stepButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PlayerTheme.text)
                .frame(width: 40, height: 36)
                .background(PlayerTheme.raised, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
