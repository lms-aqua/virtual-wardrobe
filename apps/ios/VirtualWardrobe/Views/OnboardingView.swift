import SwiftUI

/// First-run walkthrough. Shown once (tracked in AppStorage).
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Slide: Identifiable {
        let id = UUID(); let icon: String; let title: String; let body: String
    }
    private let slides = [
        Slide(icon: "camera.viewfinder", title: "Guided 360° scan",
              body: "Stand back, tap start, and slowly turn a full circle. The app captures your body from every angle."),
        Slide(icon: "cube.transparent.fill", title: "A 3D avatar of you",
              body: "We build a rotatable 3D avatar from your measurements. Drag to spin, pinch to zoom."),
        Slide(icon: "tshirt.fill", title: "Try on clothes",
              body: "Tap garments to dress your avatar in 3D, save outfits, and compare looks."),
        Slide(icon: "lock.shield.fill", title: "Private by design",
              body: "Adults-only consent, private storage, no face recognition, and one-tap delete of everything."),
    ]

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            VStack {
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { i, s in
                        VStack(spacing: 20) {
                            Image(systemName: s.icon).font(.system(size: 72))
                                .foregroundStyle(Theme.accent)
                            Text(s.title).font(.title.bold()).foregroundStyle(.white)
                            Text(s.body).multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 32)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(page == slides.count - 1 ? "Get started" : "Next") {
                    if page == slides.count - 1 { dismiss() }
                    else { withAnimation { page += 1 } }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
        }
    }
}
