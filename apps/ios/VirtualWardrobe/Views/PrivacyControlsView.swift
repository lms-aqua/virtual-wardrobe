import SwiftUI

struct PrivacyControlsView: View {
    @EnvironmentObject var session: AuthStore
    @State private var showDeleteConfirm = false
    @State private var deleting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your data", systemImage: "lock.shield.fill")
                                .font(.headline).foregroundStyle(.white)
                            row("Scans upload to private storage only.")
                            row("Raw photos are deleted after your avatar is generated.")
                            row("No face recognition is ever performed.")
                            row("Assets load through short-lived signed links.")
                        }
                        .card()

                        Button {
                            session.signOut()
                        } label: {
                            Label("Sign out", systemImage: "arrow.right.square")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Danger zone").font(.headline).foregroundStyle(.white)
                            Text("This permanently deletes your scans, avatar, measurements, outfits, and account. It cannot be undone.")
                                .font(.footnote).foregroundStyle(.white.opacity(0.7))
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                if deleting { ProgressView() }
                                else { Label("Delete everything", systemImage: "trash.fill")
                                        .frame(maxWidth: .infinity, minHeight: 50) }
                            }
                            .foregroundStyle(.white)
                            .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .card()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Privacy")
            .alert("Delete everything?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your scans, avatar, measurements, outfits, and account will be permanently erased.")
            }
        }
    }

    private func row(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            Text(text).foregroundStyle(.white.opacity(0.85))
        }
    }

    private func delete() async {
        deleting = true
        await session.deleteEverything()
        deleting = false
    }
}
