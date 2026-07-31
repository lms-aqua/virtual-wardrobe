import SwiftUI

/// Tune skin tone + body build; the 3D preview updates live. Saved to
/// UserDefaults and reflected everywhere the avatar is shown.
struct CustomizeView: View {
    @EnvironmentObject var session: AuthStore
    @StateObject private var controller = AvatarSceneController()
    @State private var measurements: MeasurementDTO?
    @State private var skinIndex = Customization.skinIndex
    @State private var build = Customization.build
    @State private var loading = true

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                AvatarSceneView(controller: controller)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                controls
            }
        }
        .navigationTitle("Customize")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skin tone").font(.subheadline.bold()).foregroundStyle(DS.Color.primaryText)
            HStack(spacing: 12) {
                ForEach(Array(Customization.skinTones.enumerated()), id: \.offset) { i, c in
                    Circle().fill(Color(c)).frame(width: 38, height: 38)
                        .overlay(Circle().stroke(skinIndex == i ? DS.Color.onAccent : .clear, lineWidth: 3))
                        .onTapGesture {
                            skinIndex = i; Customization.skinIndex = i; rebuild()
                        }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Body build").font(.subheadline.bold()).foregroundStyle(DS.Color.primaryText)
                HStack {
                    Text("Slim").font(.caption).foregroundStyle(DS.Color.secondaryText)
                    Slider(value: $build, in: 0.8...1.2)
                        .tint(Theme.accent)
                        .onChange(of: build) { Customization.build = build; rebuild() }
                    Text("Full").font(.caption).foregroundStyle(DS.Color.secondaryText)
                }
            }
            Text("A stylized preview shaped by your measurements — not a photo reconstruction.")
                .font(.caption2).foregroundStyle(DS.Color.secondaryText)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    private func load() async {
        measurements = (try? await session.api.avatars())?.first?.measurements
        loading = false
        rebuild()
    }

    private func rebuild() {
        controller.update(measurements: measurements, garments: [])
        session.pushPreferences()
    }
}
