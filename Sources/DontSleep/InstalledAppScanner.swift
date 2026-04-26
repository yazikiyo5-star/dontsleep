import AppKit
import Foundation

/// Represents a single installed application discovered by the scanner.
struct InstalledApp: Identifiable, Equatable, Hashable {
    /// Use the bundle identifier as the stable id.
    var id: String { bundleID }

    let bundleID: String
    let displayName: String
    let executableName: String
    let bundleURL: URL

    /// Resolved on demand to avoid holding lots of NSImage instances in
    /// memory. The result is a 64×64 NSImage suitable for SwiftUI display.
    func loadIcon() -> NSImage {
        let img = NSWorkspace.shared.icon(forFile: bundleURL.path)
        img.size = NSSize(width: 64, height: 64)
        return img
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}

/// Enumerates `.app` bundles under the standard macOS application
/// directories so the user can pick which ones to monitor.
///
/// This runs off the main thread. Results are cached for the lifetime of
/// the scanner instance; call `rescan()` to refresh.
final class InstalledAppScanner {

    /// Directories we enumerate. First-party + user + system.
    private static let searchRoots: [URL] = {
        let fm = FileManager.default
        var roots: [URL] = []
        roots.append(URL(fileURLWithPath: "/Applications", isDirectory: true))
        if let home = fm.urls(for: .applicationDirectory, in: .userDomainMask).first {
            roots.append(home)
        }
        roots.append(URL(fileURLWithPath: "/System/Applications", isDirectory: true))
        return roots
    }()

    private let queue = DispatchQueue(
        label: "dontsleep.appscanner",
        qos: .userInitiated
    )

    private var cache: [InstalledApp] = []
    private let cacheLock = NSLock()

    /// Kick off a scan. Completion is invoked on the main queue.
    func scan(completion: @escaping ([InstalledApp]) -> Void) {
        queue.async { [weak self] in
            let results = Self.performScan()
            self?.cacheLock.lock()
            self?.cache = results
            self?.cacheLock.unlock()
            DispatchQueue.main.async { completion(results) }
        }
    }

    /// Returns the last scan result, or an empty array if no scan has run.
    func cachedApps() -> [InstalledApp] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache
    }

    // MARK: - Implementation

    private static func performScan() -> [InstalledApp] {
        let fm = FileManager.default
        var seen: Set<String> = []
        var out: [InstalledApp] = []

        for root in searchRoots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: nil
            ) else { continue }

            for case let url as URL in enumerator {
                // Only surface top-level .app bundles, but allow one level
                // of nesting (e.g. /Applications/Utilities/Terminal.app).
                guard url.pathExtension == "app" else { continue }

                // Avoid descending into the .app contents.
                enumerator.skipDescendants()

                guard let app = makeInstalledApp(from: url) else { continue }
                if seen.insert(app.bundleID).inserted {
                    out.append(app)
                }
            }
        }

        // Stable alphabetical order by display name.
        out.sort { a, b in
            a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        return out
    }

    private static func makeInstalledApp(from url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }
        guard let bundleID = bundle.bundleIdentifier else { return nil }

        let displayName: String = {
            if let s = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               !s.isEmpty {
                return s
            }
            if let s = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
               !s.isEmpty {
                return s
            }
            return url.deletingPathExtension().lastPathComponent
        }()

        let executableName: String = {
            if let s = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
               !s.isEmpty {
                return s
            }
            // Fallback: derive from the binary at Contents/MacOS/
            return url.deletingPathExtension().lastPathComponent
        }()

        return InstalledApp(
            bundleID: bundleID,
            displayName: displayName,
            executableName: executableName,
            bundleURL: url
        )
    }
}
