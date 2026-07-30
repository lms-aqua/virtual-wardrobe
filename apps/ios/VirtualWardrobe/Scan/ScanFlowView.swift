import SwiftUI

@MainActor
final class ScanFlowModel: ObservableObject {
    @Published var index = 0
    @Published var countdown: Int? = nil
    @Published var busy = false
    @Published var status = "Position yourself in the frame"
    @Published var error: String?
    @Published var completedJobId: String?

    let views = ScanView.allCases
    private var scanId: String?
    private var api = APIClient(token: nil)
    private var started = false

    func setAPI(_ api: APIClient) { self.api = api }

    var currentView: ScanView { views[min(index, views.count - 1)] }
    var progress: Double { Double(index) / Double(views.count) }

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

    func captureCurrent(_ camera: CameraController) async {
        guard let scanId, !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            for n in stride(from: 3, through: 1, by: -1) {
                countdown = n
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            countdown = nil
            status = "Capturing \(currentView.rawValue)…"
            let jpeg = try await camera.capture()

            status = "Uploading \(currentView.rawValue)…"
            let presigned = try await api.uploadURL(
                scanId: scanId, view: currentView.rawValue, contentType: "image/jpeg")
            try await api.uploadToPresigned(presigned, imageData: jpeg)

            if index + 1 < views.count {
                index += 1
                status = "Great! Now the \(currentView.rawValue) view."
            } else {
                status = "Building your avatar…"
                let done = try await api.completeScan(scanId: scanId)
                completedJobId = done.jobId
            }
        } catch {
            self.error = error.localizedDescription
            status = "Something went wrong — try again."
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
            isPresented: Binding(
                get: { model.completedJobId != nil },
                set: { _ in }
            )
        ) {
            if let jobId = model.completedJobId { ProcessingView(jobId: jobId) }
        }
    }

    private var controls: some View {
        VStack {
            ProgressView(value: model.progress)
                .tint(Theme.accent).padding(.horizontal).padding(.top, 8)
            HStack(spacing: 8) {
                ForEach(model.views) { v in
                    Image(systemName: v.symbol)
                        .foregroundStyle(v == model.currentView ? Theme.accent : .white.opacity(0.4))
                }
            }
            .font(.title3).padding(.top, 4)

            Spacer()
            if let n = model.countdown {
                Text("\(n)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()

            VStack(spacing: 14) {
                Text(model.currentView.instruction)
                    .font(.headline).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(model.status)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                if let e = model.error {
                    Text(e).font(.footnote).foregroundStyle(.red)
                }
                Button {
                    Task { await model.captureCurrent(camera) }
                } label: {
                    if model.busy { ProgressView().tint(.white) }
                    else { Label("Capture \(model.currentView.rawValue)", systemImage: "camera.fill") }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: !model.busy))
                .disabled(model.busy)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
        }
        .animation(.spring(duration: 0.3), value: model.countdown)
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
