import SwiftUI

/// Editorial garment detail — real catalog data, your recommended size, a
/// "Try on" action into the 3D builder, and a Buy link when the garment has one.
struct GarmentDetailView: View {
    let garment: GarmentDTO
    @EnvironmentObject var session: AuthStore
    @State private var measurements: MeasurementDTO?

    private var rec: SizeRecommender.Rec? {
        SizeRecommender.recommend(garment: garment, measurements: measurements)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                hero
                identity
                if !garment.sizes.isEmpty || rec != nil { sizes }
                if let urlStr = garment.productUrl, let url = URL(string: urlStr) { buy(url) }
            }
            .padding(DS.Space.l)
        }
        .background(DS.Color.grouped)
        .navigationTitle(garment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    OutfitBuilderView(initialGarmentIds: [garment.id])
                } label: { Label("Try on", systemImage: "cube.transparent") }
            }
        }
        .task { measurements = (try? await session.api.avatars())?.first?.measurements }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.container, style: .continuous)
                .fill(DS.Color.imageBackdrop)
            if let s = garment.thumbUrl, let url = URL(string: s) {
                AsyncImage(url: url) { $0.resizable().scaledToFit().padding(DS.Space.xxl) }
                placeholder: { ProgressView() }
            } else {
                GarmentAppearance.of(garment).color.opacity(0.20)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.container, style: .continuous))
                Image(systemName: "tshirt.fill").font(.largeTitle)
                    .foregroundStyle(GarmentAppearance.of(garment).color)
            }
        }
        .frame(height: 300)
        .accessibilityLabel("\(garment.name), \(garment.category.capitalized)")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                Text(garment.name).dsText(.sectionTitle)
                Spacer()
                if let p = garment.priceText { Text(p).dsText(.itemTitle) }
            }
            row("Brand", garment.brand)
            row("Category", garment.category.capitalized)
            if CustomGarments.isCustom(garment.id) {
                row("Source", "Added by you (try-on only)")
            }
        }
        .dsCard()
    }

    private var sizes: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Sizes").dsText(.itemTitle)
            if !garment.sizes.isEmpty {
                HStack(spacing: DS.Space.s) {
                    ForEach(garment.sizes, id: \.sizeLabel) { s in
                        Text(s.sizeLabel)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, DS.Space.m).padding(.vertical, DS.Space.xs)
                            .background(DS.Color.fill, in: Capsule())
                            .foregroundStyle(DS.Color.primaryText)
                    }
                }
            }
            if let rec {
                Label("Your size: \(rec.label) · \(rec.note)", systemImage: "checkmark.seal")
                    .font(.subheadline).foregroundStyle(DS.Color.accent)
            } else {
                Text("Add your measurements for a size recommendation.")
                    .dsText(.caption)
            }
        }
        .dsCard()
    }

    private func buy(_ url: URL) -> some View {
        Link(destination: url) {
            Label("Buy", systemImage: "bag")
        }
        .buttonStyle(DSPrimaryButton())
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).dsText(.itemMeta)
            Spacer()
            Text(value).dsText(.supporting).foregroundStyle(DS.Color.primaryText)
        }
    }
}
