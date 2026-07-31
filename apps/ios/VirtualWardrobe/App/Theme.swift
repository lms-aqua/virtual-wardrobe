import SwiftUI

/// Compatibility shim over `DS` (see `DesignSystem/DS.swift`).
///
/// `Theme` was the original dark-only, gradient-based design system. Rather than
/// rewriting 20+ screens in one pass, its tokens are now *defined in terms of*
/// the semantic `DS` palette, so every existing call site adapts to Light/Dark,
/// Increased Contrast and tinting for free. In dark appearance the values land
/// close to the originals, so on its own this is a near-invisible change.
///
/// Every member is a concrete `Color`, which is both a `View` and a
/// `ShapeStyle` — so existing `.ignoresSafeArea()`, `.stroke(_:)` and
/// `.background(_:in:)` call sites keep compiling untouched.
///
/// New code should use `DS` directly. This exists only so the remaining screens
/// keep building while they migrate, and it shrinks as they do.
enum Theme {
    /// Brand accent, unchanged (#6d5efc) — `DS.Color.accent` is the same value.
    static let accent: Color = DS.Color.accent

    /// Secondary brand tone. Retained for the few call sites that still name it;
    /// it no longer builds gradients.
    static let accent2 = Color(red: 0.86, green: 0.42, blue: 0.98)

    /// Was a fixed near-black (#0b0b12). Now the semantic app background.
    static let ink: Color = DS.Color.appBackground

    /// Was `white.opacity(0.06)`, which is invisible on a light background.
    static let card: Color = DS.Color.raised

    /// Was `white.opacity(0.10)` — same problem.
    static let stroke: Color = DS.Color.separator

    /// Was a decorative purple gradient painted full-screen across 18 screens.
    /// v2.0 puts content on system backgrounds instead, so this is now a flat
    /// semantic surface. The name is kept so call sites need no edit.
    static var backgroundGradient: Color { DS.Color.grouped }

    /// Was an accent→pink gradient used as a fill and a stroke. v2.0 bans
    /// decorative gradients, so it resolves to the flat accent.
    static var brandGradient: Color { DS.Color.accent }

    /// The one place a gradient still earns its keep: seating a 3D avatar or a
    /// garment on a neutral stage.
    static var studioBackground: some View { DSStudioBackground() }
}

/// A rounded content container. Now a semantic surface rather than a
/// translucent white wash, so it renders correctly in both appearances.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.Space.l)
            .background(DS.Color.raised,
                        in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Primary action button. The gradient fill is gone — v2.0 bans gradient buttons
/// throughout — so this delegates to the design system's style and is now
/// visually identical to every other primary button in the app.
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        DSPrimaryButton(enabled: enabled).makeBody(configuration: configuration)
    }
}
