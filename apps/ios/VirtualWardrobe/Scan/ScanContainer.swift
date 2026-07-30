import SwiftUI

/// Coordinates the scan flow lifecycle so any deep child can end it.
@MainActor
final class ScanCoordinator: ObservableObject {
    var onFinish: () -> Void = {}
}

/// Hosts the guided scan as its own navigation stack inside a full-screen cover.
struct ScanContainer: View {
    let onFinish: () -> Void
    @StateObject private var coordinator = ScanCoordinator()

    var body: some View {
        NavigationStack {
            ConsentView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onFinish() }
                    }
                }
        }
        .environmentObject(coordinator)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear { coordinator.onFinish = onFinish }
    }
}
