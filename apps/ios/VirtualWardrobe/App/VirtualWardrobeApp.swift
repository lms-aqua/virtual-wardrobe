import SwiftUI

@main
struct VirtualWardrobeApp: App {
    @StateObject private var session = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(DS.Color.accent)
            // No .preferredColorScheme here: the app follows the system
            // appearance now that every surface uses semantic colours. The
            // capture flow still pins itself dark — an immersive camera UI
            // reads better that way, which is how Apple's own Camera behaves.
        }
    }
}
