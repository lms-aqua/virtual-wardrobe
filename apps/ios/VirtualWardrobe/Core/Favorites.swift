import Foundation

/// Locally-stored favorite outfit ids.
enum Favorites {
    private static let key = "vw.favOutfits"
    static var ids: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }
    static func contains(_ id: String) -> Bool { ids.contains(id) }
    static func toggle(_ id: String) {
        var s = ids
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        ids = s
    }
}
