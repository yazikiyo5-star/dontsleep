import Foundation

/// Self-hosted ad provider.
///
/// Fetches a JSON document from `feedURL` (e.g. a plain file on
/// GitHub Pages or Cloudflare Pages) and rotates through the entries.
/// If the fetch fails, we serve a small built-in list so the banner
/// still shows something useful (self-promotion / donation links).
///
/// Feed JSON format (array of objects):
/// ```json
/// [
///   {
///     "id": "abc123",
///     "attribution": "Sponsored",
///     "headline": "Headline text (<= 60 chars)",
///     "body": "Optional subheadline",
///     "imageUrl": "https://.../icon.png",
///     "fallbackSymbol": "cup.and.saucer.fill",
///     "clickUrl": "https://example.com/landing",
///     "impressionUrl": "https://example.com/pixel.gif",
///     "weight": 1.0
///   }
/// ]
/// ```
/// All fields except `id`, `headline`, and `clickUrl` are optional.
final class HouseAdProvider: AdProvider {

    let name = "house"

    private let feedURL: URL?
    private let session: URLSession
    private let refreshInterval: TimeInterval = 60 * 60   // 1 hour

    // Cached creatives + last-fetch timestamp.
    private var cached: [AdCreative] = HouseAdProvider.bundledFallback
    private var lastFetchedAt: Date?
    private var rotationIndex: Int = 0
    private let lock = NSLock()

    init(feedURL: URL?) {
        self.feedURL = feedURL

        // Short timeouts: ads should never block the UI for long.
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 20
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
    }

    func nextCreative(completion: @escaping (AdCreative?) -> Void) {
        refreshIfNeeded { [weak self] in
            guard let self = self else { return }
            let next = self.pickNext()
            DispatchQueue.main.async { completion(next) }
        }
    }

    // MARK: - Rotation

    private func pickNext() -> AdCreative? {
        lock.lock()
        defer { lock.unlock() }
        guard !cached.isEmpty else { return nil }
        let c = cached[rotationIndex % cached.count]
        rotationIndex = (rotationIndex + 1) % cached.count
        return c
    }

    // MARK: - Feed fetching

    private func refreshIfNeeded(then: @escaping () -> Void) {
        lock.lock()
        let needsFetch: Bool
        if let t = lastFetchedAt {
            needsFetch = Date().timeIntervalSince(t) > refreshInterval
        } else {
            needsFetch = true
        }
        lock.unlock()

        guard needsFetch, let url = feedURL else {
            then()
            return
        }

        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { then(); return }
            defer { then() }

            guard error == nil, let data = data,
                  let parsed = Self.parseFeed(data: data), !parsed.isEmpty else {
                // Keep the previous cached list (or the bundled fallback).
                self.lock.lock()
                self.lastFetchedAt = Date() // Back off until the next interval.
                self.lock.unlock()
                return
            }

            self.lock.lock()
            self.cached = parsed
            self.lastFetchedAt = Date()
            self.rotationIndex = 0
            self.lock.unlock()
        }.resume()
    }

    private static func parseFeed(data: Data) -> [AdCreative]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let rawArray: [[String: Any]]
        if let arr = root as? [[String: Any]] {
            rawArray = arr
        } else if let obj = root as? [String: Any],
                  let arr = obj["ads"] as? [[String: Any]] {
            rawArray = arr
        } else {
            return nil
        }

        return rawArray.compactMap { item -> AdCreative? in
            guard let id = item["id"] as? String,
                  let headline = item["headline"] as? String,
                  let clickString = item["clickUrl"] as? String,
                  let click = URL(string: clickString) else { return nil }
            return AdCreative(
                id: id,
                attribution: (item["attribution"] as? String) ?? "Sponsored",
                headline: headline,
                body: item["body"] as? String,
                imageURL: (item["imageUrl"] as? String).flatMap(URL.init(string:)),
                fallbackSymbol: (item["fallbackSymbol"] as? String) ?? "megaphone.fill",
                clickURL: click,
                impressionURL: (item["impressionUrl"] as? String).flatMap(URL.init(string:)),
                sourceName: "house"
            )
        }
    }

    // MARK: - Bundled fallback

    /// Shown when the remote feed is unreachable. Keeps the banner from
    /// ever looking "broken" and gives us a place to promote the app
    /// itself / accept donations.
    private static let bundledFallback: [AdCreative] = [
        AdCreative(
            id: "builtin-homepage",
            attribution: "About",
            headline: "DontSleep keeps your Mac awake",
            body: "Learn more about the project",
            imageURL: nil,
            fallbackSymbol: "cup.and.saucer.fill",
            clickURL: URL(string: "https://github.com/")!,
            impressionURL: nil,
            sourceName: "house-fallback"
        ),
        AdCreative(
            id: "builtin-sponsor",
            attribution: "Support",
            headline: "Support the developer",
            body: "GitHub Sponsors / Buy Me a Coffee",
            imageURL: nil,
            fallbackSymbol: "heart.fill",
            clickURL: URL(string: "https://github.com/sponsors")!,
            impressionURL: nil,
            sourceName: "house-fallback"
        )
    ]
}
