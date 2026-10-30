// StaffView.swift
// luksMusic
//
// SwiftUI view rendering the piano grand staff (Treble + Bass staves, clefs, signatures, and brace).

import SwiftUI

struct StaffView: View {
    var lineSpacing: CGFloat = 6.4
    var keySignatureValue: Int = -3 // C Minor (3 flats: Bb, Eb, Ab)
    var timeSignatureTop: Int = 4
    var timeSignatureBottom: Int = 4
    var showClefsAndSignatures: Bool = true
    var showTimeSignature: Bool = true
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Grand staff left brace / bracket
            if showClefsAndSignatures {
                grandStaffBrace()
                    .frame(width: 10)
                
                // Clefs and signatures block
                VStack(spacing: lineSpacing * 3.5) {
                    clefAndSignatures(staff: .treble)
                    clefAndSignatures(staff: .bass)
                }
                .padding(.horizontal, 2)
            }
            
            // Continuous 5-line staff backdrop, filling any room left up to the first measure
            VStack(spacing: lineSpacing * 3.5) {
                singleStaffLines()
                singleStaffLines()
            }
            .frame(minWidth: 3, maxWidth: .infinity)
        }
    }
    
    // MARK: - Single 5-line staff
    
    @ViewBuilder
    private func singleStaffLines() -> some View {
        VStack(spacing: lineSpacing) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 1.1)
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
            
            HStack(spacing: 5) {
                // Clef symbol
                Text(staff == .treble ? "𝄞" : "𝄢")
                    .font(.system(size: staff == .treble ? lineSpacing * 3.6 : lineSpacing * 2.7))
                    .foregroundColor(.black)
                    .offset(y: staff == .treble ? -lineSpacing * 0.22 : -lineSpacing * 0.1)
                
                // Key signature accidentals placed on authentic staff lines/spaces
                renderKeySignatureAccidentals(staff: staff)
                    .foregroundColor(.black)
                
                // Time signature (shown only on measure 1)
                if showTimeSignature {
                    VStack(spacing: -1) {
                        Text("\(timeSignatureTop)")
                            .font(.system(size: lineSpacing * 1.5, weight: .bold, design: .serif))
                        Text("\(timeSignatureBottom)")
                            .font(.system(size: lineSpacing * 1.5, weight: .bold, design: .serif))
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .frame(height: lineSpacing * 4)
    }
    
    // MARK: - Key Signature Accidentals

    /// Staff steps above the bottom line for each accidental, in key-signature order.
    private func accidentalSteps(staff: Staff, sharps: Bool) -> [Int] {
        switch (staff, sharps) {
        case (.treble, true): return [8, 5, 9, 6, 3, 7, 4]   // F C G D A E B
        case (.treble, false): return [4, 7, 3, 6, 2, 5, 1]  // B E A D G C F
        case (.bass, true): return [6, 3, 7, 4, 1, 5, 2]
        case (.bass, false): return [2, 5, 1, 4, 0, 3, -1]
        }
    }

    @ViewBuilder
    private func renderKeySignatureAccidentals(staff: Staff) -> some View {
        let isSharp = keySignatureValue > 0
        let steps = accidentalSteps(staff: staff, sharps: isSharp)
        HStack(spacing: 2) {
            ForEach(0..<min(7, abs(keySignatureValue)), id: \.self) { i in
                // Step 4 is the middle line, where the staff block is centered
                Text(isSharp ? "♯" : "♭")
                    .font(.system(size: lineSpacing * 1.45, weight: .bold))
                    .offset(y: -CGFloat(steps[i] - 4) * lineSpacing * 0.5)
            }
        }
    }

    /// Width the brace, clef, key signature and optional time signature need at this staff size.
    static func preferredWidth(lineSpacing: CGFloat, keySignatureValue: Int, showTimeSignature: Bool) -> CGFloat {
        let accidentals = CGFloat(min(7, abs(keySignatureValue)))
        let timeSignature = showTimeSignature ? lineSpacing * 1.4 + 5 : 0
        return 10 + 4 + lineSpacing * 2.6 + 5 + accidentals * (lineSpacing * 0.9 + 2) + timeSignature + 8
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
                    control1: CGPoint(x: 5, y: h * 0.15),
                    control2: CGPoint(x: 2, y: h * 0.35)
                )
                path.addCurve(
                    to: CGPoint(x: w - 2, y: h),
                    control1: CGPoint(x: 2, y: h * 0.65),
                    control2: CGPoint(x: 5, y: h * 0.85)
                )
            }
            .stroke(Color.black, lineWidth: 1.8)
        }
    }
}
