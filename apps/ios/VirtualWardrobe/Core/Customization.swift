import UIKit

/// User avatar customization (skin tone + body build), stored in UserDefaults.
/// Read by AvatarBuilder so every 3D preview reflects the user's choices.
enum Customization {
    private static let skinKey = "vw.skinTone"
    private static let buildKey = "vw.build"

    static let skinTones: [UIColor] = [
        UIColor(red: 0.98, green: 0.87, blue: 0.79, alpha: 1),
        UIColor(red: 0.93, green: 0.79, blue: 0.68, alpha: 1),
        UIColor(red: 0.85, green: 0.71, blue: 0.61, alpha: 1),
        UIColor(red: 0.72, green: 0.55, blue: 0.44, alpha: 1),
        UIColor(red: 0.55, green: 0.40, blue: 0.30, alpha: 1),
        UIColor(red: 0.38, green: 0.26, blue: 0.19, alpha: 1),
    ]

    static var skinIndex: Int {
        get { UserDefaults.standard.object(forKey: skinKey) as? Int ?? 2 }
        set { UserDefaults.standard.set(newValue, forKey: skinKey) }
    }
    static var skinColor: UIColor { skinTones[min(max(skinIndex, 0), skinTones.count - 1)] }

    /// Girth multiplier 0.8…1.2 applied to circumferences (slimmer ↔ fuller).
    static var build: Double {
        get { let v = UserDefaults.standard.double(forKey: buildKey); return v == 0 ? 1.0 : v }
        set { UserDefaults.standard.set(newValue, forKey: buildKey) }
    }
    static var buildFloat: Float { Float(build) }
}
