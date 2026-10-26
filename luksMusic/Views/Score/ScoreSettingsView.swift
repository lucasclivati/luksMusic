// ScoreSettingsView.swift
// luksMusic
//
// Authentic MuseScore Settings modal sheet.
// Controls Display Mode (Vertical Scroll, Single Line, Portrait View),
// HQ+ Sound toggle, Interactive Piano Keyboard toggle, and Semitone Transposition.

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
    
    // MuseScore Deep Purple Accent Color (#301a49)
    private let musePurple = Color(red: 48/255, green: 26/255, blue: 73/255)
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle Indicator
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 38, height: 4.5)
                .padding(.top, 10)
                .padding(.bottom, 12)
            
            // Modal Title
            Text("Settings")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(musePurple)
                .padding(.bottom, 18)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    
                    // MARK: - Section 1: DISPLAY MODE
                    VStack(alignment: .leading, spacing: 14) {
                        Text("DISPLAY MODE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.45))
                            .tracking(0.5)
                        
                        // Vertical Scroll Option
                        displayModeRow(
                            mode: .verticalScroll,
                            title: "Vertical Scroll",
                            iconName: "arrow.up.and.down"
                        )
                        
                        // Single Line Option
                        displayModeRow(
                            mode: .singleLine,
                            title: "Single Line",
                            iconName: "arrow.right.to.line"
                        )
                        
                        // Portrait View Option
                        displayModeRow(
                            mode: .portraitView,
                            title: "Portrait View",
                            iconName: "rectangle.portrait.fill"
                        )
                    }
                    
                    // MARK: - Section 2: MUSESCORE HQ+ SETTINGS
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MUSESCORE HQ+ SETTINGS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.45))
                            .tracking(0.5)
                            .padding(.bottom, 4)
                        
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sound")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Text("16-bit audio samples with modulation support")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.black.opacity(0.55))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $hqSoundEnabled)
                                .labelsHidden()
                                .tint(musePurple)
                                .onChange(of: hqSoundEnabled) { _, isEnabled in
                                    if isEnabled {
                                        AudioEngineService.shared.setReverb(0.25)
                                        AudioEngineService.shared.loadSoundFont(name: "Piano")
                                    } else {
                                        AudioEngineService.shared.setReverb(0.0)
                                    }
                                }
                        }
                    }
                    
                    // MARK: - Section 3: KEYBOARD
                    VStack(alignment: .leading, spacing: 6) {
                        Text("KEYBOARD")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.45))
                            .tracking(0.5)
                            .padding(.bottom, 4)
                        
                        HStack(alignment: .center) {
                            Text("Display Keyboard")
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Toggle("", isOn: $showKeyboard)
                                .labelsHidden()
                                .tint(musePurple)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    // MARK: - Section 4: TRANSPOSITION
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRANSPOSITION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.45))
                            .tracking(0.5)
                            .padding(.bottom, 2)
                        
                        HStack(alignment: .center) {
                            // Current Key Signature Text
                            Text(viewModel.transpositionKeyText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            // Stepper -
                            Button {
                                viewModel.transpositionSemitones -= 1
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 38)
                                    .background(Color.black.opacity(0.06))
                                    .clipShape(Circle())
                            }
                            
                            // Stepper +
                            Button {
                                viewModel.transpositionSemitones += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 38)
                                    .background(Color.black.opacity(0.06))
                                    .clipShape(Circle())
                            }
                            
                            // Default Reset Button
                            Button {
                                viewModel.transpositionSemitones = 0
                            } label: {
                                Text("Default")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background(Color.black.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .background(Color.white)
    }
    
    // MARK: - Custom Radio Row for Display Mode
    
    @ViewBuilder
    private func displayModeRow(mode: ScoreDisplayMode, title: String, iconName: String) -> some View {
        Button {
            displayMode = mode
        } label: {
            HStack(spacing: 14) {
                // Radio button circle
                ZStack {
                    Circle()
                        .stroke(displayMode == mode ? musePurple : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if displayMode == mode {
                        Circle()
                            .fill(musePurple)
                            .frame(width: 10, height: 10)
                    }
                }
                
                // Mode Title
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.black)
                
                Spacer()
                
                // Right Icon
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
