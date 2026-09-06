import SwiftUI

/// An image that stays loaded.
///
/// `AsyncImage` re-fetches whenever its view is rebuilt, and it keeps nothing between
/// one appearance and the next. On this app that showed up as headshots blinking out
/// whenever the weekly view was rebuilt — most obviously on returning from a league,
/// where every card is reconstructed and forty faces start again from nothing, several
/// of them losing the race and landing on a placeholder until the next refresh.
///
/// This keeps decoded images in memory, keyed by URL, so a face that has been seen once
/// renders on the very first frame of the next appearance with no request at all. The
/// disk half is `URLCache`, which `URLSession` uses automatically — headshots are static
/// files with long cache headers, so the second launch of the app is nearly free too.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    /// In-flight requests, so ten rows asking for the same defense logo at the same
    /// moment make one request rather than ten.
    private var loading: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        // Roughly a few hundred headshots. NSCache evicts under pressure by itself.
        memory.countLimit = 400
    }

    func cached(_ url: URL) -> UIImage? { memory.object(forKey: url as NSURL) }

    func load(_ url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let existing = loading[url] { return await existing.value }

        let task = Task<UIImage?, Never> {
            var request = URLRequest(url: url)
            // Headshots do not change. Prefer whatever is on disk over a round trip.
            request.cachePolicy = .returnCacheDataElseLoad
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let image = UIImage(data: data) else { return nil }
            return image
        }
        loading[url] = task
        let image = await task.value
        loading[url] = nil
        if let image { memory.setObject(image, forKey: url as NSURL) }
        return image
    }

    /// Sized generously and set up once at launch: headshots are small, and a hundred
    /// megabytes of them is the difference between a warm start and forty requests.
    static func configureDiskCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
    }
}

/// The view. Renders a cached image immediately and synchronously — the whole point is
/// that a face already seen never flickers back to a placeholder.
struct CachedImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image ?? url.flatMap({ ImageCache.shared.cached($0) }) {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            // Already warm: nothing to do, and no frame where the placeholder shows.
            if ImageCache.shared.cached(url) != nil { return }
            image = await ImageCache.shared.load(url)
        }
    }
}
