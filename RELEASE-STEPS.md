# モチモノ リリース手順

**方針：APIで到達できることは全部Claude側でやる。**
本人に頼むのは、人間でなければ物理的に無理なものだけ。
（`~/.claude/CLAUDE.md`「作業の分担」／`~/.claude/iOS-DEVLOG.md` 5-0）

## 済んでいること（Claude側）

- [x] アプリ名の重複確認（iTunes Search API。「モチモノ」は空き。
      「モチモノート」「もちもの」は別物）
- [x] **Explicit App ID の登録** `com.zzzjjj080.Mochimono` → id `2K77Y5M6HH`
      （`POST /v1/bundleIds` が 201。`Tools-ASC.py` で実行）
- [x] アーカイブ（`1.0 (1)` / iOS 18.0以降 / 縦向き / 暗号化なし）
- [x] リリース構成に確認用の抜け道が残っていないことを実物で確認
      （`screenshot-demo` `ui-testing` `mochimono.demo` すべて0件）
- [x] スクリーンショット 5枚 × 2寸法（1320x2868 / 1242x2688）→ `store/screenshots*`
- [x] 掲載文（`store/` にプレーンテキストで。**そのまま貼れる形**）
- [x] サポートページ・プライバシーポリシー → `docs/`
- [x] App Review へのメモ（英語・`store/review-notes.txt`）

## 本人しかできないこと

### 1. App Store Connect でアプリを新規登録

**理由：APIに CREATE が無い。**（`POST /v1/apps` → 403
`The resource 'apps' does not allow 'CREATE'`。実際に叩いて確認した）

https://appstoreconnect.apple.com → マイApp → ＋ → 新規App

| 欄 | 入れる値 |
|---|---|
| プラットフォーム | iOS |
| 名前 | モチモノ |
| プライマリ言語 | 日本語 |
| バンドルID | `com.zzzjjj080.Mochimono`（登録済みなので候補に出る） |
| SKU | `mochimono` |
| ユーザーアクセス | フルアクセス |

候補にバンドルIDが出ないときは**ページをリロード**する。

### 2. GitHub にリポジトリを作る

**理由：トークンが無いのでAPIを叩けない。**
`git push` は SSH鍵で通るので、**箱さえ作ってもらえれば中身は Claude が入れる。**

https://github.com/new → 名前 `mochimono` → Public → 空のまま作成

**Personal Access Token（repoスコープ）をもらえれば、以後この作業も Claude 側でできる。**

## そのあと（全部 Claude 側）

1. `git remote add` → push → GitHub Pages を `/docs` で公開 → URL の疎通を curl で確認
2. ビルドのアップロード（APIキー経由。`destination = upload`）
3. 掲載情報の登録（`PATCH /v1/appStoreVersionLocalizations`）
4. スクリーンショットの登録
5. 価格（無料）・配信地域（日本のみ）・年齢制限・プライバシー（データを収集しません）
6. 審査提出（`POST /v1/reviewSubmissions`）

## 使う道具

```bash
./Tools-ASC.py get /v1/apps                    # App Store Connect API
./Tools-ASC.py post /v1/bundleIds '{...}'
./install-device.sh                            # 接続中のiPhoneに入れる
swiftc -O Tools-MakeIcon.swift -o /tmp/makeicon && /tmp/makeicon <出力先>
swiftc -O store/MakeScreenshots.swift -o /tmp/makeshots
/tmp/makeshots store/raw store/screenshots     # 6.9インチ
/tmp/makeshots store/raw store/screenshots-65 1242 2688
```

スクリーンショットの素材は、`-screenshot-demo` を付けて起動すると
決まった状態で撮れる（`AppModel` の `#if DEBUG`）。

```bash
xcrun simctl launch booted com.zzzjjj080.Mochimono -screenshot-demo
```
