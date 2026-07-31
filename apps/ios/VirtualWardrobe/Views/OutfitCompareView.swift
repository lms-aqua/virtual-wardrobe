import SwiftUI

/// Compare two saved outfits side-by-side on your avatar in 3D.
struct OutfitCompareView: View {
    @EnvironmentObject var session: AuthStore
    @StateObject private var left = AvatarSceneController()
    @StateObject private var right = AvatarSceneController()

    @State private var outfits: [OutfitDTO] = []
    @State private var catalog: [GarmentDTO] = []
    @State private var measurements: MeasurementDTO?
    @State private var selA: OutfitDTO?
    @State private var selB: OutfitDTO?
    @State private var loading = true

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else if outfits.count < 2 {
                VStack(spacing: 10) {
                    Image(systemName: "square.on.square").font(.system(size: 40)).foregroundStyle(Theme.accent)
                    Text("Save at least two outfits to compare them.")
                        .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
                }.padding()
            } else {
                HStack(spacing: 0) {
                    pane(title: "A", selection: $selA, controller: left)
                    Divider().overlay(Color.white.opacity(0.2))
                    pane(title: "B", selection: $selB, controller: right)
                }
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func pane(title: String, selection: Binding<OutfitDTO?>,
                      controller: AvatarSceneController) -> some View {
        VStack(spacing: 8) {
            Menu {
                ForEach(outfits) { o in
                    Button(o.name) { selection.wrappedValue = o; apply(o, to: controller) }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue?.name ?? "Outfit \(title)")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                    Image(systemName: "chevron.down").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
            AvatarSceneView(controller: controller)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func garments(for outfit: OutfitDTO) -> [GarmentDTO] {
        outfit.items.compactMap { item in catalog.first { $0.id == item.garmentId } }
    }

    private func apply(_ outfit: OutfitDTO, to controller: AvatarSceneController) {
        controller.update(measurements: measurements, garments: garments(for: outfit))
    }

    private func load() async {
        outfits = (try? await session.api.outfits()) ?? []
        catalog = (try? await session.api.garments()) ?? []
        measurements = (try? await session.api.avatars())?.first?.measurements
        loading = false
        if outfits.indices.contains(0) { selA = outfits[0]; apply(outfits[0], to: left) }
        if outfits.indices.contains(1) { selB = outfits[1]; apply(outfits[1], to: right) }
    }
}
