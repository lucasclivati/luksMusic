// StaffView.swift
// luksMusic
//
// SwiftUI view rendering the piano grand staff (Treble + Bass staves, clefs, signatures, and brace).

import SwiftUI

struct StaffView: View {
    var lineSpacing: CGFloat = 12.0
    var keySignatureValue: Int = -3 // C Minor (3 flats: Bb, Eb, Ab)
    var timeSignatureTop: Int = 4
    var timeSignatureBottom: Int = 4
    var showClefsAndSignatures: Bool = true
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Grand staff left brace / bracket
            if showClefsAndSignatures {
                grandStaffBrace()
                    .frame(width: 16)
                
                // Clefs and signatures block
                VStack(spacing: lineSpacing * 3.5) {
                    clefAndSignatures(staff: .treble)
                    clefAndSignatures(staff: .bass)
                }
                .padding(.horizontal, 6)
            }
            
            // Continuous 5-line staff backdrop
            VStack(spacing: lineSpacing * 3.5) {
                singleStaffLines()
                singleStaffLines()
            }
            .frame(width: 8)
        }
    }
    
    // MARK: - Single 5-line staff
    
    @ViewBuilder
    private func singleStaffLines() -> some View {
        VStack(spacing: lineSpacing) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 1.2)
            }
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Clef and Signatures
    
    @ViewBuilder
    private func clefAndSignatures(staff: Staff) -> some View {
        ZStack(alignment: .leading) {
            // Background staff lines behind clef
            singleStaffLines()
            
            HStack(spacing: 8) {
                // Clef symbol
                Text(staff == .treble ? "𝄞" : "𝄢")
                    .font(.system(size: staff == .treble ? lineSpacing * 3.8 : lineSpacing * 2.8))
                    .foregroundColor(.black)
                    .offset(y: staff == .treble ? -lineSpacing * 0.25 : -lineSpacing * 0.1)
                
                // Key signature accidentals placed on authentic staff lines/spaces
                renderKeySignatureAccidentals(staff: staff)
                    .foregroundColor(.black)
                
                // Time signature
                VStack(spacing: -1) {
                    Text("\(timeSignatureTop)")
                        .font(.system(size: lineSpacing * 1.5, weight: .bold, design: .serif))
                    Text("\(timeSignatureBottom)")
                        .font(.system(size: lineSpacing * 1.5, weight: .bold, design: .serif))
                }
                .foregroundColor(.black)
            }
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Key Signature Accidentals
    
    @ViewBuilder
    private func renderKeySignatureAccidentals(staff: Staff) -> some View {
        HStack(spacing: 3) {
            if keySignatureValue == -3 || keySignatureValue == -2 {
                // 1st flat: B♭
                Text("♭")
                    .font(.system(size: lineSpacing * 1.5, weight: .bold))
                    .offset(y: staff == .treble ? 0 : lineSpacing * 1.0) // Line 3 for treble, Line 2 for bass
                
                // 2nd flat: E♭
                Text("♭")
                    .font(.system(size: lineSpacing * 1.5, weight: .bold))
                    .offset(y: staff == .treble ? -lineSpacing * 1.5 : -lineSpacing * 0.5) // Space 4 for treble, Space 3 for bass
                
                if keySignatureValue == -3 {
                    // 3rd flat: A♭
                    Text("♭")
                        .font(.system(size: lineSpacing * 1.5, weight: .bold))
                        .offset(y: staff == .treble ? lineSpacing * 0.5 : lineSpacing * 2.0) // Space 2 for treble, Line 1 for bass
                }
            } else if keySignatureValue != 0 {
                // Generic fallback for other keys
                let count = abs(keySignatureValue)
                let isSharp = keySignatureValue > 0
                ForEach(0..<min(7, count), id: \.self) { _ in
                    Text(isSharp ? "♯" : "♭")
                        .font(.system(size: lineSpacing * 1.4, weight: .bold))
                }
            }
        }
    }
    
    // MARK: - Grand Staff Brace
    
    @ViewBuilder
    private func grandStaffBrace() -> some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                let midY = h * 0.5
                
                // Vertical connecting bar
                path.move(to: CGPoint(x: w - 2, y: 0))
                path.addLine(to: CGPoint(x: w - 2, y: h))
                
                // Classic curly piano brace
                path.move(to: CGPoint(x: w - 2, y: 0))
                path.addCurve(
                    to: CGPoint(x: 2, y: midY),
                    control1: CGPoint(x: 6, y: h * 0.15),
                    control2: CGPoint(x: 2, y: h * 0.35)
                )
                path.addCurve(
                    to: CGPoint(x: w - 2, y: h),
                    control1: CGPoint(x: 2, y: h * 0.65),
                    control2: CGPoint(x: 6, y: h * 0.85)
                )
            }
            .stroke(Color.black, lineWidth: 2)
        }
    }
}
