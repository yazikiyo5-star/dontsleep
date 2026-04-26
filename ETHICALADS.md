# EthicalAds 申請手順 — DontSleep

EthicalAds は Read the Docs が運営する開発者向けプライバシー重視広告ネットワーク。
DontSleep には `EthicalAdsProvider` が同梱されており、publisher id を入れれば
そのまま動く状態で待機している。

## 承認のハードル

EthicalAds は「まず site の中身」を見られる想定なので、Mac 専用のネイティブアプリを
申請する場合、**プロジェクトの Web プレゼンスが必要**。最低限：

- プロダクトの紹介ページ（GitHub Pages で可）
- GitHub リポジトリ
- 想定トラフィック（MAU / DAU のラフな目標）

## 1. 下ごしらえ（申請する前に）

1. GitHub リポジトリを public にする（名前案: `dontsleep`）
2. GitHub Pages でランディングページを公開する
   - 最低限: スクリーンショット、機能説明、License、ダウンロードリンク
   - 広告欄のスクリーンショットを必ず入れる（EthicalAds が placement を確認できる）
3. プライバシーポリシーを書いて同じサイトに公開する
   - 「EthicalAds を通じて匿名の表示計測をしていること」
   - 「個人情報は一切送らないこと」

## 2. 申請

1. https://www.ethicalads.io/publishers/ にアクセス
2. 「Apply to publish」フォームで以下を入力：

    | 項目 | 書く内容 |
    |---|---|
    | Site URL | GitHub Pages の URL |
    | Category | `Developer Tools` |
    | Monthly pageviews | 正直に。まだ 0 なら `< 1k` |
    | Description | 「DontSleep は macOS メニューバーアプリ。Claude Code 等の AI エージェント実行中だけ Mac をスリープさせない。配布は Developer ID 署名済みの .app。バナー広告は **アプリ内の 320x100 フローティングウィンドウ** に表示する」ことを**明記** |
    | Traffic source | 「主に GitHub / Hacker News / Product Hunt からの配布」 |

3. **「ネイティブアプリで表示する」ことを強調する**
   デフォルトだと Web publisher として審査されるので、placement が特殊であることを必ず書く。

## 3. 承認後の設定

1. EthicalAds ダッシュボードで「publisher id」を確認（例: `your-dontsleep`）
2. アプリの *設定 → 広告表示 → 広告ソース → EthicalAds* を選択
3. `publisher id` 欄に貼り付けて保存

これだけで `EthicalAdsProvider` が有効になり、
`https://server.ethicalads.io/api/v1/decision/` から広告が配信される。
空欄の間は自動的に `HouseAdProvider`（自前JSON + 組み込みフォールバック）が使われる。

## 4. 収益化の見込み

EthicalAds の CPM は平均 **$2–$5** 程度。
1日 100 impression = 月 3,000 imp ≈ 月 $6–$15。
本格的に収益化したいなら、EthicalAds は**まず第一歩**として使い、
並行して自前 JSON 枠をスポンサー直販することを推奨。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| バナーに "広告を読み込み中…" のまま | publisher id 間違い or inventory なし | HouseAd にフォールバックするので、`houseAdsFeedURL` を設定しておく |
| 承認申請が棄却された | ネイティブアプリだと説明不足 | スクリーンショット付きでもう一度申請、または `Carbon Ads` に切り替え |
| impression が計上されない | `view_url` を踏んでない | アプリログ `os_log` で確認（DontSleep/0.1 UA で GET される） |
