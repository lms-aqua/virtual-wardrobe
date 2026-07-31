import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AuthStore
    @State private var booted = false

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if !booted {
                ProgressView().tint(DS.Color.accent)
            } else if session.isAuthenticated {
                DashboardView()
            } else {
                WelcomeView()
            }
        }
        .task {
            await session.bootstrap()
            booted = true
        }
        .animation(.easeInOut, value: session.isAuthenticated)
    }
}
