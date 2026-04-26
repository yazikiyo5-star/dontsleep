import SwiftUI

/// Settings screen. v1.0 layout:
///   - App selection (recommended AI apps + browse + selected chips)
///   - AI CLI tool list
///   - Suppression mode
///   - Launch at login
///   - Ads section (legacy)
struct PreferencesView: View {

    let prefs: Preferences
    let onSave: () -> Void

    @StateObject private var appModel: AppSelectionModel
    @State private var cliNames: [String] = []
    @State private var newCLI: String = ""
    @State private var mode: SuppressionMode = .caffeinate
    @State private var launchAtLogin: Bool = true
    @State private var adsEnabled: Bool = true
    @State private var providerKind: AdProviderKind = .house
    @State private var houseFeedURL: String = ""
    @State private var ethicalPublisher: String = ""

    init(prefs: Preferences, onSave: @escaping () -> Void) {
        self.prefs = prefs
        self.onSave = onSave
        _appModel = StateObject(wrappedValue: AppSelectionModel(
            initialBundleIDs: prefs.watchedAppBundleIDs
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                AppSelectionView(model: appModel)
                    .frame(minHeight: 320)

                Divider()

                // --- CLI tool list ---
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI CLI ツール")
                        .font(.headline)
                    Text("ターミナルで動く AI ツールはプロセス名で部分一致検知します（大文字小文字無視）")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(cliNames, id: \.self) { name in
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundColor(.secondary)
                            Text(name)
                            Spacer()
                            Button(action: { removeCLI(name) }) {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    HStack {
                        TextField("プロセス名 (例: claude)", text: $newCLI)
                            .textFieldStyle(.roundedBorder)
                        Button("追加") { addCLI() }
                            .disabled(newCLI.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Divider()

                // --- Suppression mode ---
                VStack(alignment: .leading, spacing: 6) {
                    Text("抑止モード").font(.headline)
                    Picker("", selection: $mode) {
                        Text("caffeinate（権限不要）").tag(SuppressionMode.caffeinate)
                        Text("pmset disablesleep（蓋閉じ対応）").tag(SuppressionMode.pmset)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                // --- Launch at login ---
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Macを起動したら自動でDontSleepも起動する", isOn: $launchAtLogin)
                    Text("反映には DontSleep が /Applications か ~/Applications にインストールされている必要があります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // --- Ads (legacy) ---
                VStack(alignment: .leading, spacing: 6) {
                    Text("広告表示").font(.headline)
                    Toggle("抑止中は画面右下にスポンサー枠を表示する", isOn: $adsEnabled)
                    Text("オフにすると、抑止が有効な間もバナーが出ません。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if adsEnabled {
                        Picker("広告ソース", selection: $providerKind) {
                            Text("自前JSON（House Ads）").tag(AdProviderKind.house)
                            Text("EthicalAds").tag(AdProviderKind.ethicalAds)
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 2)

                        if providerKind == .house {
                            TextField("JSON URL（空欄なら組み込みのみ）", text: $houseFeedURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        } else {
                            TextField("EthicalAds publisher id", text: $ethicalPublisher)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                            Text("承認されるまで空欄のままにしておくと、自動的に自前JSONにフォールバックします。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                Text("DontSleepはプロセス一覧をローカルで読むだけで、外部にデータを送信しません。")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack {
                    Spacer()
                    Button("閉じる") { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 580, height: 700)
        .onAppear {
            cliNames = prefs.watchedCLINames
            mode = prefs.suppressionMode
            launchAtLogin = prefs.launchAtLogin
            adsEnabled = prefs.adsEnabled
            providerKind = prefs.adProviderKind
            houseFeedURL = prefs.houseAdsFeedURLString
            ethicalPublisher = prefs.ethicalAdsPublisher
            appModel.load()
        }
    }

    // MARK: - CLI helpers

    private func addCLI() {
        let trimmed = newCLI.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !cliNames.contains(trimmed) {
            cliNames.append(trimmed)
        }
        newCLI = ""
    }

    private func removeCLI(_ name: String) {
        cliNames.removeAll { $0 == name }
    }

    private func save() {
        prefs.watchedAppBundleIDs = Array(appModel.selectedBundleIDs).sorted()
        prefs.watchedCLINames = cliNames
        prefs.suppressionMode = mode
        prefs.launchAtLogin = launchAtLogin
        prefs.adsEnabled = adsEnabled
        prefs.adProviderKind = providerKind
        prefs.houseAdsFeedURLString = houseFeedURL.trimmingCharacters(in: .whitespaces)
        prefs.ethicalAdsPublisher = ethicalPublisher.trimmingCharacters(in: .whitespaces)
        LaunchAtLoginHelper.setEnabled(launchAtLogin)
        onSave()
        NSApp.keyWindow?.close()
    }
}
