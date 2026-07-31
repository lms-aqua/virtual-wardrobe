import SwiftUI

/// Reusable garment cell for the Wardrobe grid. Image-focused, calm, and
/// accessible. Uses the real garment's thumbnail when present, otherwise a
/// neutral tinted backdrop + category symbol (the catalog has no photos yet).
struct WardrobeItemCell: View {
    let garment: GarmentDTO

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.thumb, style: .continuous)
                    .fill(DS.Color.imageBackdrop)
                if let s = garment.thumbUrl, let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit().padding(DS.Space.m)
                        case .failure:
                            placeholder
                        default:
                            ProgressView()
                        }
                    }
                } else {
                    placeholder
                }
                if CustomGarments.isCustom(garment.id) {
                    badge("Yours")
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.thumb, style: .continuous))

            Text(garment.name).dsText(.itemTitle).lineLimit(1)
            Text(displayCategory).dsText(.itemMeta).lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var placeholder: some View {
        ZStack {
            GarmentAppearance.of(garment).color.opacity(0.22)
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(GarmentAppearance.of(garment).color)
        }
    }

    private func badge(_ text: String) -> some View {
        VStack {
            HStack {
                Spacer()
                Text(text).font(.caption2.bold()).foregroundStyle(.white)
                    .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xxs)
                    .background(DS.Color.accent, in: Capsule())
                    .padding(DS.Space.s)
            }
            Spacer()
        }
    }

    private var symbol: String {
        switch garment.category.lowercased() {
        case "dress": return "figure.dress.line.vertical.figure"
        case "bottom": return "figure.walk"
        case "outerwear": return "wind"
        case "footwear": return "shoe.2"
        default: return "tshirt.fill"
        }
    }

    private var displayCategory: String { garment.category.capitalized }

    private var accessibilityText: String {
        var parts = [garment.name, displayCategory]
        if CustomGarments.isCustom(garment.id) { parts.append("your own garment") }
        else if garment.brand != garment.name { parts.append("by \(garment.brand)") }
        if let p = garment.priceText { parts.append(p) }
        return parts.joined(separator: ", ")
    }
}
