import AppKit
import SwiftUI

/// Four-step onboarding shown the first time DontSleep launches.
/// Steps:
///   1. Welcome / value proposition (battery saving)
///   2. Choose which apps + CLIs to monitor
///   3. Choose suppression mode (caffeinate / pmset)
///   4. Launch at login on/off
struct OnboardingView: View {

    let prefs: Preferences
    let onFinish: () -> Void

    @State private var step: Int = 0
    @StateObject private var appModel: AppSelectionModel
    @State private var cliSelection: Set<String>
    @State private var suppressionMode: SuppressionMode
    @State private var launchAtLogin: Bool

    init(prefs: Preferences, onFinish: @escaping () -> Void) {
        self.prefs = prefs
        self.onFinish = onFinish

        // Pre-select all known AI CLI presets by default (mirrors the
        // legacy default list).
        let defaultCLI = Set(AIPresetStore.cliPresets.map { $0.processName })
        let storedCLI = Set(prefs.watchedCLINames)
        let initialCLI = storedCLI.isEmpty ? defaultCLI : storedCLI

        _appModel = StateObject(wrappedValue: AppSelectionModel(
            initialBundleIDs: prefs.watchedAppBundleIDs
        ))
        _cliSelection = State(initialValue: initialCLI)
        _suppressionMode = State(initialValue: prefs.suppressionMode)
        _launchAtLogin = State(initialValue: prefs.launchAtLogin)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 12)

            // Step content
            Group {
                switch step {
                case 0: welcome
                case 1: appSelectionStep
                case 2: modeStep
                default: launchStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation
            HStack {
                if step > 0 {
                    Button("戻る") { step -= 1 }
                }
                Spacer()
                Button(step == 3 ? "はじめる" : "次へ") {
                    if step == 3 {
                        finish()
                    } else {
                        step += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 540, height: 520)
        .onAppear {
            appModel.load()
        }
    }

    // MARK: - Step 1: Welcome

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.green)
            Text("DontSleepへようこそ")
                .font(.title)
            Text("あなたがAIを使っている間だけ、Macを起きたままにします。\n常時ONじゃないから、バッテリーが無駄になりません。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Spacer()
        }
    }

    // MARK: - Step 2: Apps & CLIs

    private var appSelectionStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("どのアプリを使っているときに抑止しますか？")
                .font(.headline)
            Text("ここで選んだアプリ／CLIが動いている間だけ、スリープを止めます。")
                .font(.caption)
                .foregroundColor(.secondary)

            // Inline app picker (no scroll-in-scroll surprises)
            AppSelectionView(model: appModel)
                .frame(minHeight: 240)

            Divider().padding(.vertical, 4)

            Text("AI CLI ツール")
                .font(.headline)

            let columns = [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(AIPresetStore.cliPresets, id: \.self) { preset in
                    Toggle(isOn: Binding(
                        get: { cliSelection.contains(preset.processName) },
                        set: { newValue in
                            if newValue { cliSelection.insert(preset.processName) }
                            else        { cliSelection.remove(preset.processName) }
                        }
                    )) {
                        Text("\(preset.displayName)  ").font(.body)
                        + Text(preset.processName).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Suppression mode

    private var modeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("抑止の強さを選んでください")
                .font(.headline)

            modeRow(
                title: "caffeinate（おすすめ）",
                detail: "権限不要。画面を開いているとき確実に抑止します。蓋を閉じている間、バッテリー駆動だとスリープすることがあります。",
                isSelected: suppressionMode == .caffeinate
            ) { suppressionMode = .caffeinate }

            modeRow(
                title: "pmset disablesleep（蓋閉じも抑止）",
                detail: "蓋を閉じても確実にスリープしません。最初に1回だけ管理者パスワードが必要です。設定後、メニューバーの「pmsetセットアップ…」から有効化してください。",
                isSelected: suppressionMode == .pmset
            ) { suppressionMode = .pmset }

            Spacer()
        }
    }

    private func modeRow(title: String, detail: String, isSelected: Bool, onPick: @escaping () -> Void) -> some View {
        Button(action: onPick) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 4: Launch at login

    private var launchStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "arrow.uturn.up.circle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.accentColor)
            Text("Macを起動したら自動でDontSleepも起動しますか？")
                .font(.headline)
                .multilineTextAlignment(.center)
            Toggle("ログイン時に起動", isOn: $launchAtLogin)
                .toggleStyle(.switch)
            Text("いつでも設定画面から変更できます。")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Persist & exit

    private func finish() {
        prefs.watchedAppBundleIDs = Array(appModel.selectedBundleIDs).sorted()
        prefs.watchedCLINames = Array(cliSelection).sorted()
        prefs.suppressionMode = suppressionMode
        prefs.launchAtLogin = launchAtLogin
        prefs.hasCompletedOnboarding = true
        LaunchAtLoginHelper.setEnabled(launchAtLogin)
        onFinish()
    }
}

/// Hosts the OnboardingView in a borderless modal-style window.
final class OnboardingWindowController: NSObject {
    private var window: NSWindow?
    private let prefs: Preferences
    private let onFinish: () -> Void

    init(prefs: Preferences, onFinish: @escaping () -> Void) {
        self.prefs = prefs
        self.onFinish = onFinish
    }

    func show() {
        if let w = window {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }

        let view = OnboardingView(prefs: prefs) { [weak self] in
            self?.close()
            self?.onFinish()
        }
        let host = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: host)
        w.title = "DontSleep セットアップ"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()

        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.close()
        window = nil
    }
}
