#!/usr/bin/env python3
"""アカウント全体の審査状況を一覧する。

**審査に出す前に、これを叩く。**
同じアカウントから短期間に何本も出すと、4.3（スパム）の判断材料になる。
特に 4.3 で却下された直後は、結果が出るまで他のアプリを出さない。

    ./Tools-ReviewStatus.py
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from importlib import import_module

asc = import_module("Tools-ASC")
JST = timezone(timedelta(hours=9))

WAITING = {"WAITING_FOR_REVIEW", "IN_REVIEW"}
TROUBLE = {"UNRESOLVED_ISSUES", "REJECTED", "DEVELOPER_REJECTED",
           "METADATA_REJECTED", "INVALID_BINARY"}


def get(path: str):
    status, payload = asc.call("GET", path)
    return payload if 200 <= status < 300 else None


def jst(text: str | None):
    if not text:
        return None
    text = re.sub(r"\.(\d{1,6})\d*", lambda m: "." + m.group(1).ljust(6, "0"),
                  text.replace("Z", "+00:00"))
    return datetime.fromisoformat(text).astimezone(JST)


def main():
    apps = get("/v1/apps?limit=50&fields%5Bapps%5D=name,bundleId") or {}
    rows = []
    for app in apps.get("data", []):
        name = app["attributes"]["name"]
        subs = get(f"/v1/apps/{app['id']}/reviewSubmissions?limit=5") or {}
        latest = None
        for x in subs.get("data", []):
            t = jst(x["attributes"].get("submittedDate"))
            if latest is None or (t and latest[1] and t > latest[1]) or latest[1] is None:
                latest = (x["attributes"].get("state"), t)
        versions = get(f"/v1/apps/{app['id']}/appStoreVersions?limit=1") or {}
        vstate = ""
        if versions.get("data"):
            a = versions["data"][0]["attributes"]
            vstate = f'{a.get("versionString")} {a.get("appVersionState")}'
        rows.append((name, latest, vstate))

    waiting = [r for r in rows if r[1] and r[1][0] in WAITING]
    trouble = [r for r in rows if r[1] and r[1][0] in TROUBLE]

    print("=== アプリごとの状態 ===")
    for name, latest, vstate in sorted(rows, key=lambda r: r[0]):
        state = latest[0] if latest else "—"
        when = latest[1].strftime("%m/%d %H:%M") if latest and latest[1] else "—"
        mark = "  ← 審査待ち" if state in WAITING else ("  ← 要対応" if state in TROUBLE else "")
        print(f"  {name:24} {state:20} {when:12} {vstate}{mark}")

    print()
    print(f"審査待ち {len(waiting)}本 / 要対応 {len(trouble)}本")
    if len(waiting) >= 3:
        print("★ 同時に3本以上が審査待ち。**いま新しく出すのは見送る。**")
        print("  同じアカウントから短期間に何本も出すと、4.3（スパム）の判断材料になる。")
    if trouble:
        print("★ 却下されたままのものがある。**先にそれを片付ける。**")
        for name, latest, _ in trouble:
            print(f"    - {name}（{latest[0]}）")
    if not waiting and not trouble:
        print("いま出しても、ほかとぶつからない。")


if __name__ == "__main__":
    main()
