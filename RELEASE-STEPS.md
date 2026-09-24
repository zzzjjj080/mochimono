# Tilecheck リリース手順

**方針：APIで到達できることは全部Claude側でやる。**
本人に頼むのは、人間でなければ物理的に無理なものだけ。
（`~/.claude/CLAUDE.md`「作業の分担」／`~/.claude/iOS-DEVLOG.md` 5-0、4-49〜4-51）

App ID `6806789668` / バンドルID `com.zzzjjj080.Mochimono` / **1.2（12言語）公開済み・175地域・主言語 en-US。いま `1.3 (6)`（読み上げ）を提出中**

## 済んでいること（すべてClaude側）

- [x] Explicit App ID の登録（`2K77Y5M6HH`）
- [x] ビルドのアップロード → **`1.0 (1)` は `VALID`。バージョンに紐づけ済み**
- [x] 暗号化の申告（`Info.plist` の `ITSAppUsesNonExemptEncryption = NO` で自動的に済む）
- [x] サブタイトル／プライバシーポリシーURL
- [x] 概要／キーワード／プロモーション文／サポートURL／マーケティングURL
- [x] 著作権 `2026 Jin Nakamura`、リリース方法は **`AFTER_APPROVAL`（自動）**
      （2026-09-09 に手動から直した。引き継ぎ書5節の恒久ルール。承認から公開までの一手間を残さない）
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

## 1.2：12言語で世界へ（2026-09-21）

```
appStoreVersion: 42bea15b-de97-456c-a7ce-ab3844d5ed17   （1.2・AFTER_APPROVAL）
課金の版2:        233b6871-1dce-4521-9704-9b0ec7bb1ea2   （言語を足したら生えた。一緒に審査へ）
build:            7bb2fc1e-e065-4c21-80a4-d7db376defb4   （1.2 (4)・VALID）
reviewSubmission: 4d648d4e-268e-4b8e-9c71-1170632d1a18   （1.2 + 課金の版2）
```

**2026-09-21 に提出した。** 1.2 と課金の版2が `WAITING_FOR_REVIEW`。13ロケールすべてに画像5枚×2サイズ。

- 訳の元：画面 `translations/app.json` → `./Tools-GenStrings.py`、雛形 `translations/core.json` → `./Tools-GenCore.py`
- 掲載の元：`store/locales.json`（13ロケール。es は ES と MX）→ `./Tools-PushListing.py <版>`
- 画像：日本語は `store/screenshots*`、それ以外は英語の `store/screenshots-en*`
  （撮影は `TEST_RUNNER_SHOT_LANG=en … -only-testing:MochimonoUITests/StoreShotUITests`、
  組むのは `SHOT_LANG=en /tmp/makeshots store/raw-en store/screenshots-en`）
- サポートとプライバシーの英語版：`docs/en/`（非日本語のロケールはこちらを指す）
- 課金の販売地域：日本だけ → **175地域に広げ済み**（`POST /v1/inAppPurchaseAvailabilities` で置き換わる）

### 公開されたらやること（今はまだできない）

1. **アプリの配信地域を175へ。** 今は日本だけ。先に広げると、公開中の日本語だけの版が世界に出る（4-88b）。
   `appAvailabilities` は UPDATE 不可なので、`territoryAvailabilities` を1件ずつ `PATCH {"available": true}`
2. **主言語を en-US へ。** `./Tools-PushListing.py 42bea15b-de97-456c-a7ce-ab3844d5ed17 --primary`
   公開中の版にも英語の画像が要るので、1.2 が公開されてから（4-160。今は 409）

## 1.0 は 2026-09-17 に公開された

4.3(a) で却下 → テキスト⇄盤面を双方向にして再提出 → **承認・自動公開**（`READY_FOR_SALE`）。
提出から結果まで**12日**かかった（通常は1〜2日）。スパム指摘のあとの再審査は長い、と見ておく。

## 1.3 を提出した（2026-09-24 00:49 UTC）

`./Tools-Release13.py` 1本で、配信地域175・主言語 en-US・枠・掲載文・審査メモ・ビルド紐づけ・提出まで通った。

```
appStoreVersion: 6783b9dc-2b58-459c-a15e-c229b55fe01c   （1.3・AFTER_APPROVAL）
reviewSubmission: aea286b5-c39b-49e6-9656-05bf23ce6f40
build:            1.3 (6)（印 b43 09/22 16:34）
```

課金は 1.2 と一緒に多言語版が承認済みなので、1.3 には足していない。

## 1.3 の出し方（2026-09-22 準備済み）

**1.2 の公開を待ってから `./Tools-Release13.py`（先に `--check` で様子を見る）。** 1本で次を進め、途中で止まっても流し直せば続きから。

1. 配信地域を175へ（1.2 の前に広げると日本語だけの 1.1 が世界に出る）
2. 主言語を en-US へ（公開中の版に英語の画像が要る）
3. 1.3 の枠（`AFTER_APPROVAL`）→ 4. 掲載文（`store/locales.json` の新機能と説明文の読み上げの段）
5. 日本語の概要に `store/ja-readaloud-section.txt` を差し込む → 6. 審査メモ
7. ビルド 1.3 (6) を紐づけ → 8. 13言語×2サイズの画像を確かめて提出

課金は 1.2 と一緒に多言語版を審査に出したので、1.3 では足さない。
1.3 (5)（16:04）は読み上げの止まり方と大きな文字の直しの前だったので、**1.3 (6)（印 `b43 09/22 16:34`）を上げ直した。紐づけるのは 6。**

## 1.1 の提出（2026-09-17）

```
appStoreVersion: 2822df6e-39c3-44fd-808c-aa8fa105d543   （1.1・AFTER_APPROVAL）
ローカライズ(ja): c467dd26-1857-4627-88f1-4658eb0cc99d
スクショのセット:  APP_IPHONE_67 a503b152-…  /  APP_IPHONE_65 d82fc6f6-…
課金:             6806882746（コーヒー1杯・READY_TO_SUBMIT）
```

叩いた順番。**枠を作る前にビルドを上げてもよい**が、紐づけは枠ができてから。

1. `MARKETING_VERSION` を 1.1 に（ビルド番号は 3 のまま）
2. アーカイブ → 出す前の確認（版・`.storekit` 0件・`screenshot-demo` 0件・暗号化の申告）→ `-exportArchive` で `destination: upload`
3. `POST /v1/appStoreVersions`（`releaseType: AFTER_APPROVAL`）
4. ローカライズに 概要・キーワード・プロモーション・**新機能**（`store/whats-new.txt`）を `PATCH`
5. `appStoreReviewDetail` に審査メモを `PATCH`（**枠と一緒に作られている**ので POST は要らなかった）
6. スクリーンショットを 6.9 と 6.5 の両方に入れ直す（`Tools-UploadScreenshots.py`）
7. ビルドが `VALID` になるのを待って、バージョンに紐づける
8. `reviewSubmission` を作り、**バージョンと課金の2つ**をアイテムに足して提出

**課金のリレーション名は `inAppPurchaseVersion`。**（引き継ぎ書 11-8b）
`inAppPurchaseV2` で足すと 409 `unknown relationship` になる（今回も1回踏んだ）。
渡すのは課金のidではなく、**その「バージョン」のid**。

```bash
./Tools-ASC.py get /v2/inAppPurchases/6806882746/versions   # → inAppPurchaseVersions の id
```

```
reviewSubmission: 88f83b8a-87d5-4906-a0b7-33da0bdecc2f   （1.1 + 課金）
build:            eb86226a-2c54-4217-bcdd-4a4ea39785f9   （1.1 (3)・VALID）
課金のバージョン:   e137ff62-4674-4f6e-8d27-b7ff162dc04b
```

**2026-09-17 08:09（JST）に提出した。** 1.1 と課金がどちらも `WAITING_FOR_REVIEW`。
リリース方法は自動なので、承認されればそのまま公開される。

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
- [x] リストの複製／前回そろった日
- [x] **そろった知らせを押して外せるようにした**（確認なし）。知らせは盤面の上に固定の高さで置き、**そろっても盤面がずれない**。配色の操作は盤面の下へ移し、「残りだけ」と「元に戻す」は外した（2026-09-16 本人の依頼）
- [x] **配色を12→10種類に減らし、カラーモード（オンで色分け／オフで全部1色）を足した**（2026-09-13 本人の依頼）。
      切り替えは配色の矢印の隣の「カラー」。リストごとに保存。既定はオン
- [x] **掲載用スクリーンショットを撮り直した**（盤面の上の段が変わったため。`store/screenshots{,-65}`）。
      **1.1 の枠を作ったら、6.5・6.9インチとも入れ直すこと。** 1.0 の画像は「1 / 12」のまま
- [x] サポートページ（`docs/index.html`）の「配色は8種類・設定から選ぶ」という古い説明を直した
- [x] `CURRENT_PROJECT_VERSION = 3`（`MARKETING_VERSION` は 1.0 のまま。理由は下）
- [x] 掲載文・審査メモ・リリースノートを課金ありに書き直した
      （`store/description.txt` / `store/review-notes.txt` / `store/whats-new.txt`）
- [x] Core 86本・UI 25本のテストが通る。実機 iPhone Air に投入済み（2026-09-13）

### `MARKETING_VERSION` を 1.0 のままにしてある理由

**1.0 の結果で行き先が変わる。** どちらでもビルド番号は 3 で合っている。

| 1.0 (2) の結果 | やること |
|---|---|
| 承認 | `MARKETING_VERSION` を 1.1 にして、下の手順で 1.1 として出す |
| 4.3 で再却下 | 1.0 のまま build 3 を上げる。**足した機能が 4.3 への答えそのものになる**（複製・前回の記録・カラーモードは他に無い） |

### 承認されたら叩く順番

```bash
# 1. 版数を上げる
sed -i '' 's/MARKETING_VERSION = 1.0;/MARKETING_VERSION = 1.1;/g' Mochimono/Mochimono.xcodeproj/project.pbxproj

# 2. アーカイブ → アップロード（5節の手順）。ビルドが VALID になるまで待つ
# 3. バージョンの枠を作る
./Tools-ASC.py post /v1/appStoreVersions '{"data":{"type":"appStoreVersions","attributes":{"platform":"IOS","versionString":"1.1","releaseType":"AFTER_APPROVAL","copyright":"2026 Jin Nakamura"},"relationships":{"app":{"data":{"type":"apps","id":"6806789668"}}}}}'

# 4. ja のローカライズに whatsNew / description を入れる（PATCH appStoreVersionLocalizations）
# 5. 審査メモを入れる（appStoreReviewDetails）
# 6. スクリーンショットは必ず入れ直す（1.0 のものは古い）。Tools-UploadScreenshots.py で 6.5 と 6.9 の両方
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

リリースは当初**手動**だったが、2026-09-09 に `AFTER_APPROVAL` へ直した。
**承認されたらそのまま公開される。**（審査待ちの間でも `PATCH` で変えられる）

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
