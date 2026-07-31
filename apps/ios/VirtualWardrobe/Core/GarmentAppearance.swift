import SwiftUI

/// Which region of the body a garment covers — drives 3D placement.
enum GarmentRegion {
    case top, dress, bottom, outerwear, footwear, unknown
}

/// Client-side visual model for a garment (color + region), derived from its
/// category/name so the 3D try-on has something real to render without a
/// backend change. Colors are pleasant defaults, not real product colors.
struct GarmentAppearance {
    let color: Color
    let region: GarmentRegion

    static func of(_ garment: GarmentDTO) -> GarmentAppearance {
        if let custom = CustomGarments.color(for: garment.id) {
            return GarmentAppearance(color: custom, region: regionFor(garment.category))
        }
        let region: GarmentRegion
        switch garment.category.lowercased() {
        case "top": region = .top
        case "dress": region = .dress
        case "bottom": region = .bottom
        case "outerwear": region = .outerwear
        case "footwear": region = .footwear
        default: region = .unknown
        }
        return GarmentAppearance(color: colorFor(garment.name, region: region), region: region)
    }

    static func regionFor(_ category: String) -> GarmentRegion {
        switch category.lowercased() {
        case "top": return .top
        case "dress": return .dress
        case "bottom": return .bottom
        case "outerwear": return .outerwear
        case "footwear": return .footwear
        default: return .unknown
        }
    }

    private static func colorFor(_ name: String, region: GarmentRegion) -> Color {
        let n = name.lowercased()
        if n.contains("jean") { return Color(red: 0.24, green: 0.34, blue: 0.52) }
        if n.contains("hoodie") { return Color(red: 0.42, green: 0.45, blue: 0.52) }
        if n.contains("jacket") { return Color(red: 0.20, green: 0.22, blue: 0.28) }
        if n.contains("dress") { return Color(red: 0.86, green: 0.42, blue: 0.62) }
        if n.contains("skirt") { return Color(red: 0.55, green: 0.42, blue: 0.72) }
        if n.contains("blouse") { return Color(red: 0.96, green: 0.90, blue: 0.80) }
        if n.contains("sneaker") || n.contains("shoe") { return Color(red: 0.90, green: 0.90, blue: 0.94) }
        if n.contains("t-shirt") || n.contains("tee") { return Color(red: 0.43, green: 0.37, blue: 0.99) }
        switch region {
        case .top: return Color(red: 0.43, green: 0.37, blue: 0.99)
        case .dress: return Color(red: 0.86, green: 0.42, blue: 0.62)
        case .bottom: return Color(red: 0.30, green: 0.34, blue: 0.44)
        case .outerwear: return Color(red: 0.30, green: 0.30, blue: 0.36)
        case .footwear: return Color(red: 0.88, green: 0.88, blue: 0.92)
        case .unknown: return Color(red: 0.60, green: 0.60, blue: 0.70)
        }
    }
}
