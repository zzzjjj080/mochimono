#!/usr/bin/env python3
"""課金（App内課金）の審査用スクリーンショットを App Store Connect へ入れる。

掲載用スクリーンショットと手順は同じだが、**endpoint も関係の名前も別物**。
`/v1/inAppPurchaseAppStoreReviewScreenshots` に `inAppPurchaseV2` で紐づける。
これを入れないと、課金は `MISSING_METADATA` のままバージョンに添えられない。

    ./Tools-UploadIAPScreenshot.py <inAppPurchase id> <画像>

例:
    ./Tools-UploadIAPScreenshot.py 6806882746 store/iap/coffee-review.png
"""
from __future__ import annotations

import hashlib
import json
import sys
import urllib.error
import urllib.request
from importlib import import_module
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
asc = import_module("Tools-ASC")


def api(method: str, path: str, body=None):
    status, payload = asc.call(method, path, json.dumps(body, ensure_ascii=False) if body else None)
    if not 200 <= status < 300:
        print(f"HTTP {status} {method} {path}")
        print(json.dumps(payload, ensure_ascii=False, indent=2)[:1200])
        sys.exit(1)
    return payload


def put_bytes(op: dict, chunk: bytes):
    req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
    for h in op.get("requestHeaders") or []:
        req.add_header(h["name"], h["value"])
    try:
        with urllib.request.urlopen(req) as res:
            return res.status
    except urllib.error.HTTPError as e:
        print("アップロード失敗:", e.code, e.read()[:400].decode(errors="replace"))
        sys.exit(1)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    iap_id, path = sys.argv[1], Path(sys.argv[2])
    data = path.read_bytes()

    # 既にあるものは先に消す。残したまま足すと、どちらが審査に出るか決まらない。
    current = api("GET", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot")
    if current.get("data"):
        old = current["data"]["id"]
        api("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{old}")
        print("古い画像を消した:", old)

    made = api("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {
        "data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
                 "attributes": {"fileSize": len(data), "fileName": path.name},
                 "relationships": {"inAppPurchaseV2": {
                     "data": {"type": "inAppPurchases", "id": iap_id}}}}})
    shot_id = made["data"]["id"]
    for op in made["data"]["attributes"]["uploadOperations"]:
        put_bytes(op, data[op["offset"]: op["offset"] + op["length"]])
    api("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{shot_id}", {
        "data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "id": shot_id,
                 "attributes": {"uploaded": True,
                                "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"入れた: {path.name}  {len(data) // 1024}KB  ({shot_id})")


if __name__ == "__main__":
    main()
