// SheetCover.swift
// luksMusic
//
// Cover of a score in the library: a sheet of paper with the title engraved in a serif face over two grand
// staves, like the first page of a printed edition.

import SwiftUI

struct SheetCover: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            // Small covers (list rows) show only the staves
            let showsText = width >= 90

            VStack(spacing: 0) {
                if showsText {
                    Text(title)
                        .font(.system(size: max(10, width * 0.085), design: .serif))
                        .foregroundStyle(Color.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(.top, height * 0.1)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: max(7, width * 0.052), design: .serif))
                            .foregroundStyle(Color.black.opacity(0.6))
                            .lineLimit(1)
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 4)

                VStack(spacing: height * 0.07) {
                    grandStaff(lineGap: max(2, height * 0.018))
                    grandStaff(lineGap: max(2, height * 0.018))
                }
                .padding(.bottom, height * 0.09)
            }
            .padding(.horizontal, width * 0.09)
            .frame(width: width, height: height)
        }
        .background(Color.white)
        .accessibilityHidden(true)
    }

    private func grandStaff(lineGap: CGFloat) -> some View {
        VStack(spacing: lineGap * 2.2) {
            staff(lineGap: lineGap)
            staff(lineGap: lineGap)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 0.8)
        }
    }

    private func staff(lineGap: CGFloat) -> some View {
        VStack(spacing: lineGap) {
            ForEach(0..<5, id: \.self) { _ in
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .frame(height: 0.6)
            }
        }
    }
}
