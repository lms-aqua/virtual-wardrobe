import SceneKit
import SwiftUI
import UIKit

/// Builds a stylized 3D humanoid from the avatar's measurements, plus optional
/// clothing shells. This is an HONEST measurement-based preview — not a
/// photogrammetric reconstruction. Feet sit at y = 0, figure faces +z.
enum AvatarBuilder {

    /// Resolved body dimensions in meters.
    private struct Dims {
        let height: Float
        let shoulderW: Float
        let chestR: Float
        let waistR: Float
        let hipR: Float
        let inseam: Float
        let torsoLen: Float
        let armLen: Float
        let thighR: Float
        let calfR: Float
        let neckR: Float
        let headR: Float
    }

    private static func circR(_ cm: Double?, _ fallback: Float) -> Float {
        guard let cm, cm > 0 else { return fallback }
        return Float(cm) / 100 / (2 * .pi)
    }
    private static func m(_ cm: Double?, _ fallback: Float) -> Float {
        guard let cm, cm > 0 else { return fallback }
        return Float(cm) / 100
    }

    private static func dims(_ meas: MeasurementDTO?) -> Dims {
        let h = m(meas?.heightCm, 1.70)
        return Dims(
            height: h,
            shoulderW: m(meas?.shoulderCm, h * 0.259),
            chestR: circR(meas?.chestCm, h * 0.082),
            waistR: circR(meas?.waistCm, h * 0.068),
            hipR: circR(meas?.hipCm, h * 0.083),
            inseam: m(meas?.inseamCm, h * 0.45),
            torsoLen: m(meas?.torsoCm, h * 0.30),
            armLen: m(meas?.armCm, h * 0.44),
            thighR: circR(meas?.thighCm, h * 0.05),
            calfR: circR(meas?.calfCm, h * 0.035),
            neckR: circR(meas?.neckCm, h * 0.032),
            headR: h * 0.047
        )
    }

    private static func mat(_ color: UIColor, metal: Float = 0, rough: Float = 0.85) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .physicallyBased
        m.metalness.contents = metal
        m.roughness.contents = rough
        return m
    }

    private static func skin() -> UIColor { UIColor(red: 0.85, green: 0.71, blue: 0.61, alpha: 1) }

    static func makeBodyNode(measurements: MeasurementDTO?, garments: [GarmentDTO]) -> SCNNode {
        let d = dims(measurements)
        let root = SCNNode()
        let skinMat = mat(skin())

        func add(_ geo: SCNGeometry, _ pos: SCNVector3,
                 material: SCNMaterial, euler: SCNVector3 = SCNVector3Zero) {
            geo.materials = [material]
            let n = SCNNode(geometry: geo)
            n.position = pos
            n.eulerAngles = euler
            root.addChildNode(n)
        }

        // Legs (feet at 0 → pelvis at inseam)
        let legOffset = d.hipR * 0.55
        for side: Float in [-1, 1] {
            let thigh = SCNCapsule(capRadius: CGFloat(d.thighR), height: CGFloat(d.inseam * 0.55))
            add(thigh, SCNVector3(side * legOffset, d.inseam * 0.72, 0), material: skinMat)
            let calf = SCNCapsule(capRadius: CGFloat(d.calfR), height: CGFloat(d.inseam * 0.55))
            add(calf, SCNVector3(side * legOffset, d.inseam * 0.28, 0), material: skinMat)
            // foot
            let foot = SCNBox(width: CGFloat(d.calfR * 2), height: 0.05,
                              length: CGFloat(d.headR * 2.6), chamferRadius: 0.02)
            add(foot, SCNVector3(side * legOffset, 0.03, d.headR * 0.7), material: skinMat)
        }

        // Pelvis → waist → chest (tapered) up to shoulders.
        let pelvisY = d.inseam
        let lowerH = d.torsoLen * 0.45
        let upperH = d.torsoLen * 0.55
        let lower = SCNCone(topRadius: CGFloat(d.waistR), bottomRadius: CGFloat(d.hipR),
                            height: CGFloat(lowerH))
        add(lower, SCNVector3(0, pelvisY + lowerH / 2, 0), material: skinMat)
        let upper = SCNCone(topRadius: CGFloat(d.chestR), bottomRadius: CGFloat(d.waistR),
                            height: CGFloat(upperH))
        add(upper, SCNVector3(0, pelvisY + lowerH + upperH / 2, 0), material: skinMat)

        let shoulderY = pelvisY + d.torsoLen
        // Shoulder bar
        let shoulder = SCNCapsule(capRadius: CGFloat(d.chestR * 0.5), height: CGFloat(d.shoulderW))
        add(shoulder, SCNVector3(0, shoulderY, 0), material: skinMat,
            euler: SCNVector3(0, 0, Float.pi / 2))

        // Arms hang from shoulder ends.
        for side: Float in [-1, 1] {
            let arm = SCNCapsule(capRadius: CGFloat(d.chestR * 0.28), height: CGFloat(d.armLen))
            add(arm, SCNVector3(side * (d.shoulderW / 2), shoulderY - d.armLen / 2, 0),
                material: skinMat)
        }

        // Neck + head
        let neckLen = d.headR * 0.7
        let neck = SCNCylinder(radius: CGFloat(d.neckR), height: CGFloat(neckLen))
        add(neck, SCNVector3(0, shoulderY + neckLen / 2, 0), material: skinMat)
        let head = SCNSphere(radius: CGFloat(d.headR))
        add(head, SCNVector3(0, shoulderY + neckLen + d.headR * 0.95, 0), material: skinMat)

        // Clothing shells, ordered by layer_index.
        for g in garments.sorted(by: { $0.layeringOrder < $1.layeringOrder }) {
            addGarment(g, to: root, d: d, pelvisY: pelvisY, shoulderY: shoulderY, legOffset: legOffset)
        }

        // Center the figure vertically around origin for nicer framing.
        root.position = SCNVector3(0, -d.height / 2, 0)
        return root
    }

    private static func addGarment(_ g: GarmentDTO, to root: SCNNode, d: Dims,
                                   pelvisY: Float, shoulderY: Float, legOffset: Float) {
        let ap = GarmentAppearance.of(g)
        let color = UIColor(ap.color)
        let clothMat = mat(color, rough: 0.7)
        let name = g.name.lowercased()

        func add(_ geo: SCNGeometry, _ pos: SCNVector3, euler: SCNVector3 = SCNVector3Zero) {
            geo.materials = [clothMat]
            let n = SCNNode(geometry: geo)
            n.position = pos; n.eulerAngles = euler
            root.addChildNode(n)
        }

        switch ap.region {
        case .top:
            let hh = d.torsoLen * 0.60
            add(SCNCone(topRadius: CGFloat(d.chestR * 1.14), bottomRadius: CGFloat(d.waistR * 1.16),
                        height: CGFloat(hh)),
                SCNVector3(0, shoulderY - hh / 2, 0))
        case .outerwear:
            let hh = d.torsoLen * 0.9
            add(SCNCone(topRadius: CGFloat(d.chestR * 1.22), bottomRadius: CGFloat(d.hipR * 1.2),
                        height: CGFloat(hh)),
                SCNVector3(0, shoulderY - hh / 2, 0))
            for side: Float in [-1, 1] {   // sleeves
                add(SCNCapsule(capRadius: CGFloat(d.chestR * 0.33), height: CGFloat(d.armLen * 0.9)),
                    SCNVector3(side * (d.shoulderW / 2), shoulderY - d.armLen * 0.45, 0))
            }
        case .dress:
            let hh = d.torsoLen + d.inseam * 0.45
            add(SCNCone(topRadius: CGFloat(d.chestR * 1.14), bottomRadius: CGFloat(d.hipR * 1.5),
                        height: CGFloat(hh)),
                SCNVector3(0, shoulderY - hh / 2, 0))
        case .bottom:
            if name.contains("skirt") {
                let hh = d.inseam * 0.45
                add(SCNCone(topRadius: CGFloat(d.waistR * 1.1), bottomRadius: CGFloat(d.hipR * 1.7),
                            height: CGFloat(hh)),
                    SCNVector3(0, pelvisY - hh * 0.1, 0))
            } else {   // trousers / jeans
                for side: Float in [-1, 1] {
                    add(SCNCapsule(capRadius: CGFloat(d.thighR * 1.18), height: CGFloat(d.inseam * 0.95)),
                        SCNVector3(side * legOffset, d.inseam * 0.5, 0))
                }
                add(SCNCone(topRadius: CGFloat(d.waistR * 1.08), bottomRadius: CGFloat(d.hipR * 1.14),
                            height: CGFloat(d.torsoLen * 0.35)),
                    SCNVector3(0, pelvisY + d.torsoLen * 0.12, 0))
            }
        case .footwear:
            for side: Float in [-1, 1] {
                add(SCNBox(width: CGFloat(d.calfR * 2.3), height: 0.07,
                           length: CGFloat(d.headR * 3.0), chamferRadius: 0.03),
                    SCNVector3(side * legOffset, 0.035 - d.height / 2 + d.height / 2, d.headR * 0.9))
            }
        case .unknown:
            break
        }
    }
}
