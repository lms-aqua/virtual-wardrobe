import Foundation

/// User-facing measurement units (stored in UserDefaults). All values are held
/// internally in centimeters; this only affects display + entry.
enum Units {
    private static let key = "vw.units"

    enum System: String, CaseIterable, Identifiable {
        case metric, imperial
        var id: String { rawValue }
        var label: String { self == .metric ? "Metric (cm)" : "Imperial (in)" }
        var suffix: String { self == .metric ? "cm" : "in" }
    }

    static var system: System {
        get { System(rawValue: UserDefaults.standard.string(forKey: key) ?? "metric") ?? .metric }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    /// Numeric value only, in the current unit.
    static func value(cm: Double?) -> String {
        guard let cm else { return "—" }
        return system == .metric ? String(format: "%.0f", cm)
                                  : String(format: "%.1f", cm / 2.54)
    }

    /// Value + unit suffix.
    static func display(cm: Double?) -> String {
        guard cm != nil else { return "—" }
        return "\(value(cm: cm)) \(system.suffix)"
    }

    /// Parse a user-entered string (in current unit) back to centimeters.
    static func toCm(_ text: String) -> Double? {
        guard let n = Double(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        return system == .metric ? n : n * 2.54
    }
}
