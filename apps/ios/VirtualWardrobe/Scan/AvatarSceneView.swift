import SceneKit
import SwiftUI
import UIKit

enum CameraPreset { case front, side, back }

/// Owns the SCNView + scene so the parent can drive camera presets, rebuild the
/// outfit, and grab a snapshot. The measurement-based avatar is HONEST — a
/// stylized 3D preview, not a photo reconstruction. Used only from the main
/// thread (SwiftUI views + UIViewRepresentable).
final class AvatarSceneController: ObservableObject {
    let scnView = SCNView()
    private let cameraNode = SCNNode()
    private var figureHeight: Float = 1.7
    private var configured = false
    private var currentMeasurements: MeasurementDTO?
    private var bodyNode = SCNNode()

    func configure() {
        guard !configured else { return }
        configured = true
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false

        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.fieldOfView = 45
        scene.rootNode.addChildNode(cameraNode)

        let key = SCNNode()
        key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 850
        key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)
        let ambient = SCNNode()
        ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 460
        scene.rootNode.addChildNode(ambient)

        scnView.scene = scene
        scnView.pointOfView = cameraNode
    }

    func update(measurements: MeasurementDTO?, garments: [GarmentDTO]) {
        configure()
        currentMeasurements = measurements
        figureHeight = measurements?.heightCm.map { Float($0) / 100 } ?? 1.7
        bodyNode.removeFromParentNode()
        bodyNode = AvatarBuilder.makeBodyNode(measurements: measurements, garments: garments)
        scnView.scene?.rootNode.addChildNode(bodyNode)
        setPreset(.front, animated: false)
    }

    func setPreset(_ preset: CameraPreset, animated: Bool = true) {
        let d = figureHeight * 1.7
        let pos: SCNVector3
        switch preset {
        case .front: pos = SCNVector3(0, 0, d)
        case .side:  pos = SCNVector3(d, 0, 0)
        case .back:  pos = SCNVector3(0, 0, -d)
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.45 : 0
        cameraNode.position = pos
        cameraNode.look(at: SCNVector3(0, 0, 0))
        SCNTransaction.commit()
    }

    func snapshot() -> UIImage { scnView.snapshot() }
}

/// SwiftUI bridge for the controller's SCNView.
struct AvatarSceneView: UIViewRepresentable {
    @ObservedObject var controller: AvatarSceneController
    func makeUIView(context: Context) -> SCNView {
        controller.configure()
        return controller.scnView
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
