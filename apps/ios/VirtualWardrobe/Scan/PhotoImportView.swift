import PhotosUI
import SwiftUI

/// Build an avatar from existing library photos instead of a live 360° scan.
/// Reuses the same private-upload pipeline; pick several angles for best results.
struct PhotoImportView: View {
    @EnvironmentObject var session: AuthStore
    let onFinish: () -> Void

    @State private var picks: [PhotosPickerItem] = []
    @State private var phase: Phase = .pick
    @State private var progress = 0.0
    @State private var status = ""
    @State private var avatar: AvatarDTO?

    enum Phase { case pick, working, done, failed }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                switch phase {
                case .pick: pickUI
                case .working: workingUI
                case .done: doneUI
                case .failed: failedUI
                }
            }
            .navigationTitle("Import Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { onFinish() } } }
        }
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private var pickUI: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Pick 6–12 full-body photos from different angles (front, sides, back).")
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryText)
                .padding(.horizontal)
            PhotosPicker(selection: $picks, maxSelectionCount: 20, matching: .images) {
                Label(picks.isEmpty ? "Choose photos" : "\(picks.count) selected",
                      systemImage: "photo.stack")
            }
            .buttonStyle(PrimaryButtonStyle())
            if picks.count >= 4 {
                Button("Build my avatar") { Task { await run() } }
                    .buttonStyle(PrimaryButtonStyle())
            } else if !picks.isEmpty {
                Text("Pick at least 4 photos.").font(.footnote).foregroundStyle(DS.Color.secondaryText)
            }
        }
        .padding(24)
    }

    private var workingUI: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress).tint(Theme.accent).padding(.horizontal, 40)
            Text(status).foregroundStyle(DS.Color.primaryText)
        }
    }

    private var doneUI: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Avatar ready!").font(.title.bold()).foregroundStyle(DS.Color.primaryText)
            if let avatar { AvatarCard(avatar: avatar) }
            Button("Done") { onFinish() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
    }

    private var failedUI: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
            Text("Couldn't build the avatar").font(.title3.bold()).foregroundStyle(DS.Color.primaryText)
            Text("Make sure you picked at least 4 clear, full-body photos, then try again.")
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryText)
            Button("Back") { phase = .pick }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    private func run() async {
        phase = .working; progress = 0; status = "Preparing…"
        do {
            try? await session.api.grantScanConsent()
            let scan = try await session.api.createScan(heightCm: nil)

            var frame = 0
            for item in picks {
                status = "Uploading photo \(frame + 1)/\(picks.count)…"
                guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
                let jpeg = ImageUtils.downscaledJPEG(raw)
                let view = String(format: "frame_%04d", frame)
                let presigned = try await session.api.uploadURL(
                    scanId: scan.id, view: view, contentType: "image/jpeg")
                try await session.api.uploadToPresigned(presigned, imageData: jpeg)
                frame += 1
                progress = Double(frame) / Double(picks.count) * 0.9
            }
            guard frame >= 4 else { phase = .failed; return }

            status = "Building your avatar…"; progress = 0.95
            let done = try await session.api.completeScan(scanId: scan.id)
            // Poll briefly for completion (inline job in staging is fast).
            for _ in 0..<40 {
                let job = try await session.api.job(done.jobId)
                if job.status == "completed" {
                    avatar = try await session.api.avatars().first
                    progress = 1; phase = .done; return
                } else if job.status == "failed" { phase = .failed; return }
                // BUG-012: `try?` here discarded CancellationError, so leaving
                // the screen ran the remaining iterations back-to-back with no
                // delay instead of stopping.
                if Task.isCancelled { return }
                do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
            }
            phase = .failed
        } catch {
            phase = .failed
        }
    }
}
