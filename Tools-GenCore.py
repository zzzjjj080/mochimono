#!/usr/bin/env python3
"""Core の訳（雛形と、Core が持つ文言）を Swift の表にする。

**訳はコードに直書きしない。** `translations/core.json` に集め、ここから生成する（引き継ぎ書 4-158）。
生成物 `Core.generated.swift` はコミットする。ビルド時には作らない。

書き出す前に検算する。1つでも引っかかったら書き出さない。

- 12言語すべてが、12個の雛形すべてを持っているか
- **グループの数と、グループごとの項目数が日本語と同じか**
  （見本の画面で「何番目を持った状態にするか」を言語をまたいで同じにするため）
- 項目名の長さ（中日韓は8文字まで、それ以外は20文字まで。4列で読めるように）
- 1つの雛形の中に同じ名前の項目が無いか
- 言語の中で雛形の名前が重なっていないか
- 文言の `%@` `%lld` の数と種類が、どの言語でも同じか（食い違うと実行時に落ちる）

    ./Tools-GenCore.py
"""
from __future__ import annotations
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).parent
SRC = ROOT / "translations/core.json"
OUT = ROOT / "MochimonoCore/Sources/MochimonoCore/Core.generated.swift"

CASE = {"ja": "ja", "en": "en", "zh-Hans": "zhHans", "zh-Hant": "zhHant", "ko": "ko",
        "es": "es", "fr": "fr", "de": "de", "it": "it", "pt-BR": "ptBR", "ru": "ru", "ar": "ar"}
CJK = {"ja", "zh-Hans", "zh-Hant", "ko"}
COLUMNS = {2: ".two", 3: ".three", 4: ".four", 5: ".five"}


def lit(s: str) -> str:
    """Swift の文字列リテラル。JSON の書き方は Swift とほぼ同じだが、\\u は通らないので使わせない。"""
    out = json.dumps(s, ensure_ascii=False)
    assert "\\u" not in out, f"Swift で通らない書き方が混ざる: {s!r}"
    return out


def check(d: dict) -> list[str]:
    errs = []
    langs = d["languages"]
    if set(langs) != set(CASE):
        errs.append(f"言語の並びが Language と合わない: {langs}")
    for key, byLang in d["strings"].items():
        want = sorted(re.findall(r"%(?:lld|@|d)", byLang["en"]))
        for lang in langs:
            v = byLang.get(lang)
            if not v:
                errs.append(f"文言 {key}: {lang} が無い"); continue
            got = sorted(re.findall(r"%(?:lld|@|d)", v))
            if got != want:
                errs.append(f"文言 {key}: {lang} の差し込みが {got}（英語は {want}）")
    for lang in langs:
        names = [p["languages"][lang]["name"] for p in d["presets"] if lang in p["languages"]]
        if len(set(names)) != len(names):
            errs.append(f"{lang}: 雛形の名前が重なっている {names}")
    for p in d["presets"]:
        shape = [len(g) for g in p["languages"]["ja"]["groups"]]
        for lang in langs:
            L = p["languages"].get(lang)
            if not L:
                errs.append(f"{p['id']}: {lang} が無い"); continue
            got = [len(g) for g in L["groups"]]
            if got != shape:
                errs.append(f"{p['id']}/{lang}: 形が {got}（日本語は {shape}）")
            limit = 8 if lang in CJK else 20
            items = [i for g in L["groups"] for i in g]
            for i in items:
                if not i.strip():
                    errs.append(f"{p['id']}/{lang}: 空の項目")
                if len(i) > limit:
                    errs.append(f"{p['id']}/{lang}: 「{i}」が {len(i)} 文字（上限 {limit}）")
            if len(set(items)) != len(items):
                errs.append(f"{p['id']}/{lang}: 同じ名前の項目がある")
    return errs


def main():
    d = json.loads(SRC.read_text())
    errs = check(d)
    if errs:
        print("書き出さなかった。直すところ:")
        for e in errs: print("  -", e)
        sys.exit(1)

    L = []
    L.append("// このファイルは生成物。手で書き換えない。")
    L.append("// 元は translations/core.json、作るのは ./Tools-GenCore.py（引き継ぎ書 4-158）")
    L.append("")
    L.append("extension Preset {")
    L.append("    /// その言語の雛形。言語ごとに関数を分けてある（大きな辞書のリテラルは型の推論が遅い）。")
    L.append("    static func table(_ language: Language) -> [Preset] {")
    L.append("        switch language {")
    for lang in d["languages"]:
        L.append(f"        case .{CASE[lang]}: return {CASE[lang]}()")
    L.append("        }")
    L.append("    }")
    for lang in d["languages"]:
        L.append("")
        L.append(f"    private static func {CASE[lang]}() -> [Preset] {{")
        L.append("        [")
        for p in d["presets"]:
            x = p["languages"][lang]
            text = "\n\n".join("\n".join(g) for g in x["groups"])
            L.append(f"            Preset(id: {lit(p['id'])}, name: {lit(x['name'])}, detail: {lit(x['detail'])},")
            L.append(f"                   palette: Palette({p['palette']}), columns: {COLUMNS[p['columns']]},")
            L.append(f"                   text: {lit(text)}),")
        L.append("        ]")
        L.append("    }")
    L.append("}")
    L.append("")
    L.append("extension CoreText {")
    L.append("    static let table: [Key: [Language: String]] = [")
    for key, byLang in d["strings"].items():
        pairs = ", ".join(f".{CASE[l]}: {lit(byLang[l])}" for l in d["languages"])
        L.append(f"        .{key}: [{pairs}],")
    L.append("    ]")
    L.append("}")
    OUT.write_text("\n".join(L) + "\n")
    items = sum(len(g) for p in d["presets"] for g in p["languages"]["ja"]["groups"])
    print(f"書き出した: {OUT.relative_to(ROOT)}  言語{len(d['languages'])} × 雛形{len(d['presets'])}（1言語あたり項目{items}）")


if __name__ == "__main__":
    main()
