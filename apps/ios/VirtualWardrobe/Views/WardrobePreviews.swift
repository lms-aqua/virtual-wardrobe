#if DEBUG
import SwiftUI

// Preview-only fixtures and previews for the Wardrobe surface.
//
// The whole file is inside `#if DEBUG`, so no sample garment can reach a
// release build. These render the real components — not mock-ups of them — so
// a regression in the cell or a state view shows up here.

enum PreviewGarments {
    static func make(
        id: String,
        name: String,
        category: String,
        brand: String = "Atelier",
        thumbUrl: String? = nil,
        priceCents: Int? = 8900
    ) -> GarmentDTO {
        GarmentDTO(
            id: id,
            brand: brand,
            name: name,
            category: category,
            thumbUrl: thumbUrl,
            layeringOrder: 1,
            sizes: [GarmentSizeDTO(sizeLabel: "M", measurements: nil)],
            productUrl: nil,
            priceCents: priceCents
        )
    }

    static let all: [GarmentDTO] = [
        make(id: "g1", name: "Oxford Shirt", category: "top"),
        make(id: "g2", name: "Slim Chino", category: "bottom", priceCents: 6500),
        make(id: "g3", name: "Wool Overcoat", category: "outerwear", priceCents: 24900),
        make(id: "g4", name: "Linen Dress", category: "dress", priceCents: 12900),
        make(id: "g5", name: "Leather Derby", category: "footwear", priceCents: 18000),
        make(id: "custom_1", name: "My Denim Jacket", category: "outerwear", priceCents: nil),
    ]

    /// Worst-case label: long, unbroken, and easy to truncate badly.
    static let longName = make(
        id: "g6",
        name: "Double-Breasted Herringbone Wool Overcoat, Charcoal",
        category: "outerwear",
        brand: "Maison Lostfaith",
        priceCents: 48900
    )

    /// Broken remote image — must fall back to the category symbol, not a gap.
    static let missingImage = make(
        id: "g7",
        name: "Cashmere Crewneck",
        category: "top",
        thumbUrl: "https://example.invalid/missing.png"
    )
}

/// Mirrors the real grid geometry so preview spacing matches the screen.
private struct PreviewGrid: View {
    var garments: [GarmentDTO] = PreviewGarments.all
    var favorites: Set<String> = ["g2"]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: DS.Space.l)]
            : [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: DS.Space.l)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DS.Space.xl) {
                    ForEach(garments) { g in
                        WardrobeItemCell(garment: g, isFavorite: favorites.contains(g.id))
                    }
                }
                .padding(DS.Space.screenMargin)
            }
            .background(DS.Color.grouped)
            .navigationTitle("Wardrobe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: { Label("Add Garment", systemImage: "plus") }
                }
            }
        }
    }
}

// MARK: - Content

#Preview("Grid — normal") {
    PreviewGrid()
}

#Preview("Grid — dark") {
    PreviewGrid().preferredColorScheme(.dark)
}

#Preview("Grid — accessibility XXXL") {
    PreviewGrid()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Grid — reduce transparency") {
    // Glass controls must stay legible as solid surfaces.
    PreviewGrid()
        .environment(\.accessibilityReduceTransparency, true)
}

// MARK: - Edge-case cells

#Preview("Cell — long name + missing image") {
    HStack(alignment: .top, spacing: DS.Space.l) {
        WardrobeItemCell(garment: PreviewGarments.longName)
        WardrobeItemCell(garment: PreviewGarments.missingImage, isFavorite: true)
    }
    .padding(DS.Space.screenMargin)
    .background(DS.Color.grouped)
}

#Preview("Cell — long name at XXXL") {
    WardrobeItemCell(garment: PreviewGarments.longName)
        .padding(DS.Space.screenMargin)
        .environment(\.dynamicTypeSize, .accessibility3)
        .background(DS.Color.grouped)
}

// MARK: - States

#Preview("State — loading skeleton") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: DS.Space.l)],
                  spacing: DS.Space.xl) {
            ForEach(0..<6, id: \.self) { _ in DSGarmentSkeletonCell() }
        }
        .padding(DS.Space.screenMargin)
    }
    .background(DS.Color.grouped)
}

#Preview("State — empty") {
    DSEmptyState(
        title: "Your Wardrobe Is Ready",
        systemImage: "tshirt",
        message: "Add your first garment to begin creating outfits and virtual try-ons.",
        actionTitle: "Add Garment",
        action: {}
    )
}

#Preview("State — error") {
    DSErrorState(
        title: "Garments Couldn’t Load",
        message: "Your wardrobe is still safe. Check your connection and try again.",
        systemImage: "wifi.exclamationmark",
        retry: {}
    )
}

// MARK: - Design-system spot checks

#Preview("DS — status badges") {
    VStack(alignment: .leading, spacing: DS.Space.m) {
        DSProcessingBadge(status: .processing)
        DSProcessingBadge(status: .ready)
        DSProcessingBadge(status: .failed)
        DSProcessingBadge(status: .custom)
    }
    .padding(DS.Space.xl)
    .background(DS.Color.grouped)
}

#Preview("DS — glass controls") {
    ZStack {
        DSStudioBackground().ignoresSafeArea()
        VStack(spacing: DS.Space.xl) {
            DSGlassGroup {
                HStack(spacing: DS.Space.s) {
                    DSFilterChip(title: "All", isActive: true) {}
                    DSFilterChip(title: "Tops", isActive: false) {}
                    DSFilterChip(title: "Outerwear", isActive: false) {}
                }
            }
            DSFloatingActionControl(title: "Add Garment", systemImage: "plus") {}
        }
    }
}
#endif
