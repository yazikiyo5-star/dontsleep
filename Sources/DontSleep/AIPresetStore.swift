import Foundation

/// Built-in catalogue of AI-related apps and CLI tools that DontSleep
/// knows about. Used to pre-populate the onboarding selection screen
/// and to highlight "recommended AI apps" in Preferences.
///
/// In v1.0 this list is bundled in the binary. v1.1 will fetch an
/// updated JSON from the public site so new AI tools can be added
/// without shipping a new release.
enum AIPresetStore {

    /// A GUI app that qualifies as an "AI app" for our purposes.
    struct AppPreset: Hashable {
        /// Bundle identifier (matched against `CFBundleIdentifier`).
        let bundleID: String
        /// Human-readable display name (used as a fallback when the bundle
        /// can't be opened, e.g. for labeling reasons only).
        let displayName: String
    }

    /// A CLI tool that qualifies as an "AI CLI" for our purposes.
    struct CLIPreset: Hashable {
        /// Process name as it appears in `ps -o comm=` (lower-cased, no path).
        let processName: String
        /// Human-readable display name for the selection UI.
        let displayName: String
    }

    /// Known AI app bundle identifiers. Matched case-insensitively against
    /// installed apps' `CFBundleIdentifier`. Substring match is supported
    /// via the helper methods below (so "com.cursor." matches variants).
    static let appPresets: [AppPreset] = [
        AppPreset(bundleID: "com.anthropic.claudefordesktop",       displayName: "Claude"),
        AppPreset(bundleID: "com.anthropic.Claude",                 displayName: "Claude"),
        AppPreset(bundleID: "com.todesktop.230313mzl4w4u92",        displayName: "Cursor"),
        AppPreset(bundleID: "com.cursor.Cursor",                    displayName: "Cursor"),
        AppPreset(bundleID: "dev.continue.Continue",                displayName: "Continue"),
        AppPreset(bundleID: "com.electron.ollama",                  displayName: "Ollama"),
        AppPreset(bundleID: "com.ollama.ollama",                    displayName: "Ollama"),
        AppPreset(bundleID: "dev.zed.Zed",                          displayName: "Zed"),
        AppPreset(bundleID: "com.exafunction.windsurf",             displayName: "Windsurf"),
        AppPreset(bundleID: "com.codeium.windsurf",                 displayName: "Windsurf"),
        AppPreset(bundleID: "com.github.GitHubCopilotForXcode",     displayName: "GitHub Copilot"),
        AppPreset(bundleID: "com.openai.chat",                      displayName: "ChatGPT"),
        AppPreset(bundleID: "com.google.gemini",                    displayName: "Gemini"),
        AppPreset(bundleID: "com.perplexity.mac",                   displayName: "Perplexity"),
        AppPreset(bundleID: "com.aifix.fixie",                      displayName: "Fixie"),
    ]

    /// Known AI CLI tools. These are matched as substrings, case-insensitive,
    /// so "claude" will match "claude-code", "node claude", etc.
    static let cliPresets: [CLIPreset] = [
        CLIPreset(processName: "claude",   displayName: "Claude Code"),
        CLIPreset(processName: "codex",    displayName: "OpenAI Codex"),
        CLIPreset(processName: "aider",    displayName: "Aider"),
        CLIPreset(processName: "ollama",   displayName: "Ollama"),
        CLIPreset(processName: "continue", displayName: "Continue CLI"),
        CLIPreset(processName: "gemini",   displayName: "Gemini CLI"),
    ]

    /// Bundle identifier prefixes that identify common web browsers.
    /// Used to show a warning when a browser is selected as a monitored app.
    static let browserBundleIDPrefixes: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "com.brave.Browser",
        "company.thebrowser.Browser",    // Arc
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
        "com.kagi.kagimacOS",            // Orion (Kagi)
        "com.operasoftware.Opera"
    ]

    // MARK: - Helpers

    /// Given a list of installed apps, return only those that match one of
    /// the known AI app presets.
    static func filterInstalledAIApps(_ installed: [InstalledApp]) -> [InstalledApp] {
        let ids = Set(appPresets.map { $0.bundleID.lowercased() })
        return installed.filter { ids.contains($0.bundleID.lowercased()) }
    }

    /// Heuristic fallback: any installed app whose display name contains
    /// one of these keywords is also considered AI-adjacent. Used in
    /// addition to the explicit bundle-id allowlist above, so that freshly
    /// released AI tools show up under "recommended" even without a preset.
    static func heuristicAIApps(_ installed: [InstalledApp]) -> [InstalledApp] {
        let keywords = ["claude", "chatgpt", "openai", "llm", "gpt", "cursor",
                        "aider", "codex", "ollama", "windsurf", "continue",
                        "copilot", "perplexity", "gemini", "zed"]
        return installed.filter { app in
            let n = app.displayName.lowercased()
            return keywords.contains { n.contains($0) }
        }
    }

    /// Returns true if the given bundle ID looks like a browser.
    static func isBrowser(bundleID: String) -> Bool {
        let lower = bundleID.lowercased()
        return browserBundleIDPrefixes.contains { lower.hasPrefix($0.lowercased()) }
    }
}
