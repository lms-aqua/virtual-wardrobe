import SwiftUI

/// Central design system so the app reads as one polished, branded product.
enum Theme {
    static let accent = Color(red: 0.43, green: 0.37, blue: 0.99)   // #6d5efc
    static let accent2 = Color(red: 0.86, green: 0.42, blue: 0.98)  // pink-violet
    static let ink = Color(red: 0.043, green: 0.043, blue: 0.07)    // #0b0b12
    static let card = Color.white.opacity(0.06)
    static let stroke = Color.white.opacity(0.10)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [ink, Color(red: 0.10, green: 0.08, blue: 0.20), ink],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
    }
}

/// A frosted, rounded container used throughout the app.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Large, primary gradient button with a big touch target (accessibility).
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(
                Theme.brandGradient.opacity(enabled ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
