import AppKit
import SwiftUI

/// Floating ad banner shown in the bottom-right corner of the main screen
/// whenever sleep suppression is active.
///
/// Responsibilities:
/// 1. Own a single borderless `.floating` NSWindow positioned at the
///    bottom-right of the visible screen frame.
/// 2. Hold a current `AdCreative` (an `@ObservedObject` model that
///    `AdBannerView` renders).
/// 3. Fetch creatives from an `AdProvider` and rotate them on a timer.
/// 4. Fire the `impressionURL` exactly once per display of a creative.
/// 5. Respect a per-suppression-cycle dismissal: when the user clicks X,
///    hide the banner until the next ON→OFF→ON transition.
final class AdWindowController {

    // MARK: - Tunables

    private let windowSize = NSSize(width: 320, height: 100)
    private let edgePadding: CGFloat = 20
    private let rotationInterval: TimeInterval = 60

    // MARK: - State

    private var provider: AdProvider
    private var window: NSWindow?
    private let model = AdBannerModel()
    private var rotationTimer: Timer?
    private var dismissedThisCycle = false
    private var impressionsFired = Set<String>()

    private let pingSession: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        return URLSession(configuration: cfg)
    }()

    init(provider: AdProvider = NullAdProvider()) {
        self.provider = provider
    }

    /// Swap the active provider at runtime (e.g. when the user fills in
    /// an EthicalAds publisher id in Preferences).
    func setProvider(_ new: AdProvider) {
        self.provider = new
        // Force an immediate refresh if the window is visible.
        if window?.isVisible == true {
            refreshCreative()
        }
    }

    // MARK: - Public lifecycle

    func show() {
        guard !dismissedThisCycle else { return }

        if window == nil {
            window = makeWindow()
        }
        positionWindow()
        window?.orderFrontRegardless()

        refreshCreative()
        startRotation()
    }

    func hide() {
        stopRotation()
        window?.orderOut(nil)
        dismissedThisCycle = false
    }

    // MARK: - Rotation

    private func startRotation() {
        stopRotation()
        let t = Timer(timeInterval: rotationInterval, repeats: true) { [weak self] _ in
            self?.refreshCreative()
        }
        RunLoop.main.add(t, forMode: .common)
        rotationTimer = t
    }

    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    private func refreshCreative() {
        provider.nextCreative { [weak self] creative in
            guard let self = self else { return }
            guard let creative = creative else {
                // No ad available: hide the window to avoid showing a stale one.
                self.window?.orderOut(nil)
                return
            }
            self.model.current = creative
            self.fireImpressionIfNeeded(for: creative)

            // If we had hidden the window due to a previous nil,
            // bring it back (unless the user dismissed for this cycle).
            if !self.dismissedThisCycle, self.window?.isVisible == false {
                self.positionWindow()
                self.window?.orderFrontRegardless()
            }
        }
    }

    // MARK: - Impressions

    private func fireImpressionIfNeeded(for creative: AdCreative) {
        guard !impressionsFired.contains(creative.id),
              let url = creative.impressionURL else { return }
        impressionsFired.insert(creative.id)
        var req = URLRequest(url: url)
        req.setValue("DontSleep/0.1", forHTTPHeaderField: "User-Agent")
        pingSession.dataTask(with: req).resume()
    }

    // MARK: - User dismissal (close button)

    fileprivate func userDismissed() {
        dismissedThisCycle = true
        stopRotation()
        window?.orderOut(nil)
    }

    // MARK: - Window construction

    private func makeWindow() -> NSWindow {
        let rect = NSRect(origin: .zero, size: windowSize)

        let w = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.ignoresMouseEvents = false
        w.isMovableByWindowBackground = true

        let view = AdBannerView(
            model: model,
            onClose: { [weak self] in self?.userDismissed() }
        )
        w.contentView = NSHostingView(rootView: view)

        return w
    }

    private func positionWindow() {
        guard let window = window,
              let screen = NSScreen.main else { return }

        let visible = screen.visibleFrame
        let x = visible.maxX - windowSize.width - edgePadding
        let y = visible.minY + edgePadding
        window.setFrame(
            NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height),
            display: true
        )
    }
}

/// Simple observable model shared by the AdWindowController and
/// AdBannerView so the SwiftUI view re-renders when the creative rotates.
final class AdBannerModel: ObservableObject {
    @Published var current: AdCreative? = nil
}
