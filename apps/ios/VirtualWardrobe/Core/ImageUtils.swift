import UIKit

enum ImageUtils {
    /// Downscale a captured JPEG and re-encode at a lower quality so uploads are
    /// small and fast (full-res frames are ~1–3 MB each; this brings them to
    /// ~100–250 KB with plenty of detail for the mock pipeline).
    static func downscaledJPEG(_ data: Data, maxDim: CGFloat = 1080,
                               quality: CGFloat = 0.55) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxDim / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}
