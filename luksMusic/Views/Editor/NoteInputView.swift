// NoteInputView.swift
// luksMusic
//
// Step-input piano keyboard for composing and inserting notes directly onto the score.

import SwiftUI

struct NoteInputView: View {
    @Bindable var viewModel: EditorViewModel
    
    // 2-octave input range: C3 to B4 for step input
    private let whiteNotes: [(NoteName, Int)] = [
        (.C, 3), (.D, 3), (.E, 3), (.F, 3), (.G, 3), (.A, 3), (.B, 3),
        (.C, 4), (.D, 4), (.E, 4), (.F, 4), (.G, 4), (.A, 4), (.B, 4),
        (.C, 5)
    ]
    
    var body: some View {
        GeometryReader { geo in
            let keyWidth = geo.size.width / CGFloat(whiteNotes.count)
            let keyHeight = geo.size.height
            
            ZStack(alignment: .topLeading) {
                // White Keys
                HStack(spacing: 1) {
                    ForEach(0..<whiteNotes.count, id: \.self) { i in
                        let (name, octave) = whiteNotes[i]
                        Button {
                            insertPitch(noteName: name, octave: octave)
                        } label: {
                            VStack {
                                Spacer()
                                Text("\(name.rawValue)\(octave)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.6))
                                    .padding(.bottom, 6)
                            }
                            .frame(width: keyWidth - 1, height: keyHeight)
                            .background(Color.white)
                            .cornerRadius(4)
                        }
                    }
                }
                
                // Black Keys
                ForEach(0..<whiteNotes.count - 1, id: \.self) { i in
                    let (name, octave) = whiteNotes[i]
                    if hasBlackKeyAfter(name: name) {
                        let blackX = CGFloat(i + 1) * keyWidth - (keyWidth * 0.35)
                        Button {
                            insertPitch(noteName: name, octave: octave, accidental: .sharp)
                        } label: {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: keyWidth * 0.7, height: keyHeight * 0.6)
                                .cornerRadius(3)
                        }
                        .offset(x: blackX)
                    }
                }
            }
        }
        .frame(height: 120)
        .background(Color(.systemGray4))
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }
    
    private func hasBlackKeyAfter(name: NoteName) -> Bool {
        name != .E && name != .B
    }
    
    private func insertPitch(noteName: NoteName, octave: Int, accidental: Accidental = .natural) {
        let appliedAccidental = (accidental != .natural) ? accidental : viewModel.selectedAccidental
        let pitch = Pitch(noteName: noteName, octave: octave, accidental: appliedAccidental)
        viewModel.insertNote(pitch: pitch)
    }
}
