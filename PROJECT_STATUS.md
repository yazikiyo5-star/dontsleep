# DontSleep プロジェクトステータス

最終更新: 2026-04-26

このドキュメントは DontSleep を **v0.1.0 として一般配布できる状態にまで仕上げた** 一連の作業ログ兼運用リファレンスです。後続バージョンを切るとき・新しい関係者が参加するとき・将来の自分が思い出すときの「これ読めば全部わかる」資料を目指します。

---

## 1. プロジェクト概要

**DontSleep** は macOS のメニューバーに常駐する小さなユーティリティで、AI エージェント (Claude Code, codex, aider, ollama 等) が動いている間だけ Mac をスリープさせない。エージェントの作業中に蓋を閉じても処理が止まらないようにすることが目的。

- 言語: Swift 5.9+, SwiftUI + AppKit
- ビルド: Swift Package Manager (executable target)
- 対象 OS: macOS 13 (Ventura) 以降
- 配布: Apple Developer ID 署名 + Notarization 済み DMG (App Store 外配布)
- 課金モデル: 無料、控えめなスポンサーバナーで運営費を補填 (オプトアウト可)

### ファイル構成

```
DontSleep/
├── Package.swift
├── README.md                      # ユーザー向け
├── PROJECT_STATUS.md              # 本ファイル
├── DISTRIBUTION.md                # Developer ID 配布の詳細手順
├── SIGNING_SETUP.md               # 初回の Apple Developer 設定手順
├── ETHICALADS.md                  # EthicalAds 申請ガイド
├── SPEC_v1.0.md                   # 機能仕様
├── DontSleep.entitlements         # Hardened Runtime entitlements
├── .gitignore                     # 秘密鍵類を確実に除外
├── .github/workflows/release.yml  # タグ push で自動署名・公証・upload する CI
├── Sources/DontSleep/             # Swift ソース 16 ファイル
├── docs/                          # GitHub Pages のソース (index.html / privacy.html)
├── ads/                           # 自前広告サーバ用フィードのサンプル
├── scripts/                       # ビルド・配布・補助スクリプト
└── dist/                          # ビルド成果物 (.gitignore で除外)
```

### 主要 Swift モジュール

- `main.swift` — エントリ。`.accessory` で Dock 非表示、SIGTERM 対応
- `AppDelegate.swift` — メニューバー UI、状態機械
- `ProcessMonitor.swift` — `ps -Axo comm=` を 3 秒間隔でポーリング、AIプロセス検知
- `SleepSuppressor.swift` — `caffeinate` / `pmset disablesleep` のラッパー
- `SudoersInstaller.swift` — 初回だけ `osascript` で admin 認証して `/etc/sudoers.d/dontsleep` を配置
- `Preferences.swift`, `PreferencesView.swift` — 設定 (UserDefaults + SwiftUI)
- `Ad*Provider.swift`, `AdBannerView.swift`, `AdWindowController.swift` — プラガブルな広告系
- `LaunchAtLoginHelper.swift` — `SMAppService.mainApp.register()` でログイン時自動起動
- `OnboardingView.swift`, `AppSelectionView.swift`, `InstalledAppScanner.swift` — 初回設定 UI

---

## 2. 配布パイプライン (署名・公証)

### 完成済み

`./scripts/release.sh` 一発で「ビルド → 署名 → DMG → 公証 → ステープル → 検証」まで自動。

```
$ ./scripts/release.sh
>>> build .app bundle
>>> auto-detected identity: Developer ID Application: iijima haruki (ZW29TWZK6Q)
>>> codesign
>>> verify signature
>>> build DMG
>>> submit to notarytool (profile: DontSleep)
>>> staple
>>> final Gatekeeper assessment
dist/DontSleep.app: accepted
source=Notarized Developer ID
```

成果物は `dist/DontSleep-0.1.0.dmg`。Gatekeeper が完全に認める状態 (`source=Notarized Developer ID`)、他人の Mac でもダウンロード→ダブルクリック→ドラッグだけで使える。

### `release.sh` の動作モード

環境変数で挙動を切替:

| 変数 | 効果 |
|---|---|
| (無設定) | キーチェーンの Developer ID Application を自動検出してフル署名・公証 |
| `ADHOC=1` | `codesign --sign -` で ad-hoc 署名のみ。証明書なしの環境でローカル動作確認用 |
| `SKIP_NOTARIZE=1` | 署名はするが公証スキップ。Apple サーバを叩かないので速い (Gatekeeper 通らない) |
| `SIGN_IDENTITY="..."` | identity を明示指定 |
| `NOTARY_PROFILE` | `notarytool` のキーチェーンプロファイル名 (デフォルト `DontSleep`) |
| `APP_VERSION` | DMG に焼くバージョン番号 (デフォルト `0.1.0`) |

### Hardened Runtime entitlements

`DontSleep.entitlements`:

```xml
<key>com.apple.security.cs.allow-jit</key><false/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
<key>com.apple.security.automation.apple-events</key><true/>
```

Swift ランタイムが必要とする最小限のみ。`automation.apple-events` は `osascript` で admin 認証する初回 sudoers 配置のために必要。

---

## 3. GitHub リリース手順 (手動)

```bash
cd "/Users/haru/Documents/Claude/Projects/dont sleep/DontSleep"

# 1. バージョンを上げる場合は scripts/build_app.sh の CFBundleShortVersionString を編集

# 2. クリーンリリース (約4分〜数十分: Apple の公証次第)
./scripts/release.sh

# 3. タグを切って GitHub Release を作る
git tag v0.2.0
git push origin v0.2.0
gh release create v0.2.0 dist/DontSleep-0.2.0.dmg \
  --title "DontSleep v0.2.0" \
  --notes-file dist/RELEASE_NOTES.md
```

---

## 4. GitHub Actions による自動リリース (準備完了)

タグを push するだけで CI が:
1. macos-14 ランナーで checkout
2. シークレットから .p12 を一時キーチェーンにインポート
3. `notarytool` 認証情報を保存
4. `release.sh` を実行 (フル署名・公証・ステープル・DMG)
5. 出来上がった DMG を Release にアップロード

### 有効化に必要な GitHub secrets

| 名前 | 内容 |
|---|---|
| `APPLE_DEVELOPER_ID_P12_BASE64` | `dist/DontSleep-keychain.p12` の base64 |
| `APPLE_DEVELOPER_ID_P12_PASSWORD` | .p12 のエクスポートパスワード |
| `APPLE_ID` | `haruqvp@icloud.com` |
| `APPLE_TEAM_ID` | `ZW29TWZK6Q` |
| `APPLE_APP_SPECIFIC_PASSWORD` | account.apple.com で発行した `xxxx-xxxx-xxxx-xxxx` |

### 一括設定スクリプト

```bash
APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx \
APPLE_DEVELOPER_ID_P12_PASSWORD=<the .p12 export password> \
./scripts/setup_github_secrets.sh
```

設定後は `git tag v0.2.0 && git push origin v0.2.0` だけで CI が走る。

### セキュリティに関する注意

- **`.p12` パスワードは現在 `dontsleep`** で固定 (このリポジトリに記載済)。本番運用に入る前に必ず別の値で再生成することを推奨:
  ```bash
  cd dist && rm DontSleep.p12 DontSleep-keychain.p12 && \
  openssl pkcs12 -export -legacy -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -inkey DontSleep.key \
    -in developerID_application.pem \
    -out DontSleep-keychain.p12 \
    -password "pass:<新しい強いパスワード>"
  ```
  以降 GitHub secrets / `setup_github_secrets.sh` の引数も新しいパスワードに更新。
- **App-Specific Password** は account.apple.com からいつでも revoke 可能。漏れたと思ったら revoke して再発行。
- **秘密鍵 (`dist/DontSleep.key`, `dist/*.p12`)** は `.gitignore` で除外済。コミット時は `git status` で必ず確認。

---

## 5. GitHub Pages

- ソース: `docs/index.html`, `docs/privacy.html`
- 公開 URL: https://yazikiyo5-star.github.io/dontsleep/
- 設定: Settings → Pages → Source: `Deploy from a branch`, Branch: `main` / `/docs`
- ダークモード: `prefers-color-scheme` で自動切替
- バナーのスクリーンショット: 現在は HTML/CSS の inline mockup (実機 PNG なし)。差し替えたい場合は `docs/img/banner.png` を配置して `docs/index.html` の `mock-wrap` 部分を `<img>` に戻す

### Privacy Policy

`docs/privacy.html` に以下を明記:
- DontSleep が収集する情報 = 何もない (本体)
- 広告系の挙動: ハウス広告サーバ JSON フィードと EthicalAds の挙動、各種ピン
- ユーザーが完全 OFF できることの保証

---

## 6. 運用情報リファレンス (秘密情報を含まない)

| 項目 | 値 |
|---|---|
| GitHub repo | https://github.com/yazikiyo5-star/dontsleep (public) |
| GitHub Pages | https://yazikiyo5-star.github.io/dontsleep/ |
| Apple Developer Apple ID | `haruqvp@icloud.com` |
| Apple Developer Team ID | `ZW29TWZK6Q` |
| 法的氏名 (証明書 CN) | `iijima haruki` |
| Bundle Identifier | `com.haru.dontsleep` |
| 証明書有効期限 | 2027-02-01 |
| 連絡先メール (notarization confirmation 等) | `h.iijima@aihub.tokyo` |
| `notarytool` キーチェーンプロファイル名 | `DontSleep` |

### macOS 上の重要な場所

| パス | 用途 |
|---|---|
| `~/Library/Keychains/login.keychain-db` | Developer ID 証明書と秘密鍵 (login keychain) |
| `~/Applications/DontSleep.app` | `build_app.sh --install` でインストールされる場所 |
| `/etc/sudoers.d/dontsleep` | pmset モード使用時の NOPASSWD 設定 (1度だけ admin 認証で配置) |
| `~/Library/Preferences/com.haru.dontsleep.plist` | UserDefaults |

---

## 7. 遭遇した問題と解決 (lessons learned)

### 7.1 macOS Keychain Access が `.p12` を読めない (`OSStatus -26276`)

**症状**: ダブルクリックでも、最新 PBES2+AES の .p12 でも、SHA1+3DES の .p12 でも `MAC verification failed` エラー。

**原因**: 推測だが、Keychain Access GUI は OpenSSL 3 が生成する PKCS#12 構造のうち特定の組合せを拒否することがある。CLI の `security import` は問題なく読める。

**解決**: GUI を諦めて CLI 経由でインポート:
```bash
security import dist/DontSleep-keychain.p12 \
  -k ~/Library/Keychains/login.keychain-db \
  -P "<.p12 password>" -A
```
`-A` で全アプリにキーアクセスを許可、以降 codesign 実行時にパスワード聞かれない。

### 7.2 公証処理が 4 時間かかった

**症状**: 通常 15 分以内で終わる notarization が `In Progress` のまま 4 時間継続。

**原因**: 新規 Apple Developer アカウントの初回 submission は不正検知レビューに回されることがある。土曜日だったので Apple のセキュリティチームの対応が翌営業日に持ち越されない範囲で長めに。

**解決**: 待つだけ。バックグラウンドで polling watcher を仕掛け、Accepted になり次第自動で staple + spctl 評価まで走らせた。

**今後**: 同じ証明書で 2 件目以降は通常通り 15 分以内に戻ると Apple ドキュメントが明記。

### 7.3 GitHub に workflow ファイルを push できない

**症状**: `git push` が `refusing to allow an OAuth App to create or update workflow ... without workflow scope` で reject。

**原因**: gh CLI のトークンに `workflow` スコープが付与されていない。`gh auth refresh -s workflow` で OAuth 再認可しても、ローカルの token が更新されない場合がある (デバイスフローのタイミング問題)。

**解決**: GitHub Web UI のファイル編集機能で直接 commit。CodeMirror エディタには `dispatchEvent(new ClipboardEvent('paste', {...}))` で programmatic に貼付できる。

**今後**: `gh auth refresh -s workflow` で更新できれば、それ以降は git push が普通に通る。

### 7.4 Apple ID と連絡先メールの混同

**症状**: `notarytool store-credentials` が HTTP 401 で失敗。

**原因**: 連絡先メール `h.iijima@aihub.tokyo` を Apple ID と勘違い。実際の Apple ID は `haruqvp@icloud.com`。

**解決**: 正しい Apple ID で再実行。

**今後**: Apple Developer の認証は必ず `haruqvp@icloud.com` を使う。本ドキュメントの 6 章を参照。

---

## 8. 次にやること (pending items)

### 短期 (外部承認待ち系)

- **EthicalAds の publisher 申請** — `ETHICALADS.md` の手順で https://www.ethicalads.io/publishers/ に申請。承認後 publisher ID を DontSleep の設定画面 → Provider: EthicalAds で有効化。
- **本番 .p12 パスワードへの差し替え** — 現在 `dontsleep`、強いランダム値に。

### 中期 (任意)

- **GitHub Sponsors 設定** — 既存リンクは https://github.com/sponsors/yazikiyo5-star を指しているが、まだ Sponsors プロファイル未作成。
- **README をユーザー目線でさらに磨く** — スクリーンショットを実機 PNG に差し替え。
- **アイコンの SF Symbol 化** — 現在は絵文字 ☕ / 💤 でメニューバー描画。SF Symbol (`mug.fill` など) にすると配色問題が消える。
- **WidgetKit ウィジェット対応** — README の「今後の拡張 1」参照。SPM 構成のままでは無理、Xcode プロジェクト化が必要。
- **Login Item 自動起動 UX** — 既に `LaunchAtLoginHelper` あるので、設定画面トグルにつなぐだけ。

### 長期 (DontSleep 単体ではない)

- **Sparkle.framework によるアプリ内アップデーター** — 現在は GitHub Releases 手動チェック。将来的にアプリから自動アップデート可。
- **macOS 14+ 限定機能 (デスクトップウィジェット, コントロールセンター)**

---

## 9. ライセンス・著作権

- ソースコード: ライセンス未指定 (現状 All Rights Reserved)
- 公開時点でのライセンスを決めたい場合: README に SPDX-License-Identifier コメントを足し、`LICENSE` ファイルを追加。MIT / BSD-2-Clause / Apache-2.0 が個人プロジェクトでは典型。

---

## 10. 関連ドキュメント (このリポジトリ内)

- [README.md](./README.md) — ユーザー向けインストール・ビルド・トラブルシューティング
- [SIGNING_SETUP.md](./SIGNING_SETUP.md) — Apple Developer 加入から証明書発行までの手順 (本セッションの実体験ベース)
- [DISTRIBUTION.md](./DISTRIBUTION.md) — Developer ID 配布の詳細
- [ETHICALADS.md](./ETHICALADS.md) — EthicalAds 申請手順
- [SPEC_v1.0.md](./SPEC_v1.0.md) — v1.0 機能仕様
- [ads/README.md](./ads/README.md) — ハウス広告フィード仕様
- [docs/privacy.html](./docs/privacy.html) — Privacy Policy

---

> 本ドキュメントは Claude (Opus 4.7) との共同作業で 2026-04-26 に v0.1.0 を出荷するまでの実作業ログを構造化したもの。新規バージョンを切るたびに 6 章 (運用情報) と 8 章 (pending) を更新するとよい。
