import SceneKit
import SwiftUI
import UIKit

/// Renders the measurement-based 3D avatar (+ selected clothes) with orbit /
/// pinch-zoom controls. Rebuilds when the garment selection changes.
struct AvatarSceneView: View {
    let measurements: MeasurementDTO?
    let garments: [GarmentDTO]

    var body: some View {
        SceneView(
            scene: makeScene(),
            options: [.allowsCameraControl, .autoenablesDefaultLighting]
        )
        .background(Color.clear)
        .accessibilityLabel("3D avatar preview. Drag to rotate, pinch to zoom.")
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        scene.rootNode.addChildNode(
            AvatarBuilder.makeBodyNode(measurements: measurements, garments: garments))

        // Key + fill lighting for a soft, product-like look.
        let key = SCNNode()
        key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 850
        key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)

        let ambient = SCNNode()
        ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 450
        scene.rootNode.addChildNode(ambient)

        // Camera framed to the figure height.
        let h = measurements?.heightCm.map { Float($0) / 100 } ?? 1.7
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.01
        camera.camera?.fieldOfView = 45
        camera.position = SCNVector3(0, 0, h * 1.7)
        scene.rootNode.addChildNode(camera)

        return scene
    }
}
