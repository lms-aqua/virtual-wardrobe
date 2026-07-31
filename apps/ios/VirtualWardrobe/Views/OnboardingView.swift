import SwiftUI

/// First-run walkthrough. Shown once (tracked in AppStorage).
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0

    /// Scales the hero symbol with Dynamic Type instead of pinning it at 72pt.
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 72

    private struct Slide: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    // Terminology matches the rest of the product: Body Scan, Avatar, Try On.
    private let slides = [
        Slide(icon: "camera.viewfinder", title: "Guided Body Scan",
              body: "Stand back, tap start, and slowly turn a full circle. The app captures you from every angle."),
        Slide(icon: "cube.transparent.fill", title: "Your 3D Avatar",
              body: "We build a rotatable avatar from your measurements. Drag to spin, pinch to zoom."),
        Slide(icon: "tshirt.fill", title: "Try On Clothes",
              body: "Tap garments to dress your avatar in 3D, save outfits, and compare looks."),
        Slide(icon: "lock.shield.fill", title: "Private by Design",
              body: "Adults-only consent, private storage, no face recognition, and one-tap delete of everything."),
    ]

    private var isLast: Bool { page == slides.count - 1 }

    var body: some View {
        ZStack {
            DS.Color.grouped.ignoresSafeArea()

            VStack(spacing: 0) {
                skipBar
                pages
                primaryAction
            }
        }
    }

    // MARK: pieces

    /// An explicit way out. Previously the only path through was tapping Next
    /// four times.
    private var skipBar: some View {
        HStack {
            Spacer()
            Button("Skip") { finish() }
                .buttonStyle(DSTertiaryButton())
                .padding(.horizontal, DS.Space.screenMargin)
                .opacity(isLast ? 0 : 1)
                .disabled(isLast)
                .accessibilityHidden(isLast)
        }
    }

    private var pages: some View {
        TabView(selection: $page) {
            ForEach(Array(slides.enumerated()), id: \.element.id) { i, s in
                VStack(spacing: DS.Space.xl) {
                    Image(systemName: s.icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(DS.Color.accent)
                        .accessibilityHidden(true)   // decorative; the text carries it
                    Text(s.title)
                        .font(.title.bold())
                        .foregroundStyle(DS.Color.primaryText)
                        .multilineTextAlignment(.center)
                    Text(s.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DS.Color.secondaryText)
                        .padding(.horizontal, DS.Space.xxxl)
                }
                .padding(.horizontal, DS.Space.screenMargin)
                .tag(i)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(s.title). \(s.body)")
                .accessibilityHint("Step \(i + 1) of \(slides.count)")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var primaryAction: some View {
        Button(isLast ? "Get Started" : "Next") {
            if isLast {
                finish()
            } else {
                // Reduce Motion: advance immediately rather than sliding.
                withAnimation(DS.Motion.adaptive(DS.Motion.standard, reduceMotion: reduceMotion)) {
                    page += 1
                }
            }
        }
        .buttonStyle(DSPrimaryButton())
        .padding(DS.Space.screenMargin)
    }

    private func finish() {
        DS.Haptic.selection()
        dismiss()
    }
}

#if DEBUG
#Preview("Onboarding") {
    OnboardingView()
}

#Preview("Onboarding — dark") {
    OnboardingView().preferredColorScheme(.dark)
}

#Preview("Onboarding — accessibility XXXL") {
    OnboardingView().environment(\.dynamicTypeSize, .accessibility3)
}
#endif
