import SwiftUI

enum DS {
    static let corner: CGFloat = 14
    static let cornerSmall: CGFloat = 10

    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 14
        static let l: CGFloat = 18
        static let xl: CGFloat = 24
    }

    enum Shadow {
        static func card(_ isHovered: Bool) -> (Color, CGFloat, CGFloat, CGFloat) {
            // Subtle elevation, slightly stronger on hover.
            let base = isHovered ? 0.22 : 0.14
            return (Color.black.opacity(base), isHovered ? 16 : 12, 0, isHovered ? 8 : 5)
        }
    }

    enum Surface {
        static var appBackground: Color { Color(nsColor: .windowBackgroundColor) }
        static var panelBackground: Color { Color(nsColor: .underPageBackgroundColor) }
        static var card: Color { Color(nsColor: .controlBackgroundColor).opacity(0.92) }
        static var cardHover: Color { Color(nsColor: .controlBackgroundColor).opacity(0.98) }
        static var hairline: Color { Color.white.opacity(0.06) }
        static var hairlineStrong: Color { Color.white.opacity(0.10) }
    }
}

struct HoverLift: ViewModifier {
    @State private var isHovered = false
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isHovered)
            .onHover { hovering in
                guard enabled else { return }
                isHovered = hovering
            }
    }
}

extension View {
    func hoverLift(_ enabled: Bool = true) -> some View {
        modifier(HoverLift(enabled: enabled))
    }
}

