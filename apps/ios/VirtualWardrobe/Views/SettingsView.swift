import SwiftUI

/// Lets the user point the app at the backend domain (or localhost in dev).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var baseURL = AppConfig.baseURL.absoluteString

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Server")
                        .font(.headline).foregroundStyle(.white)
                    Text("The domain this app connects to. Use your deployed API, or http://localhost:8000 for a local backend in the Simulator.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.7))
                    TextField("https://api.example.com", text: $baseURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .padding(14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    Button("Save") {
                        AppConfig.setBaseURL(baseURL.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
