# DontSleep v1.0 配布版 UX・実装仕様書

- 版: 1.0.0-draft
- 作成日: 2026-04-20
- 対象: DontSleep（macOS 13+ メニューバー常駐アプリ）
- スコープ: UX 仕様 ＋ 実装インパクト（既存実装との差分・新規追加ファイル・工数概算）

---

## 0. 本書の位置づけ

既存の `README.md`（使い方）、`DISTRIBUTION.md`（配布手順）、`SIGNING_SETUP.md`（証明書まわり）を補完し、**配布版 v1.0 に向けて実装・UIをどう作り込むか**を定義する。実装（`Sources/DontSleep/**.swift`）の現状を起点に、何を残し・何を変更し・何を新規追加するかを明示する。既存ドキュメントの内容は繰り返さず、差分と判断基準のみを記述する。

---

## 1. 背景と現状整理

### 1.1 DontSleepの現状（as-is）

| 項目 | 現状 |
|---|---|
| 監視方式 | `ps -Axo comm=` を 3秒おきにポーリング（`ProcessMonitor.swift`） |
| 監視対象の指定 | ユーザーが**プロセス名の文字列**をテキストフィールドで入力・追加（`PreferencesView.swift`） |
| 既定監視リスト | `claude`, `codex`, `aider`, `ollama` の4件 |
| 抑止モード | `caffeinate`（既定）／ `pmset disablesleep`（要 sudoers セットアップ） |
| 手動操作 | メニューバーから「手動で常時ON」トグル（`AppDelegate.swift`） |
| 表示 | メニューバーに絵文字 ☕ / 💤、Dock非表示（`.accessory`） |
| 収益化 | 抑止中に画面右下にスポンサーバナー（House Ads / EthicalAds 切替可能） |
| 配布準備 | DMG は生成済み（未公証）、ランディングページ / プライバシーポリシー済み、Apple Developer Program 申込は決済フェーズ |

### 1.2 配布版に向けた主要ギャップ

1. **設定UIが技術者向けすぎる**：プロセス名を自分で打ち込む体験は、Developer/Terminal に不慣れな層には使えない。
2. **何がなぜ抑止されているかが薄い**：メニューの `● 抑止中` だけで、どのプロセスが引き金かが見えない。
3. **バッテリー節約という差別化価値がUIに乗っていない**：常時ON競合（Amphetamine/Caffeine）との違いをユーザーが認識できない。
4. **オンボーディングが無い**：初回起動時に何をすべきかの導線がない（権限要求も散発的）。

本仕様書は 1–4 を v1.0 配布までに埋めることを目的とする。

---

## 2. ターゲットユーザーと価値提案

### 2.1 想定ユーザー像

- **主ペルソナ**: AIエージェント（Claude Code, Aider, Cursor, Ollama など）でコーディングや長時間処理を回す技術者
- **副ペルソナ**: ローカルLLMを常用するML/データ分析ユーザー、長時間レンダリング／エンコードを行うクリエイター

### 2.2 コアバリュー（1行）

> **あなたがAIを使っている間だけ、Macを起きたままにします。常時ONじゃないから、バッテリーが無駄にならない。**

この1文は以下に反映する：公式LPのヒーロー文、オンボーディング1画面目、App Storeではない外部配布ページのメタディスクリプション。

### 2.3 競合差別化マトリクス

| | Amphetamine / Caffeine | DontSleep v1.0 |
|---|---|---|
| 起動中ずっと抑止 | ○ | × （既定では自動検知のみ） |
| 特定プロセスが動いている間だけ抑止 | × | ○ |
| バッテリー節約 | 手動管理が必要 | 自動で抑止／解除 |
| 蓋閉じスリープ抑止 | Amphetamine は可（非App Store） | ○（pmset モード） |
| 抑止理由の可視化 | △ | ○（引き金プロセスを表示） |

---

## 3. プロダクト原則（確定した設計判断）

以下は v1.0 以降、ブレさせない設計原則とする。

### 3.1 動作モードは「2つだけ」

- **自動検知モード（既定）** — 登録済みアプリが動いている間だけ抑止。止まったら抑止解除。
- **手動常時ON** — 自動検知の状態に関わらず、ユーザーが明示的にONにしている間は抑止。

タイマー抑止（「1時間だけ」など）は**採用しない**。理由：AIエージェントの処理時間は事前に予測できないため、時間で区切るUXはユースケースに合わない。この判断は v1.1 以降も継続する（恒久除外）。

### 3.2 選択粒度は「アプリ」、内部実装は「プロセス名」

UI はインストール済みアプリのアイコン＋名前で選ばせる。選ばれたアプリは、内部的にバンドルの `CFBundleExecutable` やバンドルIDを介してプロセス名に展開し、既存の `ProcessMonitor` に渡す。

**CLIツール（Claude Code の `claude`、Aider の `aider` など）**は .app バンドルではないので、内部に「AI CLI プリセット」として持ち、アプリ選択UIの上に別セクション「AI CLI ツール」として表示する。

### 3.3 バッテリー節約を中心メッセージに据える

- オンボーディング1画面目、設定画面の上部、公式LPヒーローに、**「常時抑止と違ってバッテリーを無駄にしない」**旨を明示。
- 自動検知モードのラベルは「**バッテリー節約モード（推奨）**」と呼称する。

### 3.4 権限操作は透明かつ可逆

sudoers 書き換えは常に**全文プレビュー + 解除ボタン**をUIに同居させる。pmsetモード有効化時、アプリ内で以下を表示：

- 書き込むファイルパス（`/etc/sudoers.d/dontsleep`）
- 書き込み内容の全文（コピー可能）
- 解除方法（アプリ内ボタン一発、または `./scripts/uninstall_sudoers.sh`）

---

## 4. 情報アーキテクチャ（画面一覧）

```
初回起動
  └─ オンボーディング (4 画面)
       ├─ 1. ウェルカム（価値提案）
       ├─ 2. 監視するアプリを選ぶ（アプリスキャン＋選択）
       ├─ 3. 抑止モード（caffeinate 既定 / pmset は後で）
       └─ 4. ログイン時に自動起動するか

通常利用
  ├─ メニューバーアイコン（☕ / 💤）
  └─ ドロップダウンメニュー
        ├─ 状態行（何が抑止理由か）
        ├─ 手動常時ON トグル
        ├─ 抑止モード切替
        ├─ 監視中アプリ一覧（動作中は▶︎）
        ├─ 設定…
        ├─ pmset セットアップ／解除
        └─ 終了

設定画面（⌘,）
  ├─ セクションA: おすすめAIアプリ（スキャン結果から抽出）
  ├─ セクションB: 選択中のアプリ（×で解除）
  ├─ セクションC: その他のアプリ（検索＋全アプリリスト）
  ├─ セクションD: AI CLI ツール（プリセット）
  ├─ セクションE: 抑止モード
  └─ セクションF: 広告表示（既存）

モーダル
  ├─ pmsetモード有効化ダイアログ（sudoers プレビュー）
  ├─ ブラウザ追加時の警告ダイアログ
  └─ AIアプリ新規検出時の追加提案通知（メニューバー赤ドット）
```

---

## 5. 画面仕様詳細

### 5.1 オンボーディング（初回起動時のみ）

SwiftUIで `NSWindow(styleMask: .titled)` を1枚モーダル風に出し、4ステップのページャで構成する。全体サイズは 520×420 pt 推奨。完了後にUserDefaultsで `hasCompletedOnboarding = true` を立て、以降は再表示しない。

#### 画面1. ウェルカム

- ヘッダ: 「DontSleepへようこそ」
- サブヘッド: **「あなたがAIを使っている間だけ、Macを起きたままにします。常時ONじゃないから、バッテリーが無駄になりません。」**
- ビジュアル: ☕ アイコン + 電池アイコンの組み合わせイラスト（SVGで可）
- CTA: `次へ`

#### 画面2. 監視するアプリを選ぶ

- ヘッダ: 「どのアプリを使っているときに抑止しますか？」
- サブヘッド: 「ここで選んだアプリが動いている間だけ、スリープを止めます。」
- コンテンツ: **インストール済みアプリをスキャンした結果**から以下を2ブロックで表示（詳細は 5.3）：
  - **AI関連アプリ（おすすめ）** — Claude / Cursor / Continue / Ollama Desktop など、PCにインストールされているものだけをチェックボックス付きで表示。既定は全てチェック。
  - **AI CLI ツール** — `claude`, `codex`, `aider`, `ollama` をチェックボックスで表示。既定は全てチェック。
- CTA: `次へ`（0件でも進行可能だが警告：「監視対象ゼロだと自動検知は動作しません」）

#### 画面3. 抑止モードを選ぶ

- ヘッダ: 「抑止の強さを選んでください」
- ラジオボタン2択:
  - ◉ **caffeinate（おすすめ）** — 権限不要、画面を開いているとき確実に抑止
  - ○ **pmset disablesleep（蓋を閉じても抑止）** — 最初に1回だけ管理者パスワードが必要
- 画面下に「あとで設定画面から変更できます」
- `pmset` 選択時のみ、次画面に進もうとしたらセットアップダイアログ（5.5）を挟む
- CTA: `次へ`

#### 画面4. ログイン時に自動起動

- ヘッダ: 「Macを起動したら自動でDontSleepも起動しますか？」
- トグル: `ログイン時に起動` （既定ON）
- 実装は `SMAppService.mainApp.register()`（macOS 13+）
- CTA: `はじめる` → メインUIへ

### 5.2 メニューバー

#### アイコン状態

| 状態 | アイコン | ツールチップ |
|---|---|---|
| 待機中 | 💤（SF Symbol `moon.zzz.fill` に置換） | DontSleep: 待機中 |
| 抑止中（自動） | ☕（SF Symbol `mug.fill`） | DontSleep: 抑止中 — [プロセス名] を検知 |
| 抑止中（手動） | ☕ + 鍵アイコン重ね or バッジ | DontSleep: 手動で抑止中 |
| AI候補検出（未登録） | 💤 + 赤ドット | 新しいAIアプリを検出しました |

SF Symbol 化により、ダーク/ライトモード自動対応＋Retina崩れ解消。

#### ドロップダウン先頭「状態行」

現在の `● 抑止中` / `○ 待機中` だけの1行から、以下に刷新する：

- 抑止中: `● 抑止中 — Claude Code を検知 (3分前から)`
- 待機中: `○ 待機中 — 最終検知: 14分前（Ollama）`
- 手動ON: `● 手動で抑止中（14分経過）`
- 未登録候補検知: `⚠ 未登録のAIアプリ「Cursor」を検出 — 追加しますか?`（行クリックで1クリック追加）

### 5.3 設定画面（アプリスキャン＋選択）

現行の `PreferencesView.swift` はテキスト入力＋リスト。以下に刷新する。サイズは 560×640 pt 推奨。

#### セクションA. おすすめAIアプリ

- 起動時 + 30分おきにバックグラウンドでアプリスキャン
- 対象ディレクトリ: `/Applications`, `~/Applications`, `/System/Applications`
- プリセット「AIアプリバンドルID一覧」（JSONで内包＋更新可能）と照合し、**インストール済みのものだけ**を縦並びで表示
- 表示要素: アイコン（64px）／アプリ名／トグルスイッチ
- 初期プリセット候補: Claude.app, Cursor.app, Continue.app, Ollama.app, Zed.app, Windsurf.app, その他 `ai`, `llm`, `claude`, `codex` を名前に含むもの

#### セクションB. 選択中のアプリ

- セクションA/C/Dで選択済みのものを横スクロールのチップ型リストで一覧表示
- 各チップは `[アイコン] アプリ名 [×]`、×クリックで1操作解除
- 0件のとき: 「監視対象が未設定です。上のリストから選んでください。」

#### セクションC. その他のアプリを追加

- 検索ボックス（インクリメンタル絞り込み）
- 全アプリリスト（スクロール可能、アイコン＋アプリ名）
- クリックで選択／再クリックで解除
- **ブラウザカテゴリ（Safari, Chrome, Firefox, Edge, Arc, Brave, Vivaldi, Chromium, Orion）を追加しようとしたら 5.6 の警告ダイアログを表示**

#### セクションD. AI CLI ツール

- チェックボックスリスト: Claude Code (`claude`), OpenAI Codex (`codex`), Aider (`aider`), Ollama (`ollama`), Continue CLI (`continue`), Gemini CLI (`gemini`), その他カスタム入力
- カスタム入力は現行の UI を踏襲（テキスト入力＋「追加」）。CLI 使用者は従来通り柔軟に拡張できる

#### セクションE. 抑止モード

- 既存ラジオ（`caffeinate` / `pmset`）を継承
- pmset セクションに「**解除する**」ボタンを追加（`uninstall_sudoers.sh` 相当を実行）

#### セクションF. 広告表示

- 既存 UI そのまま継承（`adsEnabled`, `adProviderKind` 等）

### 5.4 ドロップダウンからの手動常時ON

既存の「手動で常時ON」トグルはそのまま。加えて、**オプション＋メニューバーアイコンクリックでワンアクショントグル**のショートカットを追加する。

### 5.5 pmsetモード有効化ダイアログ

オンボーディングで pmset を選んだとき、または設定画面でモード切替したときにのみ表示。

- 見出し: 「pmsetモードを有効化しますか？」
- 本文（以下を箇条書きで明示）:
  - 書き込む場所: `/etc/sudoers.d/dontsleep`
  - 書き込む内容（コピー可能なテキストブロックで全文表示）:
    ```
    ユーザー名 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
    ```
  - 管理者パスワード入力が1回だけ必要
  - あとで解除するには：このアプリ内の「解除する」ボタン一発、または `./scripts/uninstall_sudoers.sh`
- CTA: `有効化する` / `キャンセル`

### 5.6 ブラウザ追加時の警告ダイアログ

- 見出し: 「ブラウザを監視対象に追加しますか？」
- 本文: 「ブラウザを監視すると、ブラウザを開いているだけでスリープ抑止され続けます。バッテリーを節約したい場合は、必要なときだけ手動トグル（常時ON）を使う方がおすすめです。」
- CTA: `それでも追加` / `キャンセル`

---

## 6. 状態機械と自動検知ロジック

### 6.1 状態遷移

```
            ┌─────────────────────────────────────────┐
            │                                         │
            ▼                                         │
    ┌──────────────┐   監視対象プロセス検知       ┌──────────────┐
    │  待機中      │ ─────────────────────────▶  │  抑止中       │
    │  Idle        │ ◀───────────────────────── │  Suppressing  │
    └──────┬───────┘   すべて停止                └──────┬───────┘
           │                                             │
           │ 手動ON                                      │ 手動ON
           ▼                                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │           手動抑止中（Manual Override）                 │
    │    自動検知の状態に関わらず抑止し続ける                 │
    └─────────────────────────────────────────────────────────┘
```

実装上は既存の `AppDelegate.reevaluate(anyRunning:)` の挙動を踏襲し、`manualOverride || anyRunning` で決定する。変更なし。

### 6.2 未登録AIアプリのサジェスト

- バックグラウンドで動作中プロセス名 + フォアグラウンドアプリの `NSWorkspace.shared.frontmostApplication` を監視
- プリセットJSON内の「AIアプリ／CLI辞書」と照合し、未登録なのに動作中のものを検出したらメニューバーに赤ドット＋ドロップダウン1行目に「追加しますか?」
- ユーザーのIgnoreを1回でも受け付けた候補は、そのバージョンのアプリバンドルについては再提案しない

### 6.3 検知漏れ対策（運用）

- プリセットJSONは公式サイトから**定期取得**（起動時 + 24h）し、本体更新なしでAIツール追従
- フォーマット（例）:
  ```json
  {
    "version": "2026-04-20",
    "ai_apps": [
      { "bundleId": "com.anthropic.claudefordesktop", "displayName": "Claude", "executable": "Claude" },
      { "bundleId": "com.cursor.Cursor", "displayName": "Cursor", "executable": "Cursor" }
    ],
    "ai_clis": [
      { "name": "claude", "displayName": "Claude Code" },
      { "name": "aider", "displayName": "Aider" }
    ]
  }
  ```

---

## 7. データモデル（UserDefaults）

### 7.1 追加キー（v1.0）

| キー | 型 | 既定値 | 用途 |
|---|---|---|---|
| `hasCompletedOnboarding` | Bool | false | オンボーディング再表示判定 |
| `watchedAppBundleIDs` | [String] | プリセット由来 | 選択中のアプリ（バンドルID） |
| `watchedCLINames` | [String] | `["claude","codex","aider","ollama"]` | CLI ツール（旧 `watchedProcessNames` を継承し改名可） |
| `launchAtLogin` | Bool | true | ログイン時起動 |
| `aiPresetFeedURL` | String | 公式URL | プリセットJSON取得先 |
| `suggestedIgnoreList` | [String] | [] | 「追加しない」と言われたバンドルIDの無視リスト |
| `lastDetectionMeta` | Data(JSON) | nil | 「最終検知: 14分前」表示用 |

### 7.2 既存キーの扱い

- `watchedProcessNames`（現行）→ **既存ユーザー向けマイグレーション**で `watchedCLINames` に移行
- `suppressionMode`, `adsEnabled`, `adProviderKind`, `houseAdsFeedURL`, `ethicalAdsPublisher` は現状維持

### 7.3 内部変換層

- 保存: `watchedAppBundleIDs` ＋ `watchedCLINames`
- 監視ループ渡し: バンドルID → バンドル解決 → `CFBundleExecutable` を取得して `watchedProcessNames` 配列を動的生成し、既存 `ProcessMonitor.updateWatchedProcessNames(_:)` に渡す
- これにより `ProcessMonitor.swift` への変更は不要

---

## 8. 配布 UX

### 8.1 DMG 設計

- 背景画像に「DontSleep.app → Applications」の矢印付きレイアウト（`hdiutil` + 背景PNG）
- ウィンドウサイズ・アイコン位置を `AppleScript` で指定
- `SHA256` を公式LPに併記し、改ざん検出を可能に

### 8.2 初回起動 UX

- 公証済みであれば Gatekeeper の「確認されたデベロッパ」警告1回のみで起動可能
- 公証未完了の場合は Right-click → Open で開く手順をLPに明記
- 起動後、セクション5.1 の4画面オンボーディングが走る

### 8.3 アップデート

- v1.0 は手動更新前提（LPのダウンロードボタン）
- `CFBundleShortVersionString` + `CFBundleVersion` を DMG ファイル名と連動
- v1.1 で Sparkle を導入し、起動時 + 24時間おきに `appcast.xml` 確認

---

## 9. プライバシー & 信頼性メッセージング

### 9.1 アプリ内文言

- 設定画面フッタ: 「DontSleepはプロセス一覧をローカルで読むだけで、外部にはデータを送信しません。」
- pmsetダイアログ内: sudoers 書き込み内容の全文プレビュー（5.5 参照）
- 広告有効時: 「広告配信のためにオープンソースのEthicalAds SDKを利用します。個人情報は送信されません。」

### 9.2 公式サイト（既存 `docs/index.html` / `docs/privacy.html`）

- ヒーロー下に「バッテリー節約」セクションを新設し、競合マトリクス（2.3）を簡略ビジュアル化
- privacy.html は現行版を維持しつつ、本仕様のアプリスキャン挙動を1段落追記：「インストール済みアプリのスキャンはローカルで行われ、結果は外部に送信されません」

---

## 10. 実装インパクト（既存コードからの差分）

### 10.1 新規追加ファイル

| ファイル | 役割 | 概算行数 |
|---|---|---|
| `Sources/DontSleep/OnboardingView.swift` | 4画面のSwiftUIページャ | ~250 |
| `Sources/DontSleep/OnboardingWindowController.swift` | オンボーディングWindow管理 | ~60 |
| `Sources/DontSleep/InstalledAppScanner.swift` | `/Applications` 等スキャン、アイコン取得 | ~180 |
| `Sources/DontSleep/AIPresetStore.swift` | プリセットJSONの取得・キャッシュ・照合 | ~150 |
| `Sources/DontSleep/AppSelectionView.swift` | セクションA/B/C のSwiftUI | ~300 |
| `Sources/DontSleep/LaunchAtLoginHelper.swift` | `SMAppService` ラッパ | ~40 |
| `Sources/DontSleep/MenuBarFormatter.swift` | 状態行の文言生成（「Claude Code を検知 (3分前から)」など） | ~80 |
| `Sources/DontSleep/SuggestionDetector.swift` | 未登録AI候補の発見 | ~120 |
| `Resources/ai-presets.json` | 同梱プリセット | ~5KB |

合計でおよそ **1,180行 + リソース1本**。

### 10.2 変更が必要な既存ファイル

| ファイル | 変更内容 |
|---|---|
| `AppDelegate.swift` | 起動時にオンボーディング判定、状態行の文言刷新、赤ドット描画、未登録サジェスト行の追加 |
| `PreferencesView.swift` | 現行のプロセス名リストUIを AppSelectionView に差し替え（CLI セクションは残す） |
| `Preferences.swift` | 7.1 の新キー追加、マイグレーション実装 |
| `ProcessMonitor.swift` | **変更なし**（渡すプロセス名を内部変換層で生成） |
| `SleepSuppressor.swift` / `SudoersInstaller.swift` | **変更なし** |
| `main.swift` | 変更なし |
| `docs/index.html` | ヒーロー下に「バッテリー節約」セクション追加 |
| `docs/privacy.html` | アプリスキャン挙動の記述を1段落追加 |
| `DontSleep.entitlements` | 変更なし（SMAppServiceはentitlements不要、スキャンはユーザー領域） |

### 10.3 工数概算（単独エンジニア、QA込み）

| 作業 | 目安 |
|---|---|
| InstalledAppScanner + AIPresetStore | 0.5日 |
| AppSelectionView (SwiftUI) | 1日 |
| OnboardingView 4画面 + コントローラ | 1日 |
| LaunchAtLogin (SMAppService) | 0.25日 |
| Preferences 移行 + マイグレーション | 0.5日 |
| AppDelegate 状態行リファクタ + サジェスト | 0.75日 |
| アプリアイコン・メニューバーSF Symbol対応 | 0.25日 |
| sudoersダイアログ全文プレビュー化 | 0.25日 |
| ブラウザ追加警告ダイアログ | 0.1日 |
| docs 更新（LP／プライバシー） | 0.25日 |
| QA・実機検証（macOS 13/14/15） | 1日 |
| **合計** | **約 5.85日** |

### 10.4 リスクと緩和

| リスク | 緩和策 |
|---|---|
| Bundle ID → 実行プロセス名の対応がずれる（ローカライズされた実行ファイル名など） | プリセットJSONに `executable` を明示的に持たせ、バンドル解決＋プリセットのダブルキャスト。`NSRunningApplication.runningApplications` でのbundleID一致検知もフォールバックで併用 |
| ブラウザ常時抑止でのバッテリー問題 | 5.6 の警告ダイアログ＋設定画面で該当カテゴリに警告アイコンを常時表示 |
| アプリスキャン時の遅延（1,000本超の環境） | バックグラウンドキューで非同期、結果を UserDefaults にキャッシュ、起動時はキャッシュ即表示→差分更新 |
| プリセットJSON配布元がダウン | ローカル同梱版を既定でバンドル、オンライン取得は上書きのみ |
| `ps -Axo comm=` の3秒ポーリング負荷 | 既存実装で十分軽量（確認済み）。変更なし |

---

## 11. v1.0 スコープ外（将来の拡張）

- **Sparkle 自動更新** — v1.1 で導入、`appcast.xml` 運用
- **Widget (WidgetKit) / Control Center モジュール** — Xcodeプロジェクト化が必要、v1.1〜v1.2
- **Homebrew Cask 登録** — v1.0 配布が安定してから v1.1 で申請
- **多言語対応** — 日本語 → 英語の2言語対応をv1.1で
- **CPU使用率やネットワークI/Oベースの高度な検知** — v2.0 検討
- **タイマー抑止** — **恒久的に不採用**（3.1 参照）
- **App Store 版** — 機能が半分以下になるため現時点では不採用（`DISTRIBUTION.md` §「将来」参照）

---

## 12. 受入基準（v1.0リリース判定）

以下すべてが満たされることをリリースの条件とする。

1. 新規インストール時にオンボーディング（4画面）が走り、完了後は再表示されない
2. インストール済みアプリのスキャン結果から、AIアプリを1クリックで選択できる
3. メニューバードロップダウン先頭に「何が抑止理由か」が表示される
4. 監視対象アプリが動き始めて3秒以内に抑止が有効化される
5. 監視対象アプリが全て停止してから3秒以内に抑止が解除される
6. 手動常時ONは自動検知と独立して動作する
7. pmset モード有効化ダイアログで sudoers 書き込み内容が全文表示される
8. `./scripts/uninstall_sudoers.sh` または設定内ボタンで sudoers 設定が除去できる
9. ブラウザを監視対象に追加しようとすると警告ダイアログが出る
10. `SMAppService` によるログイン時起動がON/OFFできる
11. Developer ID 署名 + Notarization 済み DMG が `dist/` に生成される
12. macOS 13 / 14 / 15 それぞれの実機またはVMでオンボーディング〜抑止〜解除までの1サイクルが動く

---

## 付録A. 画面ワイヤー概要（文字ベース）

### オンボーディング画面2（アプリ選択）

```
┌────────────────────────────────────────────┐
│  どのアプリを使っているときに抑止しますか?  │
│  ここで選んだアプリが動いている間だけ、     │
│  スリープを止めます。                       │
│                                             │
│  🤖 AI関連アプリ（おすすめ）                │
│   ┌────────────────────────────────────┐   │
│   │ [Claude.icon]  Claude       [ ON ] │   │
│   │ [Cursor.icon]  Cursor       [ ON ] │   │
│   │ [Ollama.icon]  Ollama       [ ON ] │   │
│   └────────────────────────────────────┘   │
│                                             │
│  ⌨ AI CLI ツール                            │
│   ┌────────────────────────────────────┐   │
│   │ ☑ claude     ☑ codex               │   │
│   │ ☑ aider      ☑ ollama              │   │
│   └────────────────────────────────────┘   │
│                                             │
│                   [戻る]        [次へ →]   │
└────────────────────────────────────────────┘
```

### 設定画面（セクションA/B/C/D）

```
┌────────────────────────────────────────────┐
│  DontSleep 設定                             │
├────────────────────────────────────────────┤
│  🤖 おすすめAIアプリ                        │
│   [icon] Claude         [トグル ON]         │
│   [icon] Cursor         [トグル ON]         │
│   [icon] Ollama         [トグル OFF]        │
│                                             │
│  ✅ 選択中のアプリ                          │
│   [Claude][×]  [Cursor][×]                 │
│                                             │
│  ➕ その他のアプリを追加                    │
│   [検索ボックス🔍           ]               │
│   [icon] Figma                              │
│   [icon] Slack                              │
│   [icon] Google Chrome ⚠                    │
│   …                                         │
│                                             │
│  ⌨ AI CLI ツール                            │
│   ☑ claude  ☑ codex  ☑ aider  ☑ ollama     │
│   [カスタム追加: ______] [追加]             │
│                                             │
│  🔋 抑止モード                              │
│   ◉ caffeinate（権限不要）                  │
│   ○ pmset disablesleep（蓋閉じ対応）        │
│        [解除する]                           │
│                                             │
│  📢 広告表示                                │
│   …（既存UI）                               │
└────────────────────────────────────────────┘
```

---

## 付録B. 参照ファイル

- 現状実装: [Sources/DontSleep/](./Sources/DontSleep/)
- 配布手順: [DISTRIBUTION.md](./DISTRIBUTION.md)
- 証明書セットアップ: [SIGNING_SETUP.md](./SIGNING_SETUP.md)
- 広告連携: [ETHICALADS.md](./ETHICALADS.md)
- ランディングページ: [docs/index.html](./docs/index.html)
- プライバシーポリシー: [docs/privacy.html](./docs/privacy.html)

---

以上。本仕様書は v1.0 リリースをもって確定。v1.1 以降の変更は別ファイル `SPEC_v1.1.md` に分離する。
