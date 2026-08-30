#!/bin/bash
# 接続中のiPhoneに最新のビルドを入れる。
# 機種変更しても書き換え不要なように、名前ではなく接続状態で選ぶ。
set -euo pipefail
cd "$(dirname "$0")/Mochimono"

# ペアリング済みのApple Watchも " connected " に一致するので iPhone に絞る。
# "connected (no DDI)" は中身を送れない状態なので除く（引き継ぎ書 4-26）。
# grep は空振りすると終了コード1。set -e で無言で死ぬので || true を付ける（4-19）。
LINE=$(xcrun devicectl list devices 2>/dev/null | grep '(iPhone' | grep ' connected ' | grep -v 'no DDI' | head -1 || true)
if [ -z "$LINE" ]; then
  echo "繋がっているiPhoneが見つかりません。USBで接続してください。"
  echo "（'available (paired)' は前にペアリングしただけで、今は使えません）"
  exit 1
fi
DEV=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
echo "対象: $DEV"

xcodebuild -project Mochimono.xcodeproj -scheme Mochimono -configuration Release \
  -destination "platform=iOS,id=$DEV" -destination-timeout 30 \
  -derivedDataPath /tmp/mochimono-dev -allowProvisioningUpdates build

APP=$(find /tmp/mochimono-dev/Build/Products -maxdepth 3 -name "Mochimono.app" -path "*Release*" | head -1)
xcrun devicectl device install app --device "$DEV" "$APP"
echo "入れ終わりました。ホーム画面から起動してください。"
echo "触覚は実機でしか確認できません。タップ・チェック・設定の切り替えを一通り触ってください。"
