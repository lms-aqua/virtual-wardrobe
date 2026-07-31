import UIKit
import Vision

/// On-device check for "is there actually a person in this frame".
///
/// The scan pipeline never looked at the captured images: the server derives
/// measurements from the height you type, multiplied by fixed anthropometric
/// ratios, and its quality gate only counted frames and byte sizes. Pointing the
/// camera at a blank wall therefore produced a complete set of "measurements".
///
/// This does not measure anyone — it only refuses to submit a scan with no
/// visible body, so the app stops accepting input it cannot possibly use.
/// Real reconstruction still belongs behind the server's
/// `AvatarGenerationProvider` seam.
enum BodyDetector {

    /// A frame counts as usable when Vision finds a body pose with enough
    /// confidently-located joints to plausibly be a person in frame.
    private static let minimumConfidentJoints = 6
    private static let jointConfidenceThreshold: Float = 0.3

    /// True when a human body is visible in the frame.
    static func containsBody(_ jpeg: Data) -> Bool {
        guard let image = UIImage(data: jpeg), let cg = image.cgImage else { return false }

        let request = VNDetectHumanBodyPoseRequest()
        do {
            try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        } catch {
            // Vision failed outright — don't block the user on a detector fault.
            return true
        }

        guard let observation = request.results?.first as? VNHumanBodyPoseObservation,
              let points = try? observation.recognizedPoints(.all) else {
            return false
        }

        let confident = points.values.filter { $0.confidence >= jointConfidenceThreshold }
        return confident.count >= minimumConfidentJoints
    }

    /// Fraction of the supplied frames that contain a visible body.
    static func bodyFraction(in frames: [Data]) -> Double {
        guard !frames.isEmpty else { return 0 }
        // Sampling: pose detection is not free, and a 24-frame 360° capture does
        // not need every frame checked to establish whether a person was there.
        let stride = max(1, frames.count / 6)
        let sampled = Swift.stride(from: 0, to: frames.count, by: stride).map { frames[$0] }
        let hits = sampled.filter { containsBody($0) }.count
        return Double(hits) / Double(sampled.count)
    }

    /// At least this fraction of sampled frames must show a body for the scan to
    /// be worth uploading. Deliberately lenient: during a 360° turn some frames
    /// legitimately catch the subject mid-rotation or partially out of frame.
    static let requiredBodyFraction = 0.5

    static func framesLookLikeAPerson(_ frames: [Data]) -> Bool {
        bodyFraction(in: frames) >= requiredBodyFraction
    }
}
