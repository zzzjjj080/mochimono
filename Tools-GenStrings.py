#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""画面の文言を String Catalog（Localizable.xcstrings）にする。

**キーは日本語**（コードの `Text("編集")` のまま）。訳は `translations/app.json` に集める。
`sourceLanguage` は `en` にそろえ、**ja の訳も明示的に入れる**（値はキーと同じ）。
これを外すと、日本語の端末で英語が混ざる（引き継ぎ書 4-157）。

書き出す前に検算する。1つでも引っかかったら書き出さない。

- 12言語すべてがあるか・空でないか
- `%@` `%lld` の数と種類が、キーと訳で同じか（位置指定 `%2$lld` は種類だけ見る）
- ビルドから取ったキーの一覧と、訳の一覧が一致するか（引数でビルドの置き場所を渡したとき）

    ./Tools-GenStrings.py                       # 書き出すだけ
    ./Tools-GenStrings.py /tmp/mochi-loc        # SWIFT_EMIT_LOC_STRINGS=YES のビルドと突き合わせる
"""
from __future__ import annotations
import glob, json, re, sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent
SRC = ROOT / "translations/app.json"
OUT = ROOT / "Mochimono/Mochimono/Localizable.xcstrings"
LANGS = ["ja", "en", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de", "it", "pt-BR", "ru", "ar"]
SPEC = re.compile(r"%(?:\d+\$)?(lld|ld|d|@|f)")


def specs(s: str) -> Counter:
    return Counter(SPEC.findall(s))


def built_keys(derived: str) -> set[str]:
    keys = set()
    for f in glob.glob(f"{derived}/Build/Intermediates.noindex/Mochimono.build/*/Mochimono.build/Objects-normal/*/*.stringsdata"):
        d = json.load(open(f, encoding="utf-8"))
        for e in d.get("tables", {}).get("Localizable", []):
            keys.add(e["key"])
    return keys


def main():
    src = json.loads(SRC.read_text(encoding="utf-8"))["strings"]
    errs = []
    table = {}
    for key, tr in src.items():
        vals = {"ja": key}
        if tr == "__SAME__":
            vals.update({l: key for l in LANGS[1:]})
        else:
            vals.update(tr)
        for l in LANGS:
            v = vals.get(l)
            if not v or not v.strip():
                errs.append(f"「{key}」: {l} が無い")
            elif specs(v) != specs(key):
                errs.append(f"「{key}」: {l} の差し込みが {dict(specs(v))}（キーは {dict(specs(key))}）")
        table[key] = vals

    if len(sys.argv) > 1:
        built = built_keys(sys.argv[1])
        if not built:
            errs.append(f"ビルドのキーが見つからない: {sys.argv[1]}")
        for k in sorted(built - set(table)):
            errs.append(f"訳が無いキー（ビルドにはある）: {k!r}")
        for k in sorted(set(table) - built):
            errs.append(f"使われていないキー（訳だけある）: {k!r}")

    if errs:
        print("書き出さなかった。直すところ:")
        for e in errs: print("  -", e)
        sys.exit(1)

    cat = {"sourceLanguage": "en", "version": "1.0", "strings": {}}
    for key in sorted(table):
        cat["strings"][key] = {"localizations": {
            l: {"stringUnit": {"state": "translated", "value": table[key][l]}} for l in LANGS}}
    OUT.write_text(json.dumps(cat, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"書き出した: {OUT.relative_to(ROOT)}  キー{len(table)} × 言語{len(LANGS)}")


if __name__ == "__main__":
    main()
