# App内課金の審査用スクリーンショット

`coffee-review.png`（1206×2622）… App Store Connect の課金製品に登録する1枚。

## 撮り方

**`xcrun simctl launch` では `.storekit` が効かない**（引き継ぎ書 11-9）。
スキームを経由する UI テストからしか、価格が出た状態を撮れない。

```bash
DEV=$(xcrun simctl create "Tilecheck-Shot" "iPhone 17 Pro")   # 他の作業と取り合わない専用機
xcrun simctl boot "$DEV"
cd Mochimono
xcodebuild -project Mochimono.xcodeproj -scheme Mochimono \
  -destination "platform=iOS Simulator,id=$DEV" \
  -derivedDataPath /tmp/mc-tip -resultBundlePath /tmp/tip.xcresult \
  -only-testing:MochimonoUITests/CoffeeTipUITests test
xcrun xcresulttool export attachments --path /tmp/tip.xcresult --output-path /tmp/tipshots
```

## 気をつけること

- **商品の読み込みは非同期。** 行が出た直後は無効なので、有効になるまで待ってから撮る。
  待たずに撮ると「商品が読めていない」ように見える1枚になる
- **シミュレータのストアフロントは米国**なので `$0.99` と出る。
  `.storekit` に `_storefront: "JPN"` を書いても変わらない（11-9）。
  実機・本番では App Store Connect の ¥200 が出る
