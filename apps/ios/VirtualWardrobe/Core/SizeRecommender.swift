import Foundation

/// Suggests a garment size from the user's measurements vs. the garment's size
/// chart. Heuristic only — not a guarantee of fit.
enum SizeRecommender {
    struct Rec { let label: String; let note: String }

    static func recommend(garment: GarmentDTO, measurements: MeasurementDTO?) -> Rec? {
        guard !garment.sizes.isEmpty else { return nil }

        let key: String
        switch garment.category.lowercased() {
        case "bottom": key = "waist_cm"
        case "footwear": return Rec(label: middle(garment.sizes), note: "Use your usual shoe size")
        default: key = "chest_cm"
        }

        let target = (key == "waist_cm") ? measurements?.waistCm : measurements?.chestCm
        guard let target else {
            return Rec(label: middle(garment.sizes), note: "Add measurements for a better fit")
        }

        let sized = garment.sizes.compactMap { s -> (GarmentSizeDTO, Double)? in
            s.measurements?[key].map { (s, $0) }
        }
        guard !sized.isEmpty else { return Rec(label: middle(garment.sizes), note: "True to size") }

        let sorted = sized.sorted { $0.1 < $1.1 }
        let pick = sorted.first(where: { $0.1 >= target }) ?? sorted.last!
        let room = pick.1 - target
        let note = room < 0 ? "May be snug" : (room > 15 ? "Relaxed fit" : "True to size")
        return Rec(label: pick.0.sizeLabel, note: note)
    }

    private static func middle(_ sizes: [GarmentSizeDTO]) -> String {
        sizes.isEmpty ? "M" : sizes[sizes.count / 2].sizeLabel
    }
}
