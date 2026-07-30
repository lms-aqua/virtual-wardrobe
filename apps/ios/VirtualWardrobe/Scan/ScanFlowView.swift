import SwiftUI

@MainActor
final class ScanFlowModel: ObservableObject {
    enum Phase { case idle, countdown, capturing, uploading, processing }

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

            // Capture frames as the user slowly rotates.
            phase = .capturing
            frames.removeAll()
            for i in 0..<targetFrames {
                status = "Keep turning slowly… \(i + 1)/\(targetFrames)"
                let jpeg = try await camera.capture()
                frames.append(jpeg)
                captured = i + 1
                try? await Task.sleep(nanoseconds: 350_000_000)
            }

            // Upload every frame.
            phase = .uploading
            for (i, jpeg) in frames.enumerated() {
                status = "Uploading frames… \(i + 1)/\(frames.count)"
                let view = String(format: "frame_%04d", i)
                let presigned = try await api.uploadURL(
                    scanId: scanId, view: view, contentType: "image/jpeg")
                try await api.uploadToPresigned(presigned, imageData: jpeg)
                uploaded = i + 1
            }

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
                    .foregroundStyle(.white)
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
                    .font(.headline).foregroundStyle(.white)
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
                        ProgressView().tint(.white)
                        Text(phaseLabel).foregroundStyle(.white.opacity(0.85))
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
                            .foregroundStyle(.white)
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
                .font(.system(size: 44)).foregroundStyle(Theme.accent)
            Text("Camera access needed")
                .font(.title2.bold()).foregroundStyle(.white)
            Text("We use the camera only for the scan you start. Enable it in Settings.")
                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
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
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Theme.brandGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.title2.bold()).foregroundStyle(.white)
        }
    }
}
