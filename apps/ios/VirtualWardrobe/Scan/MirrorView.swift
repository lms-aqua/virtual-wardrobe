import ARKit
import SceneKit
import SwiftUI
import UIKit

/// AR "magic mirror": overlays garment shells on your live, body-tracked figure.
/// BETA — approximate placement, and untestable without a device. Needs A12+.
final class MirrorController: NSObject, ObservableObject, ARSCNViewDelegate {
    let arView = ARSCNView()
    @Published var supported = ARBodyTrackingConfiguration.isSupported
    @Published var bodyVisible = false

    private var garments: [GarmentDTO] = []
    private var clothingNode: SCNNode?

    func start() {
        guard supported else { return }
        arView.delegate = self
        arView.scene = SCNScene()
        arView.automaticallyUpdatesLighting = true
        arView.session.run(ARBodyTrackingConfiguration(),
                           options: [.resetTracking, .removeExistingAnchors])
    }
    func stop() { arView.session.pause() }
    func setGarments(_ g: [GarmentDTO]) { garments = g; rebuild() }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARBodyAnchor else { return }
        let container = SCNNode()
        node.addChildNode(container)
        clothingNode = container
        DispatchQueue.main.async { self.bodyVisible = true }
        rebuild()
    }
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARBodyAnchor else { return }
        DispatchQueue.main.async { self.bodyVisible = false }
    }

    private func rebuild() {
        guard let c = clothingNode else { return }
        c.childNodes.forEach { $0.removeFromParentNode() }
        for g in garments.sorted(by: { $0.layeringOrder < $1.layeringOrder }) { addShell(g, to: c) }
    }

    /// Nominal adult placement relative to the hip-root anchor (meters, y up).
    private func addShell(_ g: GarmentDTO, to parent: SCNNode) {
        let color = UIColor(GarmentAppearance.of(g).color)
        let mat = SCNMaterial(); mat.diffuse.contents = color; mat.lightingModel = .physicallyBased
        func node(_ geo: SCNGeometry, _ pos: SCNVector3) {
            geo.materials = [mat]; let n = SCNNode(geometry: geo); n.position = pos
            parent.addChildNode(n)
        }
        switch GarmentAppearance.regionFor(g.category) {
        case .top:
            node(SCNCone(topRadius: 0.16, bottomRadius: 0.15, height: 0.42), SCNVector3(0, 0.24, 0))
        case .outerwear:
            node(SCNCone(topRadius: 0.19, bottomRadius: 0.18, height: 0.55), SCNVector3(0, 0.22, 0))
        case .dress:
            node(SCNCone(topRadius: 0.16, bottomRadius: 0.28, height: 0.75), SCNVector3(0, 0.08, 0))
        case .bottom:
            for side: Float in [-1, 1] {
                node(SCNCapsule(capRadius: 0.09, height: 0.7), SCNVector3(side * 0.09, -0.38, 0))
            }
        case .footwear:
            for side: Float in [-1, 1] {
                node(SCNBox(width: 0.1, height: 0.07, length: 0.24, chamferRadius: 0.03),
                     SCNVector3(side * 0.09, -0.78, 0.06))
            }
        case .unknown: break
        }
    }
}

struct MirrorContainer: UIViewRepresentable {
    let controller: MirrorController
    func makeUIView(context: Context) -> ARSCNView { controller.arView }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct MirrorView: View {
    @EnvironmentObject var session: AuthStore
    let onFinish: () -> Void
    @StateObject private var mirror = MirrorController()
    @State private var garments: [GarmentDTO] = []
    @State private var selected: Set<String> = []

    private var chosen: [GarmentDTO] { garments.filter { selected.contains($0.id) } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if mirror.supported {
                MirrorContainer(controller: mirror).ignoresSafeArea()
                overlay
            } else {
                unsupported
            }
        }
        .task { garments = (try? await session.api.garments()) ?? []; mirror.start() }
        .onDisappear { mirror.stop() }
    }

    private var overlay: some View {
        VStack {
            HStack {
                Text(mirror.bodyVisible ? "Body tracked · move back for full body" : "Point at a person…")
                    .font(.caption.bold()).foregroundStyle(DS.Color.primaryText)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Button("Close") { onFinish() }.foregroundStyle(DS.Color.primaryText)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
            }.padding()
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(garments) { g in
                        GarmentChip(garment: g, selected: selected.contains(g.id)) { toggle(g.id) }
                    }
                }.padding()
            }
            .background(.ultraThinMaterial)
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        mirror.setGarments(chosen)
    }

    private var unsupported: some View {
        VStack(spacing: 14) {
            Image(systemName: "arkit").font(.system(size: 44)).foregroundStyle(Theme.accent)
            Text("AR mirror needs a device with an A12 chip or newer")
                .font(.title3.bold()).foregroundStyle(DS.Color.primaryText).multilineTextAlignment(.center)
            Button("Close") { onFinish() }.buttonStyle(PrimaryButtonStyle())
        }.padding(28)
    }
}
