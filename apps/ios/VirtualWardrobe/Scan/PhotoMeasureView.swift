import PhotosUI
import SwiftUI
import UIKit
import Vision

/// Estimates real body proportions from a single full-body photo using the
/// Vision body-pose detector + your stated height. Gives real shoulder/arm/leg
/// ratios (scale-invariant × your height). Circumferences still stay estimated.
struct PhotoMeasureView: View {
    @EnvironmentObject var session: AuthStore
    let onFinish: () -> Void

    @State private var pick: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var heightText = ""
    @State private var result: MeasurementPatch?
    @State private var status = ""
    @State private var busy = false
    @State private var saved = false
    @State private var avatarId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Enter your height, pick a clear full-body photo, and we'll estimate your proportions.")
                            .font(.footnote).foregroundStyle(DS.Color.secondaryText)
                        HStack {
                            Text("Height").foregroundStyle(DS.Color.primaryText)
                            Spacer()
                            TextField("—", text: $heightText).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).frame(width: 90).foregroundStyle(DS.Color.primaryText)
                            Text(Units.system.suffix).foregroundStyle(DS.Color.secondaryText)
                        }.card()

                        PhotosPicker(selection: $pick, matching: .images) {
                            Label(image == nil ? "Choose photo" : "Change photo", systemImage: "photo")
                        }.buttonStyle(PrimaryButtonStyle())

                        if let image {
                            Image(uiImage: image).resizable().scaledToFit()
                                .frame(maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        if let r = result {
                            VStack(spacing: 8) {
                                metric("Height", r.heightCm)
                                metric("Shoulders", r.shoulderCm)
                                metric("Arm", r.armCm)
                                metric("Inseam", r.inseamCm)
                            }.card()
                            Button { Task { await save(r) } } label: {
                                if busy { ProgressView().tint(DS.Color.accent) }
                                else { Text(saved ? "Saved ✓" : "Use these measurements") }
                            }.buttonStyle(PrimaryButtonStyle())
                        } else if image != nil {
                            Button { analyze() } label: {
                                if busy { ProgressView().tint(DS.Color.accent) } else { Text("Analyze photo") }
                            }.buttonStyle(PrimaryButtonStyle(enabled: !busy && Units.toCm(heightText) != nil))
                                .disabled(busy || Units.toCm(heightText) == nil)
                        }
                        if !status.isEmpty {
                            Text(status).font(.footnote).foregroundStyle(.orange)
                        }
                    }.padding(20)
                }
            }
            .navigationTitle("Measure from photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { onFinish() } } }
            .onChange(of: pick) { Task { await loadImage() } }
            .task { avatarId = (try? await session.api.avatars())?.first?.id }
        }
        .tint(Theme.accent).preferredColorScheme(.dark)
    }

    private func metric(_ label: String, _ cm: Double?) -> some View {
        HStack { Text(label).foregroundStyle(DS.Color.primaryText); Spacer()
            Text(Units.display(cm: cm)).foregroundStyle(DS.Color.secondaryText) }
    }

    private func loadImage() async {
        result = nil; status = ""
        guard let data = try? await pick?.loadTransferable(type: Data.self) else { return }
        image = UIImage(data: data)
    }

    private func analyze() {
        guard let cg = image?.cgImage, let h = Units.toCm(heightText) else { return }
        busy = true; status = ""
        DispatchQueue.global(qos: .userInitiated).async {
            let req = VNDetectHumanBodyPoseRequest()
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
            guard let obs = req.results?.first as? VNHumanBodyPoseObservation,
                  let pts = try? obs.recognizedPoints(.all) else {
                finish(nil, "No body detected — try a clearer full-body photo."); return
            }
            let w = CGFloat(cg.width), ht = CGFloat(cg.height)
            func p(_ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let pt = pts[j], pt.confidence > 0.2 else { return nil }
                return CGPoint(x: pt.location.x * w, y: (1 - pt.location.y) * ht)
            }
            func dist(_ a: CGPoint, _ b: CGPoint) -> Double { Double(hypot(a.x - b.x, a.y - b.y)) }
            guard let nose = p(.nose),
                  let ankle = p(.leftAnkle) ?? p(.rightAnkle),
                  let lSh = p(.leftShoulder), let rSh = p(.rightShoulder) else {
                finish(nil, "Couldn't read the pose — make sure the whole body is visible."); return
            }
            let bodyPx = Double(ankle.y - nose.y)
            guard bodyPx > 10 else { finish(nil, "Pose too small in frame."); return }
            let fullPx = bodyPx / 0.87
            let cmPerPx = h / fullPx
            var patch = MeasurementPatch(heightCm: h)
            patch.shoulderCm = dist(lSh, rSh) * cmPerPx
            if let wrist = p(.leftWrist) ?? p(.rightWrist) {
                patch.armCm = dist(lSh, wrist) * cmPerPx
            }
            if let hip = p(.leftHip) ?? p(.rightHip) {
                patch.inseamCm = dist(hip, ankle) * cmPerPx
            }
            finish(patch, "")
        }
    }

    private func finish(_ patch: MeasurementPatch?, _ msg: String) {
        DispatchQueue.main.async {
            self.busy = false; self.status = msg; self.result = patch
        }
    }

    private func save(_ patch: MeasurementPatch) async {
        guard let id = avatarId else { status = "No avatar to update — run a scan first."; return }
        busy = true; defer { busy = false }
        if (try? await session.api.patchMeasurements(avatarId: id, patch)) != nil {
            saved = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
