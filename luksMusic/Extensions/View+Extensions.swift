// View+Extensions.swift
// luksMusic
//
// Reusable SwiftUI view modifiers for the luksMusic app.

import SwiftUI

// MARK: - Glow Effect

extension View {

    /// Adds a soft glow around the view, useful for key highlighting.
    /// - Parameters:
    ///   - color: The glow color.
    ///   - radius: Blur radius of the glow.
    func glowEffect(color: Color = .accentIndigo, radius: CGFloat = 8) -> some View {
        self
            .shadow(color: color.opacity(0.6), radius: radius / 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 2)
    }

    /// Applies a dark card style with rounded corners.
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }

    /// Fades edges of a scroll view for a polished look.
    /// - Parameter edges: Which edges to fade.
    func fadeEdges(_ edges: Edge.Set = .horizontal) -> some View {
        self.mask(
            HStack(spacing: 0) {
                if edges.contains(.leading) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 20)
                }

                Color.black

                if edges.contains(.trailing) {
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 20)
                }
            }
        )
    }

    /// Triggers haptic feedback.
    /// - Parameter style: The feedback style intensity.
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }

    /// Animates the view in with a staggered offset and opacity.
    /// - Parameters:
    ///   - delay: Delay before the animation starts.
    ///   - offset: Initial Y offset.
    func animateOnAppear(delay: Double = 0, offset: CGFloat = 20) -> some View {
        modifier(StaggeredAppearModifier(delay: delay, offset: offset))
    }
}

// MARK: - Staggered Appear Modifier

/// A view modifier that animates content in with a fade + slide.
private struct StaggeredAppearModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : offset)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Conditional Modifier

extension View {

    /// Applies a modifier only when the condition is true.
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Toolbar Button Style

/// A consistent button style for toolbar/palette buttons.
struct ToolbarButtonStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                isSelected
                    ? Color.accentIndigo.opacity(0.3)
                    : Color.backgroundSecondary
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentIndigo : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
