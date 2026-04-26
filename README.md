# DontSleep

AIエージェント（Claude Code など）を実行している間だけ、Mac が蓋を閉じてもスリープしないようにするメニューバー常駐アプリのプロトタイプです。

---

## できること

- メニューバーに常駐（☕ = 抑止中 / 💤 = 待機中）
- 監視対象プロセス（`claude`, `codex`, `aider`, `ollama` など）が動いている間だけ自動でスリープ抑止
- 抑止モードを切替
  - **caffeinate**（推奨: 権限不要、蓋閉じは電源接続時のみ確実）
  - **pmset disablesleep**（完全に蓋閉じスリープを無効化、sudoers 設定が1度だけ必要）
- **手動で常時ON**トグル
- 設定画面で監視プロセス名を GUI 追加／削除

## 必要環境

- macOS 13 (Ventura) 以降
- Xcode Command Line Tools（`xcode-select --install`）または Xcode 本体

## ビルドと起動

### A) .app バンドルとして起動（推奨・通常用途）

```bash
cd DontSleep
./scripts/build_app.sh --install
open ~/Applications/DontSleep.app
```

これで `~/Applications/DontSleep.app` が生成され、Launchpad・Spotlight・Applications フォルダから起動できるようになります。
起動するとメニューバー右上に ☕ / 💤 アイコンが出ます。

### B) 素のバイナリを直接起動（開発時の素早い検証）

```bash
cd DontSleep
swift build -c release
.build/release/DontSleep
```

もしくは同梱スクリプト `./scripts/run.sh`。

## pmset モード（蓋閉じ完全対応）を有効にする

pmset モードは「蓋を閉じても絶対に寝ない」動作ですが、`sudo` が必要な操作なので、**最初に1度だけ**管理者設定が必要です。

1. メニューバーの 💤 をクリック → **「pmset を無パスワードで使えるようにする…」** を選択
2. 管理者パスワードを入力（この1回だけ）
3. `/etc/sudoers.d/dontsleep` に以下のような行が書かれます:

   ```
   ユーザー名 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
   ```

   これで以降、アプリは**パスワード入力なし**に `pmset disablesleep` を切替られます。
4. メニューバーから **抑止モード → pmset disablesleep** を選択

**解除したいとき**:

```bash
./scripts/uninstall_sudoers.sh
```

## 動作の流れ

```
3秒ごとにプロセスリストをチェック (ps -Axo comm=)
    │
    ├─ 監視対象プロセスが見つかった → 抑止モード開始
    │       ├─ caffeinate: `caffeinate -disu` をバックグラウンド起動
    │       └─ pmset:      `sudo -n pmset -a disablesleep 1`
    │
    └─ 見つからない → 抑止解除（caffeinate プロセス終了 or disablesleep 0）
```

プロセス名マッチは**部分一致・大文字小文字無視**なので、`claude` と登録しておけば `claude-code` や `node claude` でもヒットします。

## ファイル構成

```
DontSleep/
├── Package.swift
├── README.md
├── DISTRIBUTION.md             # Developer ID 配布の詳しい手順
├── Sources/DontSleep/
│   ├── main.swift              # エントリーポイント (.accessory で Dock 非表示, SIGTERM 対応)
│   ├── AppDelegate.swift       # メニューバー UI ＋ 状態機械
│   ├── ProcessMonitor.swift    # ps を 3 秒おきに叩いて監視
│   ├── SleepSuppressor.swift   # caffeinate / pmset 実行ラッパー
│   ├── SudoersInstaller.swift  # osascript で admin 認証して sudoers 配置
│   ├── Preferences.swift       # UserDefaults
│   └── PreferencesView.swift   # SwiftUI 設定画面
├── scripts/
│   ├── build_app.sh            # .app バンドル生成（--install で ~/Applications に設置）
│   ├── run.sh                  # 素のバイナリを直接起動
│   └── uninstall_sudoers.sh    # /etc/sudoers.d/dontsleep を削除
└── dist/                       # build_app.sh が DontSleep.app / DontSleep.dmg を置く場所
```

---

## 今後の拡張

### 1. WidgetKit によるウィジェット対応

ご質問の「Mac でウィジェット出せる？」への回答: **はい、WidgetKit で作れます。**

- **通知センターウィジェット**（macOS 11+）: 画面右上から開くウィジェット領域
- **デスクトップウィジェット**（macOS 14 Sonoma+）: デスクトップに貼り付け可能
- **コントロールセンターモジュール**（macOS 15 Sequoia+）: トグル型モジュール

プロトタイプは SPM 構成ですが、ウィジェットを足すには **Xcode プロジェクトに移行**して Widget Extension ターゲットを追加する必要があります（WidgetKit は App Extension の仕組みに依存しているため）。

移行後の構成イメージ:

```
DontSleep.xcodeproj
├── DontSleep (main target)           … 今のプロトタイプ
├── DontSleepWidget (widget extension) … WidgetKit
└── Shared (App Group)                … 現在状態を共有
```

状態共有は **App Group + UserDefaults(suiteName:)** を使い、本体アプリが `isSuppressing` / `runningProcesses` を書き込み、ウィジェットから読むのが定石です。
コントロールセンターのトグルからオン／オフしたい場合は `AppIntent` + `ControlWidget` を定義します。

### 2. ログイン時自動起動

`SMAppService.mainApp.register()`（macOS 13+ API）で実装可能。設定画面にトグルを追加するだけ。

### 3. もっと賢い検知

- CPU 使用率が N% 以上なら抑止（アイドル中のプロセスは無視）
- ネットワーク I/O がある間だけ抑止
- 特定アプリがフォアグラウンドの間だけ抑止（`NSWorkspace.shared.frontmostApplication`）

### 4. 配布

詳しい手順は [DISTRIBUTION.md](./DISTRIBUTION.md) を参照してください。要約:

- **App Store は不可**: `caffeinate` 子プロセス / `pmset` / `sudoers` 書き込みが全部サンドボックス違反（Amphetamine 等も同じ理由で蓋閉じ抑止はApp Store非対応）
- **Developer ID + Notarization** で App Store 外配布が唯一の実用ルート
  1. Apple Developer Program 加入（$99/年）
  2. `codesign --options runtime --entitlements DontSleep.entitlements ...`
  3. `xcrun notarytool submit --wait`
  4. `xcrun stapler staple`
  5. DMG を GitHub Releases 等で配布

## トラブルシューティング

**「pmset モードに切り替わらない」**
→ `/etc/sudoers.d/dontsleep` が無いか、無効な形式です。メニューバーからセットアップをやり直してください。

**「caffeinate モードなのに蓋を閉じると寝る」**
→ これは `caffeinate` の仕様です。バッテリー駆動時に蓋を閉じると、caffeinate の system-sleep 抑止は効きません。pmset モードを使ってください。

**「起動したのにメニューバーに何も出ない」**
→ 絵文字 ☕ / 💤 がダーク／ライトの配色によっては見づらいことがあります。`updateMenuBarIcon()` を SF Symbol（例: `mug.fill`）に差し替えても OK です。
