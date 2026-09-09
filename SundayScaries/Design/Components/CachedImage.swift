import SwiftUI
import UIKit

/// An image that stays loaded, and a face that is never a blank circle.
///
/// `AsyncImage` re-fetches whenever its view is rebuilt, and it keeps nothing between
/// one appearance and the next. On this app that showed up as headshots blinking out
/// whenever the weekly view was rebuilt, most obviously on returning from a league,
/// where every card is reconstructed and forty faces start again from nothing, several
/// of them losing the race and landing on a placeholder until the next refresh.
///
/// This keeps decoded images in memory, keyed by URL, so a face that has been seen once
/// renders on the very first frame of the next appearance with no request at all. The
/// disk half is `URLCache`, which `URLSession` uses automatically. Headshots are static
/// files with long cache headers, so the second launch of the app is nearly free too.
///
/// Three things the first version got wrong, all of which read as "the faces don't
/// show up":
/// - A photo the CDN does not have (Sleeper answers 403, ESPN 404) was treated as still
///   loading, so the row sat on a dim placeholder forever instead of the initials.
///   A miss is now remembered, and the view falls back on the same frame.
/// - A request that failed once, a dropped connection in a burst of forty, was never
///   retried while the row stayed on screen. It gets one retry, then the fallback, and
///   the next appearance tries again.
/// - Decoding ran on the main thread, forty images at a time, in the middle of a load.
///   It runs detached now, and the decoded bitmap is capped at the largest size any face
///   is drawn at, so four hundred cached faces cost a few megabytes rather than a hundred.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    enum Outcome: Sendable {
        case image(UIImage)
        /// The server said there is no such image. Permanent for this launch.
        case missing
        /// The request did not complete. Worth another try.
        case failed
    }

    private let memory = NSCache<NSURL, UIImage>()
    /// URLs the server has answered "no image" for. Remembered so the row renders its
    /// fallback on the first frame instead of asking again on every appearance.
    private var missing: Set<URL> = []
    /// In-flight requests, so ten rows asking for the same defense logo at the same
    /// moment make one request rather than ten.
    private var loading: [URL: Task<Outcome, Never>] = [:]

    /// The longest side any face is drawn at (a 64pt portrait at 3x), so a 600px ESPN
    /// headshot is not kept at 600px.
    private static let maxPixels: CGFloat = 256

    private init() {
        // Roughly a few hundred headshots. NSCache evicts under pressure by itself.
        memory.countLimit = 400
    }

    func cached(_ url: URL) -> UIImage? { memory.object(forKey: url as NSURL) }

    func isMissing(_ url: URL) -> Bool { missing.contains(url) }

    func load(_ url: URL) async -> Outcome {
        if let hit = cached(url) { return .image(hit) }
        if missing.contains(url) { return .missing }
        if let existing = loading[url] { return await existing.value }

        let task = Task.detached(priority: .userInitiated) { () -> Outcome in
            await Self.fetch(url)
        }
        loading[url] = task
        let outcome = await task.value
        loading[url] = nil
        switch outcome {
        case let .image(image): memory.setObject(image, forKey: url as NSURL)
        case .missing:          missing.insert(url)
        case .failed:           break
        }
        return outcome
    }

    /// The network and the decode, off the main actor.
    nonisolated private static func fetch(_ url: URL) async -> Outcome {
        var request = URLRequest(url: url)
        // Headshots do not change. Prefer whatever is on disk over a round trip.
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return .failed }
        if let status = (response as? HTTPURLResponse)?.statusCode {
            // A missing photo is a 403 on Sleeper's CDN and a 404 on ESPN's. Neither
            // will change by asking again.
            if status == 403 || status == 404 { return .missing }
            guard (200...299).contains(status) else { return .failed }
        }
        guard let image = UIImage(data: data) else { return .missing }
        let longest = max(image.size.width, image.size.height) * image.scale
        if await longest > maxPixels {
            let scale = await maxPixels / longest
            let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            if let small = await image.byPreparingThumbnail(ofSize: target) { return .image(small) }
        }
        return .image(await image.byPreparingForDisplay() ?? image)
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

/// The view. Renders a cached image immediately and synchronously, so a face already
/// seen never flickers back to a placeholder, and renders the fallback, not the
/// placeholder, the moment the image is known not to exist.
struct CachedImage<Placeholder: View, Fallback: View>: View {
    let url: URL?
    /// Shown only while the first fetch is in flight.
    @ViewBuilder var placeholder: () -> Placeholder
    /// Shown when there is no image to show: the server has none, or it could not be
    /// fetched after a retry.
    @ViewBuilder var fallback: () -> Fallback

    private enum Phase { case loading, loaded(UIImage), unavailable }
    @State private var phase: Phase = .loading

    var body: some View {
        Group {
            if let image = warmImage {
                // The face is decorative here; `Headshot` hides the whole thing and the
                // row carries the name.
                Image(uiImage: image).resizable().accessibilityHidden(true)
            } else if isKnownMissing {
                fallback()
            } else if case .unavailable = phase {
                fallback()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { phase = .unavailable; return }
            if ImageCache.shared.cached(url) != nil || ImageCache.shared.isMissing(url) { return }
            phase = .loading
            switch await ImageCache.shared.load(url) {
            case let .image(image): phase = .loaded(image)
            case .missing: phase = .unavailable
            case .failed:
                // One more try, a beat later: the first failure in a burst is usually
                // the connection, not the image.
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                if case let .image(image) = await ImageCache.shared.load(url) {
                    phase = .loaded(image)
                } else {
                    phase = .unavailable
                }
            }
        }
    }

    /// What is already decoded, from this view's own state or from the shared cache, so
    /// nothing that has been seen once ever shows a placeholder again.
    private var warmImage: UIImage? {
        if case let .loaded(image) = phase { return image }
        return url.flatMap { ImageCache.shared.cached($0) }
    }

    private var isKnownMissing: Bool {
        url.map { ImageCache.shared.isMissing($0) } ?? true
    }
}
