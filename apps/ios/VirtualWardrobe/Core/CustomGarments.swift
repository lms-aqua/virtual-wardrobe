import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self = Color(red: Double((v & 0xFF0000) >> 16) / 255,
                     green: Double((v & 0x00FF00) >> 8) / 255,
                     blue: Double(v & 0x0000FF) / 255)
    }
}

struct CustomGarment: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let colorHex: String
}

/// Locally-stored garments the user adds themselves. They render in the 3D
/// try-on (client-side only) but aren't part of the shared catalog, so they
/// can't be saved into a synced outfit.
enum CustomGarments {
    private static let key = "vw.customGarments"
    static let palette = ["6D5EFC", "DC6BFA", "3E5686", "6B7280", "2E2E42",
                          "E6E6F0", "D06B9E", "4E9E6E", "C0552E"]

    static var all: [CustomGarment] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([CustomGarment].self, from: data) else { return [] }
        return list
    }

    static func add(name: String, category: String, colorHex: String) {
        var list = all
        list.append(CustomGarment(id: "custom_\(UUID().uuidString)",
                                  name: name.isEmpty ? category.capitalized : name,
                                  category: category, colorHex: colorHex))
        save(list)
    }

    static func remove(id: String) { save(all.filter { $0.id != id }) }

    private static func save(_ list: [CustomGarment]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func color(for id: String) -> Color? {
        all.first { $0.id == id }.map { Color(hex: $0.colorHex) }
    }

    static func layer(for category: String) -> Int {
        switch category {
        case "top": return 10
        case "dress": return 20
        case "bottom": return 20
        case "outerwear": return 30
        case "footwear": return 5
        default: return 15
        }
    }

    static func asGarment(_ c: CustomGarment) -> GarmentDTO {
        GarmentDTO(id: c.id, brand: "You", name: c.name, category: c.category,
                   thumbUrl: nil, layeringOrder: layer(for: c.category), sizes: [],
                   productUrl: nil, priceCents: nil)
    }

    static var isCustom: (String) -> Bool { { $0.hasPrefix("custom_") } }
}
