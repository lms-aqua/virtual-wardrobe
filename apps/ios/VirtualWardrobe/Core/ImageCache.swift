import SwiftUI
import UIKit

/// Two-tier cache for remote garment imagery.
///
/// `AsyncImage` keeps no cache of its own, so scrolling the wardrobe refetched
/// and re-decoded the same thumbnails every time a cell came back on screen.
/// This adds a decoded-image memory cache in front of an HTTP disk cache, which
/// also means a relaunch — or a launch with no connection — still paints any
/// thumbnail that has been seen before.
enum ImageCache {

    /// Decoded images. `NSCache` evicts automatically under memory pressure, so
    /// this never competes with the 3D avatar for headroom.
    private static let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    /// Raw HTTP responses on disk. `returnCacheDataElseLoad` is what makes
    /// previously-seen garments render while offline.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "vw.images"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    /// Synchronous hit, used to paint instantly without a loading flash.
    static func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    static func load(_ url: URL) async throws -> UIImage {
        if let hit = cached(url) { return hit }
        let (data, _) = try await session.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Used by "delete everything" so cached imagery does not outlive the data.
    static func clear() {
        memory.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }
}

enum CachedImagePhase {
    case loading
    case success(Image)
    case failure
}

/// Drop-in replacement for `AsyncImage` that reads through `ImageCache`.
///
/// A cache hit resolves synchronously in `init`, so a revisited cell paints its
/// image on first render rather than flashing a placeholder.
struct CachedImage<Content: View>: View {
    let url: URL?
    @ViewBuilder var content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase

    init(url: URL?, @ViewBuilder content: @escaping (CachedImagePhase) -> Content) {
        self.url = url
        self.content = content
        if let url, let hit = ImageCache.cached(url) {
            _phase = State(initialValue: .success(Image(uiImage: hit)))
        } else {
            _phase = State(initialValue: url == nil ? .failure : .loading)
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .failure
            return
        }
        if let hit = ImageCache.cached(url) {
            phase = .success(Image(uiImage: hit))
            return
        }
        phase = .loading
        do {
            let image = try await ImageCache.load(url)
            // .task is cancelled when the cell scrolls away; don't publish then.
            guard !Task.isCancelled else { return }
            phase = .success(Image(uiImage: image))
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failure
        }
    }
}
