import Foundation

/// Where the app talks to the backend. Editable in-app (Settings) so the same
/// build can point at localhost during development or the real domain in prod.
enum AppConfig {
    static let baseURLKey = "vw.apiBaseURL"

    /// Live backend on the LostHosting box. Override in-app via Settings for
    /// local dev (e.g. "http://localhost:8000" on the Simulator).
    static let defaultBaseURL = "https://wardrobe-api.losthosting.com"

    static var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: baseURLKey)
        return URL(string: stored ?? defaultBaseURL) ?? URL(string: defaultBaseURL)!
    }

    static func setBaseURL(_ value: String) {
        UserDefaults.standard.set(value, forKey: baseURLKey)
    }
}
