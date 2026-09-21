#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""多言語の掲載情報を App Store Connect へ流し込む。元は `store/locales.json`。

    ./Tools-PushListing.py <appStoreVersion id>             # 1 と 3
    ./Tools-PushListing.py <appStoreVersion id> --primary   # 2（英語のスクリーンショットを入れたあと）

やること（前例：引き継ぎ書 4-158）

1. 編集できる appInfo に、言語ごとの名前・サブタイトル・プライバシーポリシーURLを入れる
   **新しい言語には privacyPolicyUrl が入っていない。**入れないと提出が
   `STATE_ERROR.ENTITY_STATE_INVALID` で弾かれる
2. アプリの主言語を en-US にする（訳の無い国のストアページが日本語で出ないように。4-157）
   **その言語のスクリーンショットが先に要る。**無いと 409
   `MISSING_SCREENSHOTS_PRIMARY_LOCALE`。だから別の呼び出しに分けてある
3. 版のローカライズに 概要・キーワード・プロモーション・新機能・サポートURL を入れる
   **appInfo の言語を作ると版の言語は自動で生える**ので、POST ではなく PATCH。無ければ POST

日本語は新機能だけを差し替える（概要などは 1.1 のものがそのまま引き継がれている）。
"""
from __future__ import annotations
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).parent
APP = "6806789668"
NAME = "Tilecheck"
BASE = "https://zzzjjj080.github.io/mochimono/"


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
    ok = head.startswith("HTTP 2")
    return ok, head, data


def must(result, what):
    ok, head, data = result
    if not ok:
        print(f"失敗: {what} {head}\n{json.dumps(data, ensure_ascii=False)[:800]}")
        sys.exit(1)
    return data


def urls(locale):
    root = BASE if locale == "ja" else BASE + "en/"
    return root, root + "privacy.html"


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    ver = sys.argv[1]
    if sys.argv[2:] == ["--primary"]:
        must(asc("patch", f"/v1/apps/{APP}",
                 {"data": {"type": "apps", "id": APP, "attributes": {"primaryLocale": "en-US"}}}), "primaryLocale")
        print("主言語 → en-US")
        return
    M = json.loads((ROOT / "store/locales.json").read_text(encoding="utf-8"))

    # 1. appInfo（公開中のものは触れない。版を作ると編集できるものが1件増える。4-88）
    infos = must(asc("get", f"/v1/apps/{APP}/appInfos"), "appInfos")["data"]
    editable = [i for i in infos if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) != "READY_FOR_SALE"]
    if not editable:
        sys.exit("編集できる appInfo が無い（版を先に作る）")
    info = editable[0]["id"]
    have = {l["attributes"]["locale"]: l for l in
            must(asc("get", f"/v1/appInfos/{info}/appInfoLocalizations?limit=50"), "appInfoLocalizations")["data"]}
    for loc, m in M.items():
        support, privacy = urls(loc)
        attrs = {"name": NAME, "privacyPolicyUrl": privacy}
        if "subtitle" in m:
            attrs["subtitle"] = m["subtitle"]
        if loc in have:
            lid = have[loc]["id"]
            must(asc("patch", f"/v1/appInfoLocalizations/{lid}",
                     {"data": {"type": "appInfoLocalizations", "id": lid, "attributes": attrs}}), f"appInfo {loc}")
            print(f"  名前・サブタイトル（更新） {loc}")
        else:
            must(asc("post", "/v1/appInfoLocalizations",
                     {"data": {"type": "appInfoLocalizations", "attributes": dict(attrs, locale=loc),
                               "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info}}}}}),
                 f"appInfo {loc}")
            print(f"  名前・サブタイトル（新規） {loc}")

    # 3. 版のローカライズ
    vl = {l["attributes"]["locale"]: l for l in
          must(asc("get", f"/v1/appStoreVersions/{ver}/appStoreVersionLocalizations?limit=50"), "versionLocalizations")["data"]}
    for loc, m in M.items():
        support, _ = urls(loc)
        attrs = {"whatsNew": m["whatsNew"]}
        if loc != "ja":
            attrs.update(description=m["description"], keywords=m["keywords"],
                         promotionalText=m["promo"], supportUrl=support, marketingUrl=support)
        if loc in vl:
            lid = vl[loc]["id"]
            must(asc("patch", f"/v1/appStoreVersionLocalizations/{lid}",
                     {"data": {"type": "appStoreVersionLocalizations", "id": lid, "attributes": attrs}}), f"版 {loc}")
            print(f"  掲載文（更新） {loc}")
        else:
            must(asc("post", "/v1/appStoreVersionLocalizations",
                     {"data": {"type": "appStoreVersionLocalizations", "attributes": dict(attrs, locale=loc),
                               "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver}}}}}),
                 f"版 {loc}")
            print(f"  掲載文（新規） {loc}")
    print("完了")


if __name__ == "__main__":
    main()
