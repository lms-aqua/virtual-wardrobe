import Foundation

/// Bridges local preferences (units, avatar customization, favorites) to the
/// account-synced `SyncedPrefs` payload.
enum PrefsSync {
    static func snapshot() -> SyncedPrefs {
        SyncedPrefs(units: Units.system.rawValue,
                    skinIndex: Customization.skinIndex,
                    build: Customization.build,
                    favorites: Array(Favorites.ids))
    }

    static func apply(_ p: SyncedPrefs) {
        if let u = p.units, let s = Units.System(rawValue: u) { Units.system = s }
        if let s = p.skinIndex { Customization.skinIndex = s }
        if let b = p.build { Customization.build = b }
        if let f = p.favorites { Favorites.ids = Set(f) }
    }
}
