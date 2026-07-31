import ARKit
import SwiftUI
import UIKit
import simd

/// Uses ARKit body tracking to read REAL linear body measurements (height,
/// shoulder width, arm & leg length) from the detected skeleton — genuine
/// measured data, unlike the estimated-from-height defaults. Circumferences
/// (chest/waist/hip) can't be measured from a skeleton and stay estimated.
/// Requires an A12+ device; verify results on a physical device.
final class ARMeasureController: NSObject, ObservableObject, ARSessionDelegate {
    let arView = ARSCNView()
    @Published var bodyDetected = false
    @Published var heightCm: Double = 0
    @Published var shoulderCm: Double = 0
    @Published var armCm: Double = 0
    @Published var inseamCm: Double = 0
    @Published var torsoCm: Double = 0
    @Published var supported = ARBodyTrackingConfiguration.isSupported

    func start() {
        guard supported else { return }
        arView.session.delegate = self
        let config = ARBodyTrackingConfiguration()
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() { arView.session.pause() }

    private func pos(_ sk: ARSkeleton3D, _ joint: ARSkeleton.JointName) -> simd_float3? {
        guard let t = sk.modelTransform(for: joint) else { return nil }
        return simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let body = anchors.compactMap({ $0 as? ARBodyAnchor }).first else { return }
        let sk = body.skeleton
        let scale = Float(body.estimatedScaleFactor)
        func cm(_ v: Float) -> Double { Double(v * scale * 100) }

        guard let head = pos(sk, .head), let foot = pos(sk, .leftFoot) else { return }
        let root = pos(sk, .root)
        let lSh = pos(sk, .leftShoulder), rSh = pos(sk, .rightShoulder)
        let lHand = pos(sk, .leftHand)

        let h = cm(head.y - foot.y) + 14   // add ~14cm for head top above the head joint
        DispatchQueue.main.async {
            self.bodyDetected = true
            self.heightCm = max(0, h)
            if let lSh, let rSh { self.shoulderCm = cm(simd_length(lSh - rSh)) }
            if let lSh, let lHand { self.armCm = cm(simd_length(lSh - lHand)) }
            if let root { self.inseamCm = cm(root.y - foot.y) }
            if let root { self.torsoCm = cm(head.y - root.y) }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let controller: ARMeasureController
    func makeUIView(context: Context) -> ARSCNView { controller.arView }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct ARMeasureView: View {
    @EnvironmentObject var session: AuthStore
    let onFinish: () -> Void
    @StateObject private var ar = ARMeasureController()
    @State private var avatarId: String?
    @State private var saving = false
    @State private var saved = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if ar.supported {
                ARViewContainer(controller: ar).ignoresSafeArea()
                overlay
            } else {
                unsupported
            }
        }
        .task {
            avatarId = (try? await session.api.avatars())?.first?.id
            ar.start()
        }
        .onDisappear { ar.stop() }
    }

    private var overlay: some View {
        VStack {
            HStack {
                Spacer()
                Button("Close") { onFinish() }.foregroundStyle(DS.Color.primaryText)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule()).padding()
            }
            Spacer()
            VStack(spacing: 12) {
                if ar.bodyDetected {
                    Text("Body detected").font(.headline).foregroundStyle(DS.Color.primaryText)
                    HStack(spacing: 18) {
                        stat("Height", ar.heightCm)
                        stat("Shoulders", ar.shoulderCm)
                        stat("Arm", ar.armCm)
                        stat("Inseam", ar.inseamCm)
                    }
                    Text("Stand ~2–3 m away, full body in frame, for best accuracy.")
                        .font(.caption2).foregroundStyle(DS.Color.secondaryText)
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView().tint(DS.Color.accent) }
                        else { Text(saved ? "Saved ✓" : "Use these measurements") }
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: !saving && avatarId != nil))
                    .disabled(saving || avatarId == nil)
                } else {
                    Text("Point the camera at a person, full body in frame…")
                        .font(.headline).foregroundStyle(DS.Color.primaryText).multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding()
        }
    }

    private func stat(_ label: String, _ cm: Double) -> some View {
        VStack {
            Text(cm > 0 ? Units.value(cm: cm) : "—").font(.headline).foregroundStyle(DS.Color.primaryText)
            Text(label).font(.caption2).foregroundStyle(DS.Color.secondaryText)
        }
    }

    private var unsupported: some View {
        VStack(spacing: 14) {
            Image(systemName: "arkit").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("AR body measuring isn't supported on this device")
                .font(.title3.bold()).foregroundStyle(DS.Color.primaryText).multilineTextAlignment(.center)
            Text("It needs an A12 chip or newer. You can still edit measurements by hand.")
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryText)
            Button("Close") { onFinish() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(28)
    }

    private func save() async {
        guard let id = avatarId else { return }
        saving = true; defer { saving = false }
        let patch = MeasurementPatch(
            heightCm: ar.heightCm > 0 ? ar.heightCm : nil,
            inseamCm: ar.inseamCm > 0 ? ar.inseamCm : nil,
            shoulderCm: ar.shoulderCm > 0 ? ar.shoulderCm : nil,
            armCm: ar.armCm > 0 ? ar.armCm : nil,
            torsoCm: ar.torsoCm > 0 ? ar.torsoCm : nil)
        if (try? await session.api.patchMeasurements(avatarId: id, patch)) != nil {
            saved = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
