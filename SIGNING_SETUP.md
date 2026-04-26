# DontSleep — Developer ID 署名・公証 セットアップガイド

これは **一度だけ** 手でやる作業。終わったら以後は `./scripts/release.sh` 一発で
DMG が完成する。

---

## 前提：Apple Developer Program 加入（$99 / 年）

自分の Apple ID で https://developer.apple.com/programs/enroll/ から加入。
個人契約ならだいたい24〜48時間で承認される。

---

## 1. Developer ID Application 証明書の発行

1. Xcode を起動 → Settings → Accounts → 対象 Apple ID を追加
2. 下のほうの *Manage Certificates...* をクリック
3. 左下の「+」→ **Developer ID Application** を選択
4. 自動で Keychain に保存される（private key 付き）

確認：

```bash
security find-identity -v -p codesigning
# => "Developer ID Application: 飯島 春彦 (ABCD1234EF)"  など
```

もし Xcode を使いたくない場合：

1. https://developer.apple.com/account/resources/certificates/list にアクセス
2. 「+」→ **Developer ID Application** → 手元で `Certificate Signing Request` を
   キーチェーンアクセス.app から作成してアップロード
3. 発行された `.cer` をダブルクリックでキーチェーンにインポート

---

## 2. App-Specific Password を作成

notarytool は普通の Apple ID パスワードを受け付けない。

1. https://account.apple.com/account/manage にアクセス
2. *Sign-In and Security* → *App-Specific Passwords* → 「+」
3. ラベル例: `notarytool-dontsleep`
4. 生成された **16 文字** のパスワードをコピー（画面を閉じると二度と見られない）

---

## 3. Team ID を控える

https://developer.apple.com/account → *Membership Details* → **Team ID**（10文字）をコピー。

---

## 4. notarytool にログイン情報を保存

```bash
xcrun notarytool store-credentials DontSleep \
    --apple-id "あなたの@apple.id" \
    --team-id "ABCD1234EF" \
    --password "xxxx-xxxx-xxxx-xxxx"      # 手順2で作った app-specific password
```

確認：

```bash
xcrun notarytool history --keychain-profile "DontSleep"
# Successfully received submission history.
# createdDate  id  name  status  <empty if first time>
```

---

## 5. 本番ビルド

```bash
cd ~/Documents/Claude/Projects/dont\ sleep/DontSleep
./scripts/release.sh
```

これで自動的に：
- `.app` をビルド
- Developer ID Application で `--options runtime` 付きコード署名
- DMG 作成
- Apple に公証提出 → 完了待ち
- `.app` と `.dmg` にステイプル
- `spctl` で Gatekeeper 受理を確認

完成物：

```
dist/DontSleep-0.1.0.dmg
```

この DMG は **他人の Mac に渡しても** Gatekeeper が通る。

---

## 一時しのぎ：ad-hoc 署名（Developer ID 発行待ちの間に自分の Mac で試す）

Apple Developer 加入が承認される前でも、**自分の Mac 専用**ならこれでOK：

```bash
ADHOC=1 ./scripts/release.sh
```

Gatekeeper 判定は落ちるが、自分で `xattr -dr com.apple.quarantine DontSleep.app`
するか「開く」を右クリックから許可すれば動く。**他人には絶対配らないこと。**

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `no identity found` | 証明書が別のキーチェーンに入っている | `login.keychain-db` に手でドラッグ |
| `errSecInternalComponent` | private key が見つからない | 同じ Mac で CSR を作って再発行 |
| `notarytool` が `Invalid Credentials` | app-specific password 誤り | 手順2 で作り直す（複数作ってOK） |
| `stapler` が "No ticket" | 公証はまだ伝播中 | 5 分待ってリトライ |
| Gatekeeper 判定が reject | Hardened Runtime 欠如 | `release.sh` が `--options runtime` を付けていることを確認 |
