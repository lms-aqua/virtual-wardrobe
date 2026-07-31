import SwiftUI

/// Browse the catalog with prices, your recommended size, and buy links.
struct ShopView: View {
    @EnvironmentObject var session: AuthStore
    @State private var garments: [GarmentDTO] = []
    @State private var measurements: MeasurementDTO?
    @State private var loading = true

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(garments) { g in row(g) }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(_ g: GarmentDTO) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12).fill(GarmentAppearance.of(g).color)
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "tshirt.fill").foregroundStyle(.white.opacity(0.85)))
            VStack(alignment: .leading, spacing: 3) {
                Text(g.name).font(.subheadline.bold()).foregroundStyle(.white)
                Text(g.brand).font(.caption).foregroundStyle(.white.opacity(0.6))
                if let rec = SizeRecommender.recommend(garment: g, measurements: measurements) {
                    Text("Your size: \(rec.label) · \(rec.note)")
                        .font(.caption2).foregroundStyle(Theme.accent2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let price = g.priceText {
                    Text(price).font(.subheadline.bold()).foregroundStyle(.white)
                }
                if let urlStr = g.productUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Text("Buy").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Theme.accent, in: Capsule())
                    }
                }
            }
        }
        .card()
    }

    private func load() async {
        garments = (try? await session.api.garments()) ?? []
        measurements = (try? await session.api.avatars())?.first?.measurements
        loading = false
    }
}
