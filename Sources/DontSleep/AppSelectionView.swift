import AppKit
import SwiftUI

/// SwiftUI view that lets the user pick which installed apps to monitor.
/// Three logical sections:
///   - Recommended AI apps  (installed + matched against AIPresetStore)
///   - Selected apps        (chips for currently-selected bundle IDs)
///   - Other apps           (full alphabetical list with search)
///
/// The view is driven by a lightweight view-model so it can be embedded
/// both in the Preferences window and in the Onboarding flow.
struct AppSelectionView: View {

    @ObservedObject var model: AppSelectionModel

    @State private var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            batterySaverBanner

            // --- Recommended AI apps ---
            if !model.recommendedApps.isEmpty {
                sectionHeader("おすすめAIアプリ",
                              caption: "インストール済みのAI関連アプリを検出しました")

                VStack(spacing: 4) {
                    ForEach(model.recommendedApps) { app in
                        AppRow(
                            app: app,
                            isSelected: model.isSelected(app),
                            showWarning: AIPresetStore.isBrowser(bundleID: app.bundleID),
                            onToggle: { model.toggle(app) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            // --- Selected apps chip strip ---
            sectionHeader("選択中のアプリ",
                          caption: model.selectedApps.isEmpty
                            ? "上か下のリストから選んでください"
                            : "監視対象 \(model.selectedApps.count) 件")

            if model.selectedApps.isEmpty {
                Text("（未選択）")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.selectedApps) { app in
                            SelectedChip(app: app, onRemove: { model.toggle(app) })
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
            }

            // --- Other apps ---
            sectionHeader("その他のアプリを追加",
                          caption: "ブラウザを選ぶとバッテリー消費が増える点に注意")

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("アプリ名で検索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(filteredOtherApps) { app in
                        AppRow(
                            app: app,
                            isSelected: model.isSelected(app),
                            showWarning: AIPresetStore.isBrowser(bundleID: app.bundleID),
                            onToggle: { model.requestToggle(app) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(minHeight: 180)
        }
        .alert(item: $model.pendingBrowser) { app in
            Alert(
                title: Text("ブラウザを監視対象に追加しますか？"),
                message: Text("""
                ブラウザを監視すると、ブラウザを開いているだけでスリープ抑止が続き、バッテリーが余分に消費されます。

                「\(app.displayName)」を追加しますか？
                """),
                primaryButton: .destructive(Text("それでも追加")) {
                    model.toggle(app)
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }

    // MARK: - Pieces

    private var batterySaverBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "battery.100.bolt")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("バッテリー節約モード")
                    .font(.subheadline.weight(.semibold))
                Text("ここで選んだアプリが動いている間だけスリープを止めます。常時ONじゃないのでバッテリーを無駄にしません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.green.opacity(0.08))
        )
    }

    private func sectionHeader(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.headline)
            Text(caption).font(.caption).foregroundColor(.secondary)
        }
        .padding(.top, 6)
    }

    private var filteredOtherApps: [InstalledApp] {
        let recSet = Set(model.recommendedApps.map { $0.id })
        let others = model.allApps.filter { !recSet.contains($0.id) }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return others }
        return others.filter { $0.displayName.lowercased().contains(query) }
    }
}

// MARK: - Row

private struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let showWarning: Bool
    let onToggle: () -> Void

    @State private var icon: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName).font(.body)
                Text(app.bundleID)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if showWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .help("ブラウザ: 常時抑止になりやすくバッテリーを消費します")
            }

            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let i = app.loadIcon()
                DispatchQueue.main.async { icon = i }
            }
        }
    }
}

private struct SelectedChip: View {
    let app: InstalledApp
    let onRemove: () -> Void

    @State private var icon: NSImage?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(app.displayName)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            Capsule().fill(Color.secondary.opacity(0.12))
        )
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let i = app.loadIcon()
                DispatchQueue.main.async { icon = i }
            }
        }
    }
}

// MARK: - Model

/// Drives the AppSelectionView. Emits changes via ObservableObject.
final class AppSelectionModel: ObservableObject {
    @Published var allApps: [InstalledApp] = []
    @Published var recommendedApps: [InstalledApp] = []
    @Published var selectedBundleIDs: Set<String>
    @Published var pendingBrowser: InstalledApp?

    private let scanner = InstalledAppScanner()

    init(initialBundleIDs: [String]) {
        self.selectedBundleIDs = Set(initialBundleIDs)
    }

    var selectedApps: [InstalledApp] {
        allApps.filter { selectedBundleIDs.contains($0.bundleID) }
    }

    func isSelected(_ app: InstalledApp) -> Bool {
        selectedBundleIDs.contains(app.bundleID)
    }

    /// Request a toggle but interpose a browser-warning alert when the
    /// user is adding (not removing) a browser.
    func requestToggle(_ app: InstalledApp) {
        if !isSelected(app) && AIPresetStore.isBrowser(bundleID: app.bundleID) {
            pendingBrowser = app
        } else {
            toggle(app)
        }
    }

    func toggle(_ app: InstalledApp) {
        if selectedBundleIDs.contains(app.bundleID) {
            selectedBundleIDs.remove(app.bundleID)
        } else {
            selectedBundleIDs.insert(app.bundleID)
        }
    }

    /// Kick off a scan and populate the published arrays.
    func load() {
        scanner.scan { [weak self] apps in
            guard let self else { return }
            self.allApps = apps
            // Recommended = explicit preset hits ∪ heuristic name-match hits
            let explicit = AIPresetStore.filterInstalledAIApps(apps)
            let heuristic = AIPresetStore.heuristicAIApps(apps)
            var seen: Set<String> = []
            var recs: [InstalledApp] = []
            for a in explicit + heuristic {
                if seen.insert(a.bundleID).inserted { recs.append(a) }
            }
            self.recommendedApps = recs
        }
    }
}

// Hook `Alert(item:)` up to InstalledApp by adding Identifiable conformance
// in a file-local extension. (`InstalledApp` already is Identifiable via its
// `id` property.)
extension InstalledApp {
    // nothing extra needed; left here to make the dependency explicit.
}
