import SwiftUI
import UIKit

/// Reusable garment cell for the Wardrobe grid.
///
/// The garment image is the subject; everything else is quiet support. Uses the
/// real thumbnail when present, otherwise a neutral backdrop + category symbol
/// tinted from the garment's own appearance (the catalog has no photos yet).
struct WardrobeItemCell: View {
    let garment: GarmentDTO
    var isFavorite: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            thumbnail
            Text(garment.name)
                .dsText(.itemTitle)
                .lineLimit(2)                       // names wrap rather than truncate
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(displayCategory)
                .dsText(.itemMeta)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: image

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Color.imageBackdrop)

            if let s = garment.thumbUrl, let url = URL(string: s) {
                // Cached: revisiting a cell paints from memory instead of
                // refetching and re-decoding, and previously-seen garments
                // still render with no connection.
                CachedImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().padding(DS.Space.m)
                    case .failure:
                        symbolPlaceholder
                    case .loading:
                        // Static fill, not a spinner — a grid of independently
                        // animating placeholders reads as noise.
                        DS.Color.skeleton
                    }
                }
            } else {
                symbolPlaceholder
            }

            if let badge = badgeStatus {
                overlayTopTrailing { DSProcessingBadge(status: badge) }
            }
            if isFavorite {
                overlayTopLeading {
                    Image(systemName: "heart.fill")
                        .font(.footnote)
                        .foregroundStyle(DS.Color.favorite)
                        .padding(DS.Space.xs)
                        .background(.thinMaterial, in: Circle())
                }
            }
        }
        .aspectRatio(DS.Ratio.garment, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    /// Shown when the catalog has no photo for this garment (`thumb_url` is
    /// null server-side for the seeded catalog). Previously a small symbol
    /// floating on a flat block, which read as "coloured square" rather than
    /// clothing — the symbol now fills the tile so the silhouette is legible.
    private var symbolPlaceholder: some View {
        ZStack {
            GarmentAppearance.of(garment).color.opacity(0.18)
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .padding(DS.Space.xxxl)
                .foregroundStyle(GarmentAppearance.of(garment).color)
        }
    }

    // MARK: overlays

    private func overlayTopTrailing<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack {
            HStack { Spacer(); content() }
            Spacer()
        }
        .padding(DS.Space.s)
    }

    private func overlayTopLeading<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack {
            HStack { content(); Spacer() }
            Spacer()
        }
        .padding(DS.Space.s)
    }

    // MARK: derived

    /// At most one badge per cell — stacking indicators clutters the grid.
    private var badgeStatus: DSProcessingBadge.Status? {
        CustomGarments.isCustom(garment.id) ? .custom : nil
    }

    /// Category symbol, resolved at runtime.
    ///
    /// Outerwear was `wind` and bottoms were `figure.walk` — a breeze icon and a
    /// walking person, neither of which reads as a garment. These are the right
    /// symbols, but some were added in later SF Symbols releases and a missing
    /// name renders as *nothing*, so each is checked before use and falls back
    /// to a shape that definitely exists.
    private var symbol: String {
        let preferred: String
        switch garment.category.lowercased() {
        case "dress": preferred = "figure.dress.line.vertical.figure"
        case "bottom": preferred = "pants"
        case "outerwear": preferred = "jacket"
        case "footwear": preferred = "shoe.2"
        default: preferred = "tshirt.fill"
        }
        return UIImage(systemName: preferred) != nil ? preferred : "tshirt.fill"
    }

    private var displayCategory: String { garment.category.capitalized }

    private var accessibilityText: String {
        var parts = [garment.name, displayCategory]
        if CustomGarments.isCustom(garment.id) { parts.append("your own garment") }
        else if garment.brand != garment.name { parts.append("by \(garment.brand)") }
        if let p = garment.priceText { parts.append(p) }
        if isFavorite { parts.append("favorite") }
        return parts.joined(separator: ", ")
    }
}
