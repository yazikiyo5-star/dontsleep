# DontSleep 配布ガイド (Developer ID + 公証)

このドキュメントは App Store を経由せず、**Developer ID + Notarization** で DontSleep を外部配布する手順をまとめたものです。App Store は本アプリの要件（`caffeinate` 子プロセス / `pmset` / `/etc/sudoers.d/`）と互換性が無いため、こちらのルートを選びました。

---

## なぜ App Store ではないのか（短い確認）

App Store 提出は **App Sandbox が必須** です。本アプリが使っている以下の機能はすべてサンドボックスに阻まれます:

| 機能 | サンドボックス |
|---|---|
| `caffeinate` を子プロセス起動 | ❌ 任意の外部プロセス起動禁止 |
| `sudo pmset -a disablesleep` | ❌ システム全体設定の変更禁止 |
| `/etc/sudoers.d/dontsleep` 書き込み | ❌ システムファイル書き込み禁止 |
| 他プロセス検知 (`ps -Axo comm=`) | ❌ 他アプリ情報取得不可 |

類似アプリの Amphetamine も、App Store 版では「蓋閉じ抑止」を提供していません（IOPMAssertion でアイドルスリープだけ）。蓋閉じ対応が欲しい以上、Developer ID 配布が唯一の選択肢です。

---

## 必要なもの

1. **Apple Developer Program 加入** ($99/年, [developer.apple.com](https://developer.apple.com))
2. **Developer ID Application 証明書**（Keychain にインストール済み）
3. **App-Specific Password**（公証用, [appleid.apple.com](https://appleid.apple.com) で発行）
4. **Xcode または Xcode Command Line Tools**（`codesign`, `notarytool`, `xcrun stapler` を含む）

---

## 配布フロー全景

```
 swift build → .app バンドル生成 → Hardened Runtime で署名 → DMG にパッケージ
     → DMG も署名 → notarytool で公証 → stapler で公証チケットを添付 → 配布
```

各ステップを下で解説します。

---

## 1. 証明書の確認

```bash
# インストール済みの署名用証明書を確認
security find-identity -v -p codesigning
```

出力例:
```
1) ABCD1234EFGH5678IJKL "Developer ID Application: Haru Iijima (TEAMID123)"
```

この `"Developer ID Application: ..."` の文字列全体を `SIGN_IDENTITY` として以下で使います。

---

## 2. Hardened Runtime で .app に署名

DontSleep は子プロセス（caffeinate, sudo, osascript）を起動するので、**エンタイトルメント** を付けて署名する必要があります。
Hardened Runtime 配下では、子プロセス起動にこのフラグが必須です。

### 2a. エンタイトルメントファイルを作る

`DontSleep.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime 下で caffeinate, sudo, osascript を起動するため -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <!-- AppleScript (osascript) を実行するため -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### 2b. 署名コマンド

```bash
SIGN_IDENTITY="Developer ID Application: Haru Iijima (TEAMID123)"
APP_PATH="dist/DontSleep.app"

codesign --force --deep --timestamp \
    --options runtime \
    --entitlements DontSleep.entitlements \
    --sign "$SIGN_IDENTITY" \
    "$APP_PATH"

# 署名結果を確認
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"
```

`--options runtime` が Hardened Runtime 有効化。公証には必須です。

---

## 3. DMG を作る

```bash
APP_PATH="dist/DontSleep.app"
DMG_PATH="dist/DontSleep.dmg"
STAGING="dist/dmg-staging"

rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
# Applications フォルダへのシンボリックリンクを入れておくとドラッグ&ドロップで楽
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "DontSleep" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

# DMG 自体にも署名
codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"
```

---

## 4. 公証 (Notarization)

`notarytool` は Apple ID とアプリ固有パスワードを使います。初回に一度 keychain に保存しておくと楽。

### 4a. 認証情報を keychain に保存（初回のみ）

```bash
xcrun notarytool store-credentials "DontSleepNotary" \
    --apple-id "your-apple-id@example.com" \
    --team-id "TEAMID123" \
    --password "xxxx-xxxx-xxxx-xxxx"    # App-Specific Password
```

### 4b. DMG を公証サーバに送る

```bash
xcrun notarytool submit dist/DontSleep.dmg \
    --keychain-profile "DontSleepNotary" \
    --wait
```

`--wait` で完了までブロック（数分〜十数分）。成功すると `status: Accepted` が返ります。
失敗した場合は `xcrun notarytool log <submission-id> --keychain-profile DontSleepNotary` でログを取得して原因を確認。

### 4c. 公証チケットを DMG と .app に貼り付ける (stapling)

```bash
xcrun stapler staple dist/DontSleep.dmg
xcrun stapler staple dist/DontSleep.app
```

こうしておくと、配布先 Mac がオフラインでも Gatekeeper 検証が通ります。

---

## 5. 検証

配布直前の最終チェック:

```bash
# 公証済みかの確認
spctl --assess --type open --context context:primary-signature --verbose dist/DontSleep.dmg
stapler validate dist/DontSleep.app
```

`source=Notarized Developer ID` と表示されればOK。

---

## 6. 配布

あとは DMG をどこかに置くだけ:

- GitHub Releases (最もシンプル、署名済みなので OS も信頼する)
- 自分のウェブサイト
- Gumroad / Lemon Squeezy（有料配布したい場合）

ユーザーは DMG をマウント → `DontSleep.app` を `Applications` にドラッグ → 初回起動時に Gatekeeper が「確認されたデベロッパ」として許可する、という流れ。

---

## 自動化スクリプトのたたき台

上記を `scripts/release.sh` にまとめた雛形:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_IDENTITY="Developer ID Application: Haru Iijima (TEAMID123)"
NOTARY_PROFILE="DontSleepNotary"

./scripts/build_app.sh
codesign --force --deep --timestamp --options runtime \
    --entitlements DontSleep.entitlements \
    --sign "$SIGN_IDENTITY" dist/DontSleep.app

rm -rf dist/dmg-staging dist/DontSleep.dmg
mkdir -p dist/dmg-staging
cp -R dist/DontSleep.app dist/dmg-staging/
ln -s /Applications dist/dmg-staging/Applications
hdiutil create -volname DontSleep -srcfolder dist/dmg-staging \
    -ov -format UDZO dist/DontSleep.dmg
codesign --force --sign "$SIGN_IDENTITY" dist/DontSleep.dmg

xcrun notarytool submit dist/DontSleep.dmg \
    --keychain-profile "$NOTARY_PROFILE" --wait

xcrun stapler staple dist/DontSleep.dmg
xcrun stapler staple dist/DontSleep.app

echo "✅ dist/DontSleep.dmg ready for distribution"
```

使う前に `SIGN_IDENTITY` と `NOTARY_PROFILE` を自分の値に置き換えてください。

---

## よくある引っかかりどころ

| 症状 | 原因 / 対処 |
|---|---|
| `codesign: invalid Info.plist` | `CFBundleIdentifier` がリバースドメイン形式 (`com.xxx.yyy`) になっているか確認 |
| `notarytool` が `Invalid` 判定 | `--options runtime` 無しで署名した、またはエンタイトルメント不足。`notarytool log` でログを見る |
| 起動時に「開発元を確認できない」 | DMG → .app 両方に stapler したか再確認 |
| caffeinate が起動しない | Hardened Runtime 下で entitlements が不足。`disable-library-validation` などが必要 |
| Apple Silicon + Intel 両対応 | `swift build` をデフォルトで動かすと単一アーキになる。`swift build -c release --arch arm64 --arch x86_64` で universal binary を作る。または `lipo -create` で2つをマージ |

---

## 将来: App Store 版も作る場合

現状コードをフォークして、以下に置き換え:

1. `SleepSuppressor` → `IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString, ...)` に置換
2. `caffeinate` / `pmset` / `SudoersInstaller` を全削除
3. `ProcessMonitor` は `NSRunningApplication.runningApplications` に置換（バンドルIDのみ検知、CLIツールは検知不可）
4. `Info.plist` に `NSAppleEventsUsageDescription` などを追加
5. Xcode Project 化して App Sandbox を有効にし、App Store Connect から TestFlight / 審査へ

機能は半分以下になりますが、App Store の認知度とユーザー導線は魅力的なので、両方出す戦略は後からでも取れます。
