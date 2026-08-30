# Tilecheck リリース手順

**方針：APIで到達できることは全部Claude側でやる。**
本人に頼むのは、人間でなければ物理的に無理なものだけ。
（`~/.claude/CLAUDE.md`「作業の分担」／`~/.claude/iOS-DEVLOG.md` 5-0、4-49〜4-51）

App ID `6806789668` / バンドルID `com.zzzjjj080.Mochimono` / バージョン `1.0 (1)`

## 済んでいること（すべてClaude側）

- [x] Explicit App ID の登録（`2K77Y5M6HH`）
- [x] ビルドのアップロード → **`1.0 (1)` は `VALID`。バージョンに紐づけ済み**
- [x] 暗号化の申告（`Info.plist` の `ITSAppUsesNonExemptEncryption = NO` で自動的に済む）
- [x] サブタイトル／プライバシーポリシーURL
- [x] 概要／キーワード／プロモーション文／サポートURL／マーケティングURL
- [x] 著作権 `2026 Jin Nakamura`、リリース方法は**手動**
- [x] 審査の連絡先とメモ（連絡先は前作からAPIで引いた）、**サインイン不要**
- [x] スクリーンショット 6.5インチ・6.9インチ 各5枚（10枚とも `COMPLETE`・エラー0）
- [x] 年齢制限の申告（すべて該当なし）
- [x] 第三者の素材を使っていない（`contentRightsDeclaration`）
- [x] カテゴリ：**仕事効率化**（副：ユーティリティ）
- [x] 価格：**無料**（基準の地域 JPN）
- [x] 配信地域：**日本のみ**。新しい地域が増えても自動配信しない
- [x] GitHub に push（`docs/` にサポートページとプライバシーポリシー）

## 残り2つ（本人しかできない）

### 1. アプリのプライバシー →「データを収集しません」

**理由：`appDataUsages` は API に存在しない。**（`POST /v1/appDataUsages` → 404。
審査に出せない理由としては返ってくるのに、エンドポイントが無い。→ 4-51）

App Store Connect → Tilecheck → 左の「**アプリのプライバシー**」
→ データ収集の質問に「**いいえ、このAppからデータを収集しません**」

通信しないアプリなので、これで終わり。

### 2. GitHub Pages を有効にする

**理由：トークンが無いのでGitHubのAPIを叩けない。**
（repoスコープの Personal Access Token をもらえれば、以後はClaude側でできる）

https://github.com/zzzjjj080/mochimono/settings/pages
→ Source: **Deploy from a branch** → Branch: **main** → フォルダ: **`/docs`**

**既定は `/(root)` なので必ず変える**（→ 4-42）。反映に1〜3分。

## そのあと（Claude側）

1. `curl` でサポートURLとプライバシーURLが 200 を返すことを確認する。
   **404のまま審査に出さない。**
2. 審査に提出する。提出枠は作ってあるので、アイテムを足して `submitted=true` にするだけ。

```
reviewSubmission: 397190ad-c52f-4a6f-8a31-6af1dd8b56f4
appStoreVersion:  9b6b0e24-0ba6-47b5-92c4-5cae5ab19afc
```

## 使う道具

```bash
./Tools-ASC.py get /v1/apps                        # App Store Connect API
./Tools-UploadScreenshots.py <locId> APP_IPHONE_65 store/screenshots-65
./install-device.sh                                # 接続中のiPhoneに入れる
swiftc -O Tools-MakeIcon.swift -o /tmp/makeicon && /tmp/makeicon <出力先>
swiftc -O store/MakeScreenshots.swift -o /tmp/makeshots
/tmp/makeshots store/raw store/screenshots         # 6.9インチ
/tmp/makeshots store/raw store/screenshots-65 1242 2688
xcrun simctl launch booted com.zzzjjj080.Mochimono -screenshot-demo
```
