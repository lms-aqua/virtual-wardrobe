import SwiftUI

struct ProcessingView: View {
    let jobId: String
    @EnvironmentObject var session: AuthStore
    @EnvironmentObject var coordinator: ScanCoordinator

    @State private var status = "processing"
    @State private var avatar: AvatarDTO?
    @State private var errorCode: String?
    @State private var polling = true

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                if status == "completed", let avatar {
                    completed(avatar)
                } else if status == "failed" {
                    failed
                } else {
                    inProgress
                }
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Your avatar")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task { await poll() }
    }

    private var inProgress: some View {
        VStack(spacing: 16) {
            ProgressView().tint(DS.Color.accent).scaleEffect(1.4)
            Text("Building your avatar…").font(.title3.bold()).foregroundStyle(DS.Color.primaryText)
            Text("Validating your scan, estimating measurements, and generating a mobile-ready 3D model.")
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryText)
        }
    }

    private func completed(_ avatar: AvatarDTO) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44)).foregroundStyle(Theme.accent)
            Text("Avatar ready!").font(.title.bold()).foregroundStyle(DS.Color.primaryText)
            AvatarCard(avatar: avatar)
            Button("Done") { coordinator.onFinish() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var failed: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40)).foregroundStyle(.orange)
            Text(errorCode == "network_unreachable"
                 ? "Couldn’t Reach the Server"
                 : "Scan Didn’t Pass Quality Checks")
                .font(.title3.bold()).foregroundStyle(DS.Color.primaryText)
                .multilineTextAlignment(.center)
            Text(friendlyError())
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryText)
            Button("Back") { coordinator.onFinish() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func friendlyError() -> String {
        switch errorCode {
        case let c? where c.contains("low_quality"):
            return "Make sure your whole body is in frame with good lighting, then try again."
        case let c? where c.contains("invalid_image"):
            return "One of the photos couldn't be read. Please retake the scan."
        case "network_unreachable":
            return "We couldn't reach the server. Your scan is safe — check your connection and try again."
        default:
            return "Please try the scan again."
        }
    }

    /// Maximum consecutive request failures before giving up. Without a cap the
    /// loop retried forever on a permanent error (expired token, deleted job),
    /// and the back button is hidden here, so the user was trapped on a spinner
    /// with the app hammering the API every 1.5s.
    private static let maxConsecutiveFailures = 5

    private func poll() async {
        var failures = 0

        while polling {
            if Task.isCancelled { return }

            do {
                let job = try await session.api.job(jobId)
                failures = 0
                status = job.status
                errorCode = job.errorCode
                if job.status == "completed" {
                    avatar = (try? await session.api.avatars())?.first
                    polling = false
                } else if job.status == "failed" {
                    polling = false
                }
            } catch {
                failures += 1
                if failures >= Self.maxConsecutiveFailures {
                    // Terminal state, so the screen stops spinning and offers a
                    // way out instead of retrying indefinitely.
                    status = "failed"
                    errorCode = "network_unreachable"
                    polling = false
                }
            }

            guard polling else { break }

            // `try?` here swallowed CancellationError: when .task cancelled on
            // disappear, sleep threw immediately, the error was discarded and
            // the loop spun with no delay — a tight CPU loop still calling the
            // API after the user had navigated away.
            do {
                try await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                return
            }
        }
    }
}
