import SwiftUI

@MainActor
final class ScanFlowModel: ObservableObject {
    enum Phase { case idle, countdown, capturing, validating, uploading, processing }

    @Published var phase: Phase = .idle
    @Published var captured = 0
    @Published var uploaded = 0
    @Published var countdown: Int? = nil
    @Published var status = "Stand back so your whole body fits in the frame."
    @Published var error: String?
    @Published var completedJobId: String?

    /// Number of frames captured across a full 360° turn. More frames = more
    /// angular coverage for the (future) reconstruction pipeline.
    let targetFrames = 24

    private var frames: [Data] = []
    private var scanId: String?
    private var api = APIClient(token: nil)
    private var started = false

    func setAPI(_ api: APIClient) { self.api = api }

    var progress: Double {
        switch phase {
        case .capturing: return Double(captured) / Double(targetFrames)
        case .uploading: return Double(uploaded) / Double(max(1, frames.count))
        case .processing: return 1
        default: return 0
        }
    }

    func begin() async {
        guard !started else { return }
        started = true
        do {
            let scan = try await api.createScan(heightCm: nil)
            scanId = scan.id
        } catch {
            self.error = error.localizedDescription
        }
    }

    func run360(_ camera: CameraController) async {
        guard let scanId, phase == .idle else { return }
        error = nil
        do {
            // 3-2-1 so the user can get into position and start turning.
            phase = .countdown
            for n in stride(from: 3, through: 1, by: -1) {
                countdown = n
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            countdown = nil

            // Capture frames as the user slowly rotates. Each frame is
            // downscaled immediately so memory + upload stay small.
            phase = .capturing
            frames.removeAll()
            for i in 0..<targetFrames {
                status = "Keep turning slowly… \(i + 1)/\(targetFrames)"
                let raw = try await camera.capture()
                frames.append(ImageUtils.downscaledJPEG(raw))
                captured = i + 1
                try? await Task.sleep(nanoseconds: 300_000_000)
            }

            // Refuse to submit a scan with no visible body. Nothing downstream
            // looks at these pixels — the server derives measurements from the
            // entered height — so without this the app happily accepted a wall
            // and returned a full set of "measurements".
            phase = .validating
            status = "Checking your photos…"
            let framesToCheck = frames
            let looksLikeAPerson = await Task.detached(priority: .userInitiated) {
                BodyDetector.framesLookLikeAPerson(framesToCheck)
            }.value
            guard looksLikeAPerson else {
                phase = .idle
                countdown = nil
                captured = 0
                frames.removeAll()
                error = "We couldn't see a person in those photos. Put your whole "
                    + "body in frame, in good light, and try again."
                return
            }

            // Upload frames concurrently (much faster than sequential).
            phase = .uploading
            uploaded = 0
            try await uploadConcurrently(frames, scanId: scanId, maxParallel: 4)

            // Kick off avatar generation.
            phase = .processing
            status = "Building your avatar…"
            let done = try await api.completeScan(scanId: scanId)
            completedJobId = done.jobId
        } catch {
            self.error = error.localizedDescription
            status = "Something went wrong — you can restart the scan."
            phase = .idle
            captured = 0
            uploaded = 0
        }
    }

    private func bumpUploaded() { uploaded += 1 }

    /// Upload frames in batches so several run at once (cap = maxParallel).
    private func uploadConcurrently(_ frames: [Data], scanId: String,
                                    maxParallel: Int) async throws {
        let api = self.api
        var index = 0
        while index < frames.count {
            let end = min(index + maxParallel, frames.count)
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in index..<end {
                    let jpeg = frames[i]
                    let view = String(format: "frame_%04d", i)
                    group.addTask {
                        let presigned = try await api.uploadURL(
                            scanId: scanId, view: view, contentType: "image/jpeg")
                        try await api.uploadToPresigned(presigned, imageData: jpeg)
                    }
                }
                for try await _ in group { bumpUploaded() }
            }
            status = "Uploading frames… \(uploaded)/\(frames.count)"
            index = end
        }
    }
}

struct ScanFlowView: View {
    @EnvironmentObject var session: AuthStore
    @StateObject private var camera = CameraController()
    @StateObject private var model = ScanFlowModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.authorized {
                CameraPreview(session: camera.session).ignoresSafeArea()
                SilhouetteOverlay()
                controls
                flipButton
            } else {
                permissionPrompt
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            model.setAPI(session.api)
            await camera.requestAccess()
            camera.start()
            await model.begin()
        }
        .onDisappear { camera.stop() }
        .navigationDestination(
            isPresented: Binding(get: { model.completedJobId != nil }, set: { _ in })
        ) {
            if let jobId = model.completedJobId { ProcessingView(jobId: jobId) }
        }
    }

    private var controls: some View {
        VStack {
            Spacer()
            if let n = model.countdown {
                Text("\(n)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Color.primaryText)
                    .transition(.scale.combined(with: .opacity))
            } else if model.phase != .idle {
                ProgressRing(progress: model.progress)
                    .frame(width: 130, height: 130)
            }
            Spacer()

            VStack(spacing: 14) {
                Text(model.phase == .idle
                     ? "Tap start, then slowly spin in a full circle keeping your whole body in frame."
                     : model.status)
                    .font(.headline).foregroundStyle(DS.Color.primaryText)
                    .multilineTextAlignment(.center)
                if let e = model.error {
                    Text(e).font(.footnote).foregroundStyle(.red)
                }
                if model.phase == .idle {
                    Button {
                        Task { await model.run360(camera) }
                    } label: {
                        Label("Start 360° scan", systemImage: "arrow.triangle.2.circlepath.camera.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    HStack(spacing: 8) {
                        ProgressView().tint(DS.Color.accent)
                        Text(phaseLabel).foregroundStyle(DS.Color.primaryText)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
        }
        .animation(.spring(duration: 0.3), value: model.countdown)
        .animation(.easeInOut, value: model.phase)
    }

    private var phaseLabel: String {
        switch model.phase {
        case .capturing: return "Capturing \(model.captured)/\(model.targetFrames)"
        case .validating: return "Checking your photos…"
        case .uploading: return "Uploading \(model.uploaded)/\(model.targetFrames)"
        case .processing: return "Processing…"
        default: return ""
        }
    }

    /// Front/back toggle, shown top-right while idle (not mid-capture).
    private var flipButton: some View {
        VStack {
            HStack {
                Spacer()
                if model.phase == .idle {
                    Button { camera.flip() } label: {
                        Label(camera.position == .front ? "Front" : "Back",
                              systemImage: "arrow.triangle.2.circlepath.camera")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.primaryText)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.trailing, 18).padding(.top, 10)
                }
            }
            Spacer()
        }
    }

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Camera access needed")
                .font(.title2.bold()).foregroundStyle(DS.Color.primaryText)
            Text("We use the camera only for the scan you start. Enable it in Settings.")
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryText)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(30)
    }
}

/// Circular progress indicator used during capture/upload.
struct ProgressRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(DS.Color.separator, lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Theme.brandGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.title2.bold()).foregroundStyle(DS.Color.primaryText)
        }
    }
}
