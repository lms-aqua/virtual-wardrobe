import SwiftUI
import UIKit

/// Wraps a UIActivityViewController for SwiftUI (share a snapshot, etc.).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so we can present an image via `.sheet(item:)`.
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Identifiable wrapper for sharing an exported video file URL.
struct ShareVideo: Identifiable {
    let id = UUID()
    let url: URL
}
