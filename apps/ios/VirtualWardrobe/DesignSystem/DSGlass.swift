import SwiftUI

// MARK: - Availability-safe Liquid Glass
//
// `.glassEffect(_:in:)` and `GlassEffectContainer` ship in the iOS 26 SDK.
// An `#available` check gates *runtime* behavior, not symbol resolution — so
// the real call also has to sit behind `#if compiler(>=6.2)` (Xcode 26 / Swift
// 6.2) or the app fails to compile on older toolchains entirely.
//
// CI runs `macos-15` (Xcode 16 / iOS 18 SDK) today, so this currently resolves
// to the material fallback. Bumping the runner to `macos-26` lights up true
// Liquid Glass with no source changes and no deployment-target raise.
//
// Both paths share hierarchy, spacing, shape language, and behavior — the
// fallback is a designed state, not a degraded one.

/// Glass is an *interaction* layer: toolbars, floating controls, overlays on
/// top of a garment or avatar stage. It is never the default content
/// background.
struct DSGlassBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    /// Tints the surface toward the accent for selected/active controls.
    var active: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            // Reduce Transparency: solid surface, clear boundary, same shape.
            // Glass effects are never allowed to reduce usability.
            content
                .background(active ? DS.Color.accent.opacity(0.18) : DS.Color.raised, in: shape)
                .overlay(shape.strokeBorder(DS.Color.separator, lineWidth: 0.5))
        } else {
            glassed(content)
        }
    }

    @ViewBuilder
    private func glassed(_ content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(active ? .regular.tint(DS.Color.accent) : .regular, in: shape)
        } else {
            material(content)
        }
        #else
        material(content)
        #endif
    }

    /// iOS 17–18 fallback: system material with a hairline edge so the control
    /// still reads as a distinct floating surface in both appearances.
    private func material(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay { if active { shape.fill(DS.Color.accent.opacity(0.14)) } }
            .overlay(shape.strokeBorder(DS.Color.separator.opacity(0.6), lineWidth: 0.5))
    }
}

extension View {
    /// Apply the glass interaction surface in a given shape.
    func dsGlass<S: InsettableShape>(in shape: S, active: Bool = false) -> some View {
        modifier(DSGlassBackground(shape: shape, active: active))
    }

    /// Convenience: capsule glass, the default for compact control clusters.
    func dsGlassCapsule(active: Bool = false) -> some View {
        modifier(DSGlassBackground(shape: Capsule(), active: active))
    }
}

// MARK: - Glass container
//
// Groups nearby glass controls so they blend and morph as one unit instead of
// stacking independent blur layers on top of each other.

struct DSGlassGroup<Content: View>: View {
    var spacing: CGFloat = DS.Space.s
    @ViewBuilder var content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Floating action control
//
// The one custom glass control on the Wardrobe screen: a floating "Add
// Garment" action over the grid. Justified because it keeps the primary action
// reachable at the thumb while the garment images stay visually dominant.

struct DSFloatingActionControl: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .dsText(.button)
                .foregroundStyle(DS.Color.accent)
                .padding(.horizontal, DS.Space.xl)
                .frame(minHeight: DS.Size.controlProminent)
        }
        .dsGlassCapsule()
        // Soft, appearance-aware elevation — never a hard black shadow.
        .shadow(color: .black.opacity(reduceTransparency ? 0.10 : 0.16), radius: 12, y: 4)
        .accessibilityLabel(title)
    }
}
