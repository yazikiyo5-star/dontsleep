import Foundation

/// Abstraction over "where does the next ad come from".
///
/// Concrete providers:
/// - HouseAdProvider:     self-hosted JSON + bundled fallback (works today)
/// - EthicalAdsProvider:  POST to server.ethicalads.io/api/v1/decision/
///                        (activated once the publisher account is approved)
///
/// The protocol is intentionally async & callback-based so that remote
/// providers can do network I/O. A provider is allowed to return nil to
/// signal "no ad available right now, please try again later" — the UI
/// will hide the banner in that case.
protocol AdProvider: AnyObject {
    /// A human-readable name used for logging and for the "sourceName"
    /// field on returned creatives.
    var name: String { get }

    /// Request the next creative to show.
    /// - Parameter completion: invoked on the main queue with the
    ///   creative, or nil if none is available.
    func nextCreative(completion: @escaping (AdCreative?) -> Void)
}

/// A no-op provider used while we still have no network connectivity or
/// while the app boots. Returns nil so the banner stays hidden.
final class NullAdProvider: AdProvider {
    let name = "null"
    func nextCreative(completion: @escaping (AdCreative?) -> Void) {
        DispatchQueue.main.async { completion(nil) }
    }
}

/// Which provider the app is currently using. Exposed so the user can
/// choose in Preferences (or we can auto-fall-back if a network
/// provider starts erroring).
enum AdProviderKind: String, CaseIterable {
    case house       // self-hosted JSON + bundled fallback
    case ethicalAds  // EthicalAds REST API (requires publisher id)
}
