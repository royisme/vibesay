import SwiftUI

/// A centralized design system for Hex (Developer Edition).
enum HexDesign {
    enum Colors {
        static let background = Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)) // VSCode-ish Dark
        static let secondaryBackground = Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1.0))
        static let border = Color(nsColor: NSColor(red: 0.25, green: 0.25, blue: 0.26, alpha: 1.0))

        static let accent = Color(nsColor: NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)) // System Blue
        static let success = Color(nsColor: NSColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0))
        static let warning = Color(nsColor: NSColor(red: 0.8, green: 0.5, blue: 0.1, alpha: 1.0))
        static let error = Color(nsColor: NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0))

        static let textPrimary = Color.white
        static let textSecondary = Color.gray
    }

    enum Fonts {
        static func code(size: CGFloat = 13) -> Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }

        static func ui(size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static let recordingStatus = Font.system(size: 12, weight: .bold, design: .monospaced)
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
    }

    static let cornerRadius: CGFloat = 8.0
}

struct HexPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(HexDesign.Colors.background)
            .cornerRadius(HexDesign.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: HexDesign.cornerRadius)
                    .stroke(HexDesign.Colors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func hexPanel() -> some View {
        modifier(HexPanelStyle())
    }
}
