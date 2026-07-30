import Foundation

/// Where the app talks to the backend. Editable in-app (Settings) so the same
/// build can point at localhost during development or the real domain in prod.
enum AppConfig {
    static let baseURLKey = "vw.apiBaseURL"

    /// Change this default to your deployed domain, e.g.
    /// "https://api.virtualwardrobe.app". For the iOS Simulator hitting a local
    /// backend use "http://localhost:8000" (ATS exception is set in Info.plist).
    static let defaultBaseURL = "https://api.virtualwardrobe.app"

    static var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: baseURLKey)
        return URL(string: stored ?? defaultBaseURL) ?? URL(string: defaultBaseURL)!
    }

    static func setBaseURL(_ value: String) {
        UserDefaults.standard.set(value, forKey: baseURLKey)
    }
}
