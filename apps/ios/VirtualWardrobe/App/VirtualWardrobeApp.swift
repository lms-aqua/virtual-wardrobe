import SwiftUI

@main
struct VirtualWardrobeApp: App {
    @StateObject private var session = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
