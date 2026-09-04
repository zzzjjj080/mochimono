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

## 1.0 (1) は 4.3(a) で却下された（2026-09-02）

> Guideline 4.3(a) - Design - Spam
> 既存の似たアプリと、バイナリ・メタデータ・コンセプトが似ていて差が小さい

**不具合の指摘ではない。** 同種アプリを数えたら91件あり、名前・サブタイトル・
キーワードのすべてが同じ棚に並ぶ作りになっていた。

立て直しの中身（1.0 (2)）:

- **テキスト⇄盤面を双方向にした。** 書き出し（共有シート）と貼り付けからの取り込み。
  独自の書式を使わないので、他アプリで書いた箇条書きもそのまま盤面になる
- 掲載情報から「チェックリスト」「忘れ物」「持ち物リスト」を落とし、機構の説明に書き直した
- スクリーンショットの1枚目を、テキストと盤面を並べたものにした
- **投げ銭は 1.0 から外した**（`AppFeature.showsTipJar = false`）。
  再審査の論点を「このアプリは独自か」の一点に絞るため。1.0 が通ったら 1.1 で戻す

**返信は API から投稿できない。**（`reviewSubmissions/{id}/messages` などは全部404）
本人が App Store Connect → App Review → 解決センターに貼る。
文面は `store/review-reply.txt`。

**順番は「ビルド差し替え → 返信 → 再提出」。**（6節）返信だけでは審査は再開しない。

### 2026-09-05 に再提出した

```
reviewSubmission: c6425193-e421-41c9-a98a-ae066453da03   （1.0 (2)）
旧:               397190ad-c52f-4a6f-8a31-6af1dd8b56f4   （1.0 (1) 4.3(a)で却下）
```

**却下されたバージョンは、古い提出枠に紐づいたまま残る。**
新しい提出枠にアイテムを足そうとすると
`was already added to another reviewSubmission` で 409 になる。
`DELETE /v1/reviewSubmissionItems/<id>` も 409 で外せない。

**古い提出枠を `canceled: true` で取り消すと外れる。**（`PATCH /v1/reviewSubmissions/<id>`）
取り消したあと状態は `COMPLETE` になり、バージョンを新しい枠に足せるようになる。

## 旧：1.0 (1) の提出

**2026-08-30 22:56（JST）に審査へ提出した。** `WAITING_FOR_REVIEW`。

```
reviewSubmission: 397190ad-c52f-4a6f-8a31-6af1dd8b56f4
appStoreVersion:  9b6b0e24-0ba6-47b5-92c4-5cae5ab19afc
```

リリースは**手動**にしてあるので、審査が通っても勝手には公開されない。

### 結果が出るまで、ビルドを上げない

**審査中にビルドを差し替えると、審査がやり直しになる。**
直したものはコミットだけしておき、アップロードは結果が出てから。

いま 1.0 に含まれていないもの（次のバージョン行き）:

| 中身 | コミット |
|---|---|
| 投げ銭「開発者にコーヒーを奢る」 | `9e2dda7` |
| 不具合の報告・要望を送るボタン | `ec2f781` |
| 文字サイズ対応／リストの並べ替え／1つだけ足す | `a31bc48` |
| 配色20種・矢印で送る | `fd12f88` |

**投げ銭を出すときに要るもの**（引き継ぎ書 11節・4-8）:

- 有料App契約が「有効」になっていること（2026-08-29に手続き済み。銀行口座の処理待ちだった）
- App内課金「コーヒー1杯」（`com.zzzjjj080.Mochimono.coffee` / CONSUMABLE）は
  いま `MISSING_METADATA`。**この状態では審査に含まれない**ので、1.0 の審査には影響しない
- **掲載文・プライバシーポリシー・App Reviewのメモの整合を取り直す。**
  いまのメモには "no in-app purchases" と書いてある。雀算はこれで4か所の記述が嘘になった

**初回提出は Guideline 2.1（情報不足）で却下されると思っておく**（6節）。
却下されたら、まず**ビルドの中身を疑う**。指摘された箇所以外も実機で一通り触ること。
順番は「ビルド差し替え → 返信 → 再提出」。返信だけでは審査は再開しない。

## 提出前に本人がやったこと（Claude側では無理だったもの）

### 1. アプリのプライバシー →「データを収集しません」（完了）

**理由：`appDataUsages` は API に存在しない。**（`POST /v1/appDataUsages` → 404。
審査に出せない理由としては返ってくるのに、エンドポイントが無い。→ 4-51）

App Store Connect → Tilecheck → 左の「**アプリのプライバシー**」
→ データ収集の質問に「**いいえ、このAppからデータを収集しません**」

通信しないアプリなので、これで終わり。

### 2. GitHub Pages を有効にする（完了）

**理由：トークンが無いのでGitHubのAPIを叩けない。**
（repoスコープの Personal Access Token をもらえれば、以後はClaude側でできる）

https://github.com/zzzjjj080/mochimono/settings/pages
→ Source: **Deploy from a branch** → Branch: **main** → フォルダ: **`/docs`**

**既定は `/(root)` なので必ず変える**（→ 4-42）。反映に1〜3分。

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
