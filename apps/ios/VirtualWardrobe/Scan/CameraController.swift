import AVFoundation
import UIKit

/// Thin wrapper around AVCaptureSession for still capture. LiDAR/depth capture
/// (Phase 7 advanced) plugs in here later behind the same interface; for now we
/// capture guided still images the backend turns into a (mock) avatar.
@MainActor
final class CameraController: NSObject, ObservableObject {
    @Published var authorized = false
    @Published var running = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<Data, Error>?

    func requestAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined:
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        if authorized { configure() }
    }

    private func configure() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    func start() {
        guard authorized, !session.isRunning else { return }
        Task.detached { [session] in session.startRunning() }
        running = true
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
        running = false
    }

    /// Capture one JPEG. Returns the image data.
    func capture() async throws -> Data {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        return try await withCheckedThrowingContinuation { cont in
            self.captureContinuation = cont
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                captureContinuation?.resume(throwing: error)
            } else if let data = photo.fileDataRepresentation() {
                captureContinuation?.resume(returning: data)
            } else {
                captureContinuation?.resume(throwing: APIError.network("capture failed"))
            }
            captureContinuation = nil
        }
    }
}
