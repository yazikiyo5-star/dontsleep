import Foundation

/// Simple UserDefaults-backed preferences store.
final class Preferences {

    private let defaults = UserDefaults.standard

    private enum Key {
        static let watchedProcessNames = "watchedProcessNames"   // legacy; still used
        static let watchedAppBundleIDs = "watchedAppBundleIDs"   // new in v1.0
        static let hasCompletedOnboarding = "hasCompletedOnboarding" // new in v1.0
        static let launchAtLogin       = "launchAtLogin"         // new in v1.0
        static let suppressionMode     = "suppressionMode"
        static let adsEnabled          = "adsEnabled"
        static let adProviderKind      = "adProviderKind"
        static let houseAdsFeedURL     = "houseAdsFeedURL"
        static let ethicalAdsPublisher = "ethicalAdsPublisher"
    }

    init() {
        defaults.register(defaults: [
            Key.watchedProcessNames: defaultCLIList,
            Key.watchedAppBundleIDs: defaultBundleIDList,
            Key.hasCompletedOnboarding: false,
            Key.launchAtLogin: true,
            Key.suppressionMode: SuppressionMode.caffeinate.rawValue,
            Key.adsEnabled: true,
            Key.adProviderKind: AdProviderKind.house.rawValue,
            Key.houseAdsFeedURL: "",
            Key.ethicalAdsPublisher: ""
        ])
    }

    /// Default CLI tools we watch out of the box.
    /// Users can edit this list in the Preferences window.
    private let defaultCLIList: [String] = [
        "claude",          // Claude Code CLI
        "codex",           // OpenAI Codex CLI
        "aider",           // Aider AI coding assistant
        "ollama"           // local LLM server
    ]

    /// Default GUI app bundle IDs we watch out of the box.
    /// These ship as preset suggestions during onboarding; users can toggle
    /// them on/off in the app selection screen.
    private let defaultBundleIDList: [String] = []

    // MARK: - Watched CLI process names (legacy key reused)

    /// Process names watched for CLI tools (claude, codex, etc.).
    /// Retained in the legacy `watchedProcessNames` key for migration
    /// compatibility with earlier builds.
    var watchedCLINames: [String] {
        get {
            (defaults.array(forKey: Key.watchedProcessNames) as? [String]) ?? defaultCLIList
        }
        set {
            defaults.set(newValue, forKey: Key.watchedProcessNames)
        }
    }

    // MARK: - Watched GUI app bundle IDs (new)

    /// Bundle identifiers of GUI apps the user has selected to monitor.
    var watchedAppBundleIDs: [String] {
        get {
            (defaults.array(forKey: Key.watchedAppBundleIDs) as? [String]) ?? []
        }
        set {
            defaults.set(newValue, forKey: Key.watchedAppBundleIDs)
        }
    }

    // MARK: - Onboarding flag

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    // MARK: - Suppression mode

    var suppressionMode: SuppressionMode {
        get {
            let raw = defaults.string(forKey: Key.suppressionMode) ?? SuppressionMode.caffeinate.rawValue
            return SuppressionMode(rawValue: raw) ?? .caffeinate
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.suppressionMode)
        }
    }

    // MARK: - Ads

    /// Whether to show the floating ad banner while suppression is active.
    /// Defaults to true (free tier). Users can disable it in Preferences.
    var adsEnabled: Bool {
        get { defaults.bool(forKey: Key.adsEnabled) }
        set { defaults.set(newValue, forKey: Key.adsEnabled) }
    }

    /// Which ad network to use. Defaults to `.house` (self-hosted).
    var adProviderKind: AdProviderKind {
        get {
            let raw = defaults.string(forKey: Key.adProviderKind) ?? AdProviderKind.house.rawValue
            return AdProviderKind(rawValue: raw) ?? .house
        }
        set { defaults.set(newValue.rawValue, forKey: Key.adProviderKind) }
    }

    /// URL of the JSON feed used by HouseAdProvider. Empty = use bundled
    /// fallback only.
    var houseAdsFeedURL: URL? {
        get {
            let s = defaults.string(forKey: Key.houseAdsFeedURL) ?? ""
            return URL(string: s)
        }
        set { defaults.set(newValue?.absoluteString ?? "", forKey: Key.houseAdsFeedURL) }
    }

    var houseAdsFeedURLString: String {
        get { defaults.string(forKey: Key.houseAdsFeedURL) ?? "" }
        set { defaults.set(newValue, forKey: Key.houseAdsFeedURL) }
    }

    /// EthicalAds publisher id. Empty = EthicalAds provider returns nil.
    var ethicalAdsPublisher: String {
        get { defaults.string(forKey: Key.ethicalAdsPublisher) ?? "" }
        set { defaults.set(newValue, forKey: Key.ethicalAdsPublisher) }
    }
}
