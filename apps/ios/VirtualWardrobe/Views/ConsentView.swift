import SwiftUI

struct ConsentView: View {
    @EnvironmentObject var session: AuthStore
    @State private var agreed = false
    @State private var granting = false
    @State private var goToScan = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40)).foregroundStyle(Theme.accent)
                    Text("Before you scan")
                        .font(.largeTitle.bold()).foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        bullet("Only scan your own body.", "person.fill.checkmark")
                        bullet("Wear close-fitting clothes for better accuracy. Never nudity.", "tshirt")
                        bullet("Your photos upload to private storage and are deleted after your avatar is built.", "trash.slash.fill")
                        bullet("You can crop, blur, or omit your face. No face recognition is used.", "eye.slash.fill")
                        bullet("You can delete everything anytime.", "lock.shield.fill")
                    }
                    .card()

                    Toggle(isOn: $agreed) {
                        Text("I consent to a body scan of myself under these terms.")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .tint(Theme.accent)

                    Button {
                        Task { await grant() }
                    } label: {
                        if granting { ProgressView().tint(.white) }
                        else { Text("I consent — continue") }
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: agreed && !granting))
                    .disabled(!agreed || granting)

                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                }
                .padding(20)
            }
        }
        .navigationTitle("Consent")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToScan) { ScanFlowView() }
    }

    private func bullet(_ text: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
            Text(text).foregroundStyle(.white.opacity(0.85))
        }
    }

    private func grant() async {
        granting = true; error = nil
        defer { granting = false }
        do {
            try await session.api.grantScanConsent()
            goToScan = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
