import AVFoundation
import Metal
import SceneKit
import UIKit

/// Renders a short spinning video of the dressed avatar to an .mp4 for sharing.
enum AvatarVideoExporter {
    static func exportSpin(measurements: MeasurementDTO?, garments: [GarmentDTO],
                           size: CGSize = CGSize(width: 720, height: 1280),
                           frames: Int = 72, fps: Int32 = 24,
                           completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let device = MTLCreateSystemDefaultDevice() else { return done(nil, completion) }
            let renderer = SCNRenderer(device: device, options: nil)
            let scene = buildScene(measurements: measurements, garments: garments)
            renderer.scene = scene
            guard let camera = scene.rootNode.childNode(withName: "cam", recursively: false)
            else { return done(nil, completion) }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("wardrobe-\(UUID().uuidString).mp4")
            guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4)
            else { return done(nil, completion) }
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: size.width,
                    kCVPixelBufferHeightKey as String: size.height,
                ])
            guard writer.canAdd(input) else { return done(nil, completion) }
            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            let h = measurements?.heightCm.map { Float($0) / 100 } ?? 1.7
            for i in 0..<frames {
                let angle = Float(i) / Float(frames) * 2 * .pi
                camera.position = SCNVector3(sin(angle) * h * 1.7, 0, cos(angle) * h * 1.7)
                camera.look(at: SCNVector3(0, 0, 0))
                let image = renderer.snapshot(atTime: 0, with: size,
                                              antialiasingMode: .multisampling4X)
                guard let buffer = pixelBuffer(from: image, size: size) else { continue }
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
                let time = CMTime(value: CMTimeValue(i), timescale: fps)
                adaptor.append(buffer, withPresentationTime: time)
            }
            input.markAsFinished()
            writer.finishWriting { done(writer.status == .completed ? url : nil, completion) }
        }
    }

    private static func done(_ url: URL?, _ completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async { completion(url) }
    }

    private static func buildScene(measurements: MeasurementDTO?, garments: [GarmentDTO]) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 1)
        scene.rootNode.addChildNode(
            AvatarBuilder.makeBodyNode(measurements: measurements, garments: garments))
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional
        key.light?.intensity = 850; key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)
        let amb = SCNNode(); amb.light = SCNLight(); amb.light?.type = .ambient; amb.light?.intensity = 500
        scene.rootNode.addChildNode(amb)
        let cam = SCNNode(); cam.name = "cam"; cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 45
        scene.rootNode.addChildNode(cam)
        return scene
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32ARGB, attrs, &pb)
        guard let buffer = pb, let cg = image.cgImage else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                            width: Int(size.width), height: Int(size.height),
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        ctx?.draw(cg, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
