#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""1.2 が公開されたら、世界へ広げて 1.3 を出すまでを1本で通す。

    ./Tools-Release13.py --check    # 何も書き換えずに、いまの状態と次にやることだけ出す
    ./Tools-Release13.py            # 1.2 が READY_FOR_SALE なら、下の1〜8を順に進める

**途中で止まっても、もう一度流せば続きから進む**（済んだところは見て飛ばす）。

1. アプリの配信地域を全175へ（`territoryAvailabilities` を1件ずつ PATCH。引き継ぎ書 4-88b）
   1.2 の公開前に広げると、日本語だけの 1.1 が世界に出てしまうので、公開を待つ
2. ストアの主言語を en-US へ（公開中の版に英語の画像が要るので公開後。4-160）
3. 1.3 の枠を作る（`AFTER_APPROVAL`。承認されたら自動で公開）
4. 掲載文（`store/locales.json` の新機能・概要など。`Tools-PushListing.py`）
5. 日本語の概要に「手ぶらで読み上げ」の段を足す（`store/ja-readaloud-section.txt`）
6. 審査メモ（`store/review-notes.txt`）
7. ビルド 1.3 (5) を紐づける（`VALID` になっていること）
8. スクリーンショットが13言語×2サイズそろっているのを確かめて、提出する
"""
from __future__ import annotations
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).parent
APP = "6806789668"
PREV, VERSION, BUILD = "1.2", "1.3", "5"
CHECK = "--check" in sys.argv


def asc(method, path, body=None):
    cmd = [str(ROOT / "Tools-ASC.py"), method.lower(), path]
    if body is not None:
        cmd.append(json.dumps(body, ensure_ascii=False))
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    head, _, rest = out.partition("\n")
    try:
        data = json.loads(rest) if rest.strip() else {}
    except json.JSONDecodeError:
        data = {"raw": rest[:400]}
    status = int(head.split()[1]) if head.startswith("HTTP") else 0
    return status, data


def must(result, what):
    status, data = result
    if not 200 <= status < 300:
        sys.exit(f"失敗: {what} → HTTP {status}\n{json.dumps(data, ensure_ascii=False)[:800]}")
    return data


def all_pages(path):
    items, nxt = [], path
    while nxt:
        data = must(asc("get", nxt), nxt)
        items += data.get("data", [])
        link = data.get("links", {}).get("next")
        nxt = link.replace("https://api.appstoreconnect.apple.com", "") if link else None
    return items


def versions():
    return {v["attributes"]["versionString"]: v for v in
            must(asc("get", f"/v1/apps/{APP}/appStoreVersions?limit=10"), "versions")["data"]}


def step(n, text):
    print(f"{n}. {text}")


def main():
    vs = versions()
    prev = vs.get(PREV, {}).get("attributes", {}).get("appStoreState")
    print(f"{PREV}: {prev}")
    if prev != "READY_FOR_SALE":
        print(f"→ {PREV} がまだ公開されていないので、何もしない")
        sys.exit(2)

    # 1. 配信地域
    rel = must(asc("get", f"/v1/apps/{APP}/appAvailabilityV2"), "appAvailability")
    tlink = rel["data"]["relationships"]["territoryAvailabilities"]["links"]["related"]
    tas = all_pages(tlink.replace("https://api.appstoreconnect.apple.com", "") + "?limit=200")
    closed = [t for t in tas if not t["attributes"].get("available")]
    step(1, f"配信地域 {len(tas) - len(closed)}/{len(tas)}")
    if closed and not CHECK:
        for i, t in enumerate(closed, 1):
            must(asc("patch", f"/v1/territoryAvailabilities/{t['id']}",
                     {"data": {"type": "territoryAvailabilities", "id": t["id"],
                               "attributes": {"available": True}}}), f"地域 {t['id']}")
            if i % 25 == 0:
                print(f"   {i}/{len(closed)}")
        print(f"   → {len(tas)} 地域すべてで配信")

    # 2. 主言語
    app = must(asc("get", f"/v1/apps/{APP}"), "app")["data"]["attributes"]
    step(2, f"主言語 {app.get('primaryLocale')}")
    if app.get("primaryLocale") != "en-US" and not CHECK:
        must(asc("patch", f"/v1/apps/{APP}",
                 {"data": {"type": "apps", "id": APP, "attributes": {"primaryLocale": "en-US"}}}), "primaryLocale")
        print("   → en-US")

    # 3. 1.3 の枠
    ver = vs.get(VERSION)
    step(3, f"{VERSION} の枠 {ver['attributes']['appStoreState'] if ver else 'なし'}")
    if ver and ver["attributes"]["appStoreState"] not in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"):
        print(f"   → {VERSION} はもう提出済み")
        return
    if not ver:
        if CHECK:
            return
        ver = must(asc("post", "/v1/appStoreVersions", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": VERSION, "releaseType": "AFTER_APPROVAL"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}}), "版の枠")["data"]
        print(f"   → 作った {ver['id']}")
    vid = ver["id"]

    # 4. 掲載文
    step(4, "掲載文（13言語）")
    if not CHECK:
        r = subprocess.run([str(ROOT / "Tools-PushListing.py"), vid], capture_output=True, text=True)
        print("   " + (r.stdout.strip().splitlines() or ["(出力なし)"])[-1])
        if r.returncode != 0:
            sys.exit(r.stdout + r.stderr)

    # 5. 日本語の概要に読み上げの段
    locs = {l["attributes"]["locale"]: l for l in
            must(asc("get", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=50"), "locs")["data"]}
    ja = locs.get("ja")
    section = (ROOT / "store/ja-readaloud-section.txt").read_text(encoding="utf-8").strip() + "\n"
    desc = ja["attributes"].get("description") or "" if ja else ""
    has = section.splitlines()[0] in desc
    step(5, f"日本語の概要に読み上げの段 {'あり' if has else 'なし'}")
    if ja and not has and not CHECK:
        heads = [i for i in range(len(desc)) if desc.startswith("\n■ ", i)]
        at = heads[-2] + 1 if len(heads) >= 2 else len(desc)
        new = desc[:at] + section + "\n" + desc[at:]
        must(asc("patch", f"/v1/appStoreVersionLocalizations/{ja['id']}",
                 {"data": {"type": "appStoreVersionLocalizations", "id": ja["id"],
                           "attributes": {"description": new}}}), "日本語の概要")
        print("   → 足した")

    # 6. 審査メモ
    notes = (ROOT / "store/review-notes.txt").read_text(encoding="utf-8")
    st, rd = asc("get", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
    step(6, "審査メモ")
    if not CHECK:
        if st == 200 and rd.get("data"):
            rid = rd["data"]["id"]
            must(asc("patch", f"/v1/appStoreReviewDetails/{rid}",
                     {"data": {"type": "appStoreReviewDetails", "id": rid, "attributes": {"notes": notes}}}), "審査メモ")
        else:
            must(asc("post", "/v1/appStoreReviewDetails", {"data": {
                "type": "appStoreReviewDetails", "attributes": {"notes": notes},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}}), "審査メモ")
        print("   → 入れた")

    # 7. ビルド
    builds = must(asc("get", f"/v1/builds?filter[app]={APP}&filter[version]={BUILD}"
                             f"&filter[preReleaseVersion.version]={VERSION}&limit=5"), "builds")["data"]
    b = builds[0] if builds else None
    step(7, f"ビルド {VERSION} ({BUILD}) {b['attributes']['processingState'] if b else 'まだ届いていない'}")
    if not b or b["attributes"]["processingState"] != "VALID":
        sys.exit("   → ビルドが VALID になってから流し直す")
    if not CHECK:
        must(asc("patch", f"/v1/appStoreVersions/{vid}/relationships/build",
                 {"data": {"type": "builds", "id": b["id"]}}), "ビルドの紐づけ")
        print("   → 紐づけた")

    # 8. スクリーンショットを確かめて提出
    short = []
    for loc, l in sorted(locs.items()):
        sets = must(asc("get", f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets?include=appScreenshots"),
                    f"画像 {loc}")
        kinds = {s["attributes"]["screenshotDisplayType"]: len(s["relationships"]["appScreenshots"]["data"])
                 for s in sets["data"]}
        if kinds.get("APP_IPHONE_67", 0) == 0 or kinds.get("APP_IPHONE_65", 0) == 0:
            short.append(f"{loc} {kinds}")
    step(8, f"スクリーンショット {len(locs) - len(short)}/{len(locs)} 言語そろい")
    if short:
        sys.exit("   足りない: " + ", ".join(short))
    if CHECK:
        return
    sub = must(asc("post", "/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}}), "提出の箱")["data"]
    must(asc("post", "/v1/reviewSubmissionItems", {"data": {
        "type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}}), "提出の中身")
    must(asc("patch", f"/v1/reviewSubmissions/{sub['id']}",
             {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}}), "提出")
    print(f"   → 提出した reviewSubmission {sub['id']}")


if __name__ == "__main__":
    main()
