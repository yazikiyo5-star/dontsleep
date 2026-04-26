import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var monitor: ProcessMonitor!
    private var suppressor: SleepSuppressor!
    private var prefs: Preferences!
    private var prefsWindow: NSWindow?
    private var onboardingController: OnboardingWindowController?
    private let appScanner = InstalledAppScanner()
    private let adWindow = AdWindowController()

    /// Build an ad provider from current preferences. Falls back to the
    /// house provider if EthicalAds is selected but the publisher id is
    /// still empty (pre-approval state).
    private func makeAdProvider() -> AdProvider {
        switch prefs.adProviderKind {
        case .ethicalAds:
            let pub = prefs.ethicalAdsPublisher
            if !pub.isEmpty {
                return EthicalAdsProvider(publisherId: pub)
            }
            return HouseAdProvider(feedURL: prefs.houseAdsFeedURL)
        case .house:
            return HouseAdProvider(feedURL: prefs.houseAdsFeedURL)
        }
    }

    // Tracks whether suppression is currently active
    private var isSuppressing = false {
        didSet {
            updateMenuBarIcon()
            syncAdWindow()
        }
    }

    // Manual override: if true, always suppress regardless of process state
    private var manualOverride = false

    // Cached executable names from selected GUI apps; combined with
    // watchedCLINames before being handed to ProcessMonitor.
    private var resolvedAppExecutables: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        prefs = Preferences()
        suppressor = SleepSuppressor()
        monitor = ProcessMonitor(
            watchedProcessNames: combinedWatchList(appExecutables: []),
            pollInterval: 3.0
        )

        setupMenuBar()
        adWindow.setProvider(makeAdProvider())

        monitor.onStateChange = { [weak self] anyRunning in
            self?.handleProcessStateChange(anyRunning: anyRunning)
        }
        monitor.start()

        // Resolve selected GUI apps → executable names, then push to monitor.
        refreshWatchedAppsAsync()

        // First-launch onboarding (after the menu bar is up so users can
        // still see a status item if they dismiss the window).
        if !prefs.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up: always turn suppression off when quitting
        suppressor.stop(mode: prefs.suppressionMode)
        adWindow.hide()
    }

    /// Show / hide the bottom-right ad banner in sync with `isSuppressing`,
    /// gated by the user preference `adsEnabled`.
    private func syncAdWindow() {
        guard prefs != nil else { return }
        if prefs.adsEnabled && isSuppressing {
            adWindow.show()
        } else {
            adWindow.hide()
        }
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()
        buildMenu()
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        // ☕ when suppressing, 💤 when idle. Plain text fallback works on
        // every macOS theme without bundled assets.
        button.title = isSuppressing ? "☕" : "💤"
        button.toolTip = isSuppressing
            ? "DontSleep: スリープ抑止中"
            : "DontSleep: 待機中"
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Status row
        let statusRow = NSMenuItem(
            title: statusRowText(),
            action: nil, keyEquivalent: ""
        )
        statusRow.isEnabled = false
        menu.addItem(statusRow)

        menu.addItem(.separator())

        // Manual override toggle
        let overrideItem = NSMenuItem(
            title: manualOverride ? "✓ 手動で常時ON" : "手動で常時ON",
            action: #selector(toggleManualOverride),
            keyEquivalent: ""
        )
        overrideItem.target = self
        menu.addItem(overrideItem)

        menu.addItem(.separator())

        // Mode selection
        let modeHeader = NSMenuItem(title: "抑止モード", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)

        let caffeinateItem = NSMenuItem(
            title: "\(prefs.suppressionMode == .caffeinate ? "● " : "   ")caffeinate (権限不要・簡易)",
            action: #selector(setModeCaffeinate),
            keyEquivalent: ""
        )
        caffeinateItem.target = self
        menu.addItem(caffeinateItem)

        let pmsetItem = NSMenuItem(
            title: "\(prefs.suppressionMode == .pmset ? "● " : "   ")pmset disablesleep (蓋閉じ対応)",
            action: #selector(setModePmset),
            keyEquivalent: ""
        )
        pmsetItem.target = self
        menu.addItem(pmsetItem)

        menu.addItem(.separator())

        // Watched apps & CLIs
        let watchedHeader = NSMenuItem(title: "監視中", action: nil, keyEquivalent: "")
        watchedHeader.isEnabled = false
        menu.addItem(watchedHeader)

        for name in combinedWatchList(appExecutables: resolvedAppExecutables) {
            let running = monitor.isRunning(name)
            let item = NSMenuItem(
                title: "   \(running ? "▶︎" : "・") \(name)",
                action: nil, keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "設定…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        let installItem = NSMenuItem(
            title: "pmset を無パスワードで使えるようにする…",
            action: #selector(installSudoers),
            keyEquivalent: ""
        )
        installItem.target = self
        menu.addItem(installItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // Status line: which process triggered suppression, if any.
    private func statusRowText() -> String {
        if manualOverride {
            return "● 手動で抑止中"
        }
        if isSuppressing {
            let active = combinedWatchList(appExecutables: resolvedAppExecutables)
                .filter { monitor.isRunning($0) }
            if let first = active.first {
                let extra = active.count > 1 ? " ほか\(active.count - 1)件" : ""
                return "● 抑止中 — \(first) を検知\(extra)"
            }
            return "● 抑止中"
        }
        return "○ 待機中"
    }

    // Rebuild menu whenever anything changes (simple approach)
    private func refreshMenu() {
        buildMenu()
    }

    // MARK: - Actions

    @objc private func toggleManualOverride() {
        manualOverride.toggle()
        reevaluate()
        refreshMenu()
    }

    @objc private func setModeCaffeinate() {
        switchMode(to: .caffeinate)
    }

    @objc private func setModePmset() {
        if !SudoersInstaller.isInstalled() {
            let alert = NSAlert()
            alert.messageText = "pmset モードには管理者設定が必要です"
            alert.informativeText = """
            このモードは蓋を閉じてもスリープしないようにしますが、\
            そのために sudoers 設定を1度だけ行う必要があります。\n\n\
            メニューの「pmset を無パスワードで使えるようにする…」\
            から先にセットアップしてください。
            """
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        switchMode(to: .pmset)
    }

    private func switchMode(to newMode: SuppressionMode) {
        // Stop under current mode, swap, restart if needed
        let wasSuppressing = isSuppressing
        if wasSuppressing {
            suppressor.stop(mode: prefs.suppressionMode)
        }
        prefs.suppressionMode = newMode
        if wasSuppressing {
            suppressor.start(mode: newMode)
        }
        refreshMenu()
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let content = PreferencesView(
                prefs: prefs,
                onSave: { [weak self] in self?.handlePrefsSaved() }
            )
            let hosting = NSHostingController(rootView: content)
            let window = NSWindow(contentViewController: hosting)
            window.title = "DontSleep 設定"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 580, height: 700))
            window.center()
            prefsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
    }

    private func handlePrefsSaved() {
        // Re-resolve apps → executable names and re-sync ad provider.
        refreshWatchedAppsAsync()
        adWindow.setProvider(makeAdProvider())
        syncAdWindow()
        refreshMenu()
    }

    @objc private func installSudoers() {
        let ok = SudoersInstaller.install()
        let alert = NSAlert()
        if ok {
            alert.messageText = "セットアップ完了"
            alert.informativeText = "pmset モードが使えるようになりました。"
        } else {
            alert.messageText = "セットアップに失敗しました"
            alert.informativeText = "管理者パスワードが必要です。再度お試しください。"
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let controller = OnboardingWindowController(prefs: prefs) { [weak self] in
            // Onboarding finished — refresh everything that depends on prefs.
            self?.handlePrefsSaved()
        }
        onboardingController = controller
        controller.show()
    }

    // MARK: - Watch list resolution (apps → process names)

    /// Combine selected app executables with CLI process names.
    private func combinedWatchList(appExecutables: [String]) -> [String] {
        var names = prefs?.watchedCLINames ?? []
        names.append(contentsOf: appExecutables)
        // Deduplicate while preserving order.
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    /// Resolve each watched bundle ID into a CFBundleExecutable on a
    /// background queue, then push the combined list into ProcessMonitor.
    private func refreshWatchedAppsAsync() {
        let bundleIDs = prefs.watchedAppBundleIDs
        guard !bundleIDs.isEmpty else {
            self.resolvedAppExecutables = []
            self.monitor.updateWatchedProcessNames(combinedWatchList(appExecutables: []))
            self.refreshMenu()
            return
        }
        appScanner.scan { [weak self] apps in
            guard let self else { return }
            let map = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0.executableName) })
            let execs = bundleIDs.compactMap { map[$0] }
            self.resolvedAppExecutables = execs
            self.monitor.updateWatchedProcessNames(self.combinedWatchList(appExecutables: execs))
            self.refreshMenu()
        }
    }

    // MARK: - Core state machine

    private func handleProcessStateChange(anyRunning: Bool) {
        reevaluate(anyRunning: anyRunning)
        refreshMenu()
    }

    /// Re-evaluates whether suppression should be active, given current state.
    private func reevaluate(anyRunning: Bool? = nil) {
        let running = anyRunning ?? monitor.anyWatchedProcessRunning()
        let shouldSuppress = manualOverride || running

        if shouldSuppress && !isSuppressing {
            suppressor.start(mode: prefs.suppressionMode)
            isSuppressing = true
        } else if !shouldSuppress && isSuppressing {
            suppressor.stop(mode: prefs.suppressionMode)
            isSuppressing = false
        }
    }
}
