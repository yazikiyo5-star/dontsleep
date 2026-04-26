import Foundation

/// A single ad unit ready to render. Providers convert their native
/// formats (EthicalAds decision JSON, our own house-ad JSON, a static
/// bundled fallback) into this shape so `AdBannerView` doesn't need to
/// know about any specific network.
struct AdCreative: Equatable {

    /// Stable identifier so we can avoid showing the same creative twice
    /// in a row and so impression pings can be deduped.
    let id: String

    /// Short label that goes above the headline ("Sponsored",
    /// "Community", "Self-promotion", ...).
    let attribution: String

    /// One-line primary copy.
    let headline: String

    /// Optional secondary copy (shown in smaller/secondary text).
    let body: String?

    /// Optional URL of a small square image (<= 64x64 recommended).
    /// Fetched asynchronously; if it fails we just fall back to the
    /// built-in SF Symbol icon.
    let imageURL: URL?

    /// SF Symbol name to show when there is no image. Defaults to a
    /// neutral "megaphone" glyph. Providers may override per creative.
    let fallbackSymbol: String

    /// Where clicks should go. For networks this is already wrapped in
    /// their click-tracking redirect.
    let clickURL: URL

    /// URL to GET once when the ad becomes visible. Nil = no tracking.
    /// EthicalAds calls this the "view_url".
    let impressionURL: URL?

    /// Where this creative came from. Useful for logging.
    let sourceName: String
}
