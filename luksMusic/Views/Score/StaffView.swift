// StaffView.swift
// luksMusic
//
// SwiftUI view rendering the piano grand staff (Treble + Bass staves, clefs, signatures).

import SwiftUI

struct StaffView: View {
    var lineSpacing: CGFloat = 12.0
    var keySignatureValue: Int = 0
    var timeSignatureTop: Int = 4
    var timeSignatureBottom: Int = 4
    var showClefsAndSignatures: Bool = true
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Grand staff left brace / bracket
            if showClefsAndSignatures {
                grandStaffBrace()
                    .frame(width: 14)
                
                // Clefs and signatures block
                VStack(spacing: lineSpacing * 3.5) {
                    clefAndSignatures(staff: .treble)
                    clefAndSignatures(staff: .bass)
                }
                .padding(.horizontal, 4)
            }
            
            // Empty Staff Lines Background
            VStack(spacing: lineSpacing * 3.5) {
                singleStaffLines()
                singleStaffLines()
            }
        }
    }
    
    // MARK: - Single 5-line staff
    
    @ViewBuilder
    private func singleStaffLines() -> some View {
        VStack(spacing: lineSpacing) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(height: 1)
            }
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Clef and Signatures
    
    @ViewBuilder
    private func clefAndSignatures(staff: Staff) -> some View {
        HStack(spacing: 6) {
            // Clef symbol
            Text(staff == .treble ? "𝄞" : "𝄢")
                .font(.system(size: staff == .treble ? lineSpacing * 3.8 : lineSpacing * 2.8))
                .foregroundColor(.primary)
                .offset(y: staff == .treble ? -lineSpacing * 0.2 : -lineSpacing * 0.1)
            
            // Key signature accidentals
            if keySignatureValue != 0 {
                renderKeySignatureAccidentals(staff: staff)
            }
            
            // Time signature
            VStack(spacing: -2) {
                Text("\(timeSignatureTop)")
                    .font(.system(size: lineSpacing * 1.6, weight: .bold))
                Text("\(timeSignatureBottom)")
                    .font(.system(size: lineSpacing * 1.6, weight: .bold))
            }
            .foregroundColor(.primary)
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Key Signature Accidentals
    
    @ViewBuilder
    private func renderKeySignatureAccidentals(staff: Staff) -> some View {
        HStack(spacing: 1) {
            let count = abs(keySignatureValue)
            let isSharp = keySignatureValue > 0
            ForEach(0..<min(7, count), id: \.self) { _ in
                Text(isSharp ? "♯" : "♭")
                    .font(.system(size: lineSpacing * 1.3, weight: .semibold))
                    .foregroundColor(.primary)
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
                path.move(to: CGPoint(x: w, y: 0))
                path.addCurve(
                    to: CGPoint(x: 2, y: h * 0.5),
                    control1: CGPoint(x: 4, y: h * 0.1),
                    control2: CGPoint(x: 2, y: h * 0.4)
                )
                path.addCurve(
                    to: CGPoint(x: w, y: h),
                    control1: CGPoint(x: 2, y: h * 0.6),
                    control2: CGPoint(x: 4, y: h * 0.9)
                )
            }
            .stroke(Color.primary, lineWidth: 2.5)
        }
        .frame(height: lineSpacing * 11.5)
    }
}
