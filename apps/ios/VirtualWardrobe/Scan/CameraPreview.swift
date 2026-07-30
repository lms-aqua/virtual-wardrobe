import AVFoundation
import SwiftUI

/// Bridges the AVCaptureSession into SwiftUI as a live preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// A stylized body silhouette + framing guide drawn over the preview.
struct SilhouetteOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Dim the area outside the framing box.
                Color.black.opacity(0.35).ignoresSafeArea()
                    .mask {
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .frame(width: w * 0.7, height: h * 0.82)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    }
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Theme.accent.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .frame(width: w * 0.7, height: h * 0.82)
                Image(systemName: "figure.stand")
                    .resizable().scaledToFit()
                    .frame(height: h * 0.7)
                    .foregroundStyle(.white.opacity(0.12))
            }
        }
        .allowsHitTesting(false)
    }
}
