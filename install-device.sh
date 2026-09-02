#!/bin/bash
# 接続中のiPhoneに最新のビルドを入れる。
# 機種変更しても書き換え不要なように、名前ではなく接続状態で選ぶ。
set -euo pipefail
cd "$(dirname "$0")/Mochimono"

list() { xcrun devicectl list devices 2>/dev/null | grep '(iPhone' | grep -v 'no DDI'; }
uuid_of() { grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' <<<"$1"; }

# grep は空振りすると終了コード1。set -e で無言で死ぬので || true を付ける（引き継ぎ書 4-19）
# ペアリング済みのApple Watchも " connected " に一致するので iPhone に絞る（4-26）
LINE=$(list | grep ' connected ' | head -1 || true)
OVER_NETWORK=0
if [ -z "$LINE" ]; then
  # **`available (paired)` でも devicectl なら入ることがある。**
  # `xcodebuild -destination` には渡せないが、ビルドを generic/platform=iOS で作れば
  # インストールだけはネットワーク越しに通る（4-20の補足）
  LINE=$(list | grep 'available (paired)' | head -1 || true)
  OVER_NETWORK=1
fi
if [ -z "$LINE" ]; then
  echo "iPhoneが見つかりません。USBで接続するか、Macと同じネットワークに繋いでください。"
  xcrun devicectl list devices 2>/dev/null | grep '(iPhone' || true
  exit 1
fi

DEV=$(uuid_of "$LINE")
if [ "$OVER_NETWORK" = "1" ]; then
  echo "対象: $DEV（USB直結ではないので、ネットワーク越しに入れます）"
else
  echo "対象: $DEV"
fi

# リリース構成で入れる。デバッグ構成は最適化が効かない（4-27）
# 端末を -destination に渡さず generic で作る。available の端末を渡すと
# 「developer disk image がマウントできない」で10分待たされる（4-20）
xcodebuild -project Mochimono.xcodeproj -scheme Mochimono -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/mochimono-dev \
  -allowProvisioningUpdates build

APP=$(find /tmp/mochimono-dev/Build/Products -maxdepth 3 -name "Mochimono.app" -path "*Release-iphoneos*" | head -1)
xcrun devicectl device install app --device "$DEV" "$APP"
echo "入れ終わりました。ホーム画面の Tilecheck から起動してください。"
echo "触覚は実機でしか確認できません。タップ・チェック・配色の矢印を触ってください。"
