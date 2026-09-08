# Tilecheck リリース手順

**方針：APIで到達できることは全部Claude側でやる。**
本人に頼むのは、人間でなければ物理的に無理なものだけ。
（`~/.claude/CLAUDE.md`「作業の分担」／`~/.claude/iOS-DEVLOG.md` 5-0、4-49〜4-51）

App ID `6806789668` / バンドルID `com.zzzjjj080.Mochimono` / **いま `1.0 (2)` 審査中、次は `(3)`**

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

## 1.1 の準備（2026-09-09・審査待ちの間にできることは全部やった）

**審査中は ASC 側でバージョンの枠すら作れない。** 実際に叩いて確定させた。

```
POST /v1/appStoreVersions  versionString=1.1
→ 409 ENTITY_ERROR.RELATIONSHIP.INVALID
  "You cannot create a new version of the App in the current state."
```

だから 1.1 は「**中身は完成、ASC 側は結果待ち**」で止めてある。

### 済ませたこと

- [x] 投げ銭を戻した（`AppFeature.showsTipJar = true`）
- [x] **App内課金を `READY_TO_SUBMIT` にした。** 足りなかったのは審査用スクリーンショット1枚だけ。
      `./Tools-UploadIAPScreenshot.py 6806882746 store/iap/coffee-review.png`
- [x] 残りだけ表示／リストの複製／前回そろった日
- [x] `CURRENT_PROJECT_VERSION = 3`（`MARKETING_VERSION` は 1.0 のまま。理由は下）
- [x] 掲載文・審査メモ・リリースノートを課金ありに書き直した
      （`store/description.txt` / `store/review-notes.txt` / `store/whats-new.txt`）
- [x] Core 76本・UI 23本のテストが通る。実機 iPhone Air に投入済み

### `MARKETING_VERSION` を 1.0 のままにしてある理由

**1.0 の結果で行き先が変わる。** どちらでもビルド番号は 3 で合っている。

| 1.0 (2) の結果 | やること |
|---|---|
| 承認 | `MARKETING_VERSION` を 1.1 にして、下の手順で 1.1 として出す |
| 4.3 で再却下 | 1.0 のまま build 3 を上げる。**足した機能が 4.3 への答えそのものになる**（複製・残りだけ・前回の記録は他に無い） |

### 承認されたら叩く順番

```bash
# 1. 版数を上げる
sed -i '' 's/MARKETING_VERSION = 1.0;/MARKETING_VERSION = 1.1;/g' Mochimono/Mochimono.xcodeproj/project.pbxproj

# 2. アーカイブ → アップロード（5節の手順）。ビルドが VALID になるまで待つ
# 3. バージョンの枠を作る
./Tools-ASC.py post /v1/appStoreVersions '{"data":{"type":"appStoreVersions","attributes":{"platform":"IOS","versionString":"1.1","releaseType":"MANUAL","copyright":"2026 Jin Nakamura"},"relationships":{"app":{"data":{"type":"apps","id":"6806789668"}}}}}'

# 4. ja のローカライズに whatsNew / description を入れる（PATCH appStoreVersionLocalizations）
# 5. 審査メモを入れる（appStoreReviewDetails）
# 6. スクリーンショットが引き継がれているか確認。無ければ Tools-UploadScreenshots.py で入れ直す
# 7. ビルドを紐づける（→ 4-40。紐づけ忘れが一番多い）
# 8. reviewSubmission を作り、**バージョンと課金の2つ**をアイテムに足して submit
```

**課金はバージョンとは別のアイテムとして足す。** `APP_STORE_VERSION` だけ足すと、
課金は審査に含まれないまま公開され、アプリ側に出ている購入行が動かない。

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
./Tools-UploadIAPScreenshot.py 6806882746 store/iap/coffee-review.png   # 課金の審査用画像
./Tools-ReviewStatus.py                            # 出す前にアカウント全体を見る
./install-device.sh                                # 接続中のiPhoneに入れる
swiftc -O Tools-MakeIcon.swift -o /tmp/makeicon && /tmp/makeicon <出力先>
swiftc -O store/MakeScreenshots.swift -o /tmp/makeshots
/tmp/makeshots store/raw store/screenshots         # 6.9インチ
/tmp/makeshots store/raw store/screenshots-65 1242 2688
xcrun simctl launch booted com.zzzjjj080.Mochimono -screenshot-demo
```
