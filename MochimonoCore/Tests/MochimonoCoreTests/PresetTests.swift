import Foundation
import Testing
@testable import MochimonoCore

/// はじめから用意する雛形。**12言語すべてで**守る。
///
/// 中身は目で見て決めない。4列で読めるか、グループが分かれているかを機械で守る。
/// 元のデータは `translations/core.json`。生成するときにも `Tools-GenCore.py` が同じことを確かめる。
struct PresetTests {

    @Test func 日本語の雛形がひととおり揃っている() {
        let names = Preset.all(.ja).map(\.name)
        #expect(names.count >= 10)
        for expected in ["街中", "通勤・通学", "国内旅行", "海外旅行"] {
            #expect(names.contains(expected), "「\(expected)」の雛形が無い")
        }
    }

    /// **どの言語でも、同じ雛形が同じ順・同じ配色で並ぶ。**
    /// ずれると、言語を変えただけで初期リストの配色が変わる。
    @Test(arguments: Language.allCases)
    func どの言語も日本語と同じ並び(_ language: Language) {
        let ja = Preset.all(.ja), other = Preset.all(language)
        #expect(other.map(\.id) == ja.map(\.id))
        #expect(other.map(\.palette) == ja.map(\.palette))
        #expect(other.map(\.columns) == ja.map(\.columns))
    }

    /// グループの形も同じ。見本の画面で「何番目を持った状態にするか」を言語をまたいで使う。
    @Test(arguments: Language.allCases)
    func グループの形が日本語と同じ(_ language: Language) {
        for (a, b) in zip(Preset.all(.ja), Preset.all(language)) {
            let shape = { (p: Preset) in p.groups.map { g in p.items.filter { $0.group == g }.count } }
            #expect(shape(b) == shape(a), "\(language)/\(b.id)")
        }
    }

    @Test(arguments: Language.allCases)
    func idと名前が重複していない(_ language: Language) {
        let all = Preset.all(language)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(all.map(\.name)).count == all.count, "\(language) の雛形名が重なっている")
    }

    /// 項目名が長いと、4列では縮んで読めなくなる。**中日韓とそれ以外で上限が違う。**
    @Test(arguments: Language.allCases)
    func 項目名が短い(_ language: Language) {
        let limit = Preset.maxItemLength(language)
        for preset in Preset.all(language) {
            for item in preset.items {
                #expect(item.text.count <= limit,
                        "\(language)/\(preset.id) の「\(item.text)」が \(item.text.count)文字（上限 \(limit)）")
            }
        }
    }

    /// 空行で分ける意味があること。1グループしか無いなら色分けが効かない。
    @Test(arguments: Language.allCases)
    func グループが2つ以上ある(_ language: Language) {
        for preset in Preset.all(language) {
            #expect(preset.items.count >= 6, "\(language)/\(preset.id) の項目が少なすぎる")
            #expect(preset.groups.count >= 2, "\(language)/\(preset.id) のグループが1つしかない")
            #expect(preset.groups == Array(0..<preset.groups.count), "\(language)/\(preset.id) の番号が飛んでいる")
        }
    }

    @Test(arguments: Language.allCases)
    func 同じ名前の項目が入っていない(_ language: Language) {
        for preset in Preset.all(language) {
            let names = preset.items.map(\.text)
            #expect(Set(names).count == names.count, "\(language)/\(preset.id) に同じ名前がある")
        }
    }

    @Test(arguments: Language.allCases)
    func 名前と説明が空でない(_ language: Language) {
        for preset in Preset.all(language) {
            #expect(!preset.name.isEmpty && !preset.detail.isEmpty, "\(language)/\(preset.id)")
        }
    }

    /// 選んだ時点でただのリストになり、雛形とは切り離される。
    @Test func 雛形から作ると独立したリストになる() {
        let preset = Preset.preset(id: "trip-domestic", language: .ja)!
        var a = preset.makeList()
        let b = preset.makeList()
        #expect(a.id != b.id)
        #expect(a.name == preset.name)
        #expect(a.palette == preset.palette)
        #expect(a.items.allSatisfy { !$0.isPacked })

        a.updateText("財布のみ")
        #expect(b.items.count > 1)
        #expect(Preset.preset(id: "trip-domestic", language: .ja)!.items.count > 1)
    }

    @Test func 初期リストは雛形から作られる() {
        let store = Store.starter(language: .ja)
        #expect(store.lists.map(\.name) == ["街中", "通勤・通学", "国内旅行"])
        #expect(store.lists.allSatisfy { !$0.items.isEmpty })
        #expect(store.lists.allSatisfy { $0.packedCount == 0 })
    }

    /// **英語の端末には英語の初期リスト。** 日本語が並ぶと、最初の一画面で使えない。
    @Test(arguments: Language.allCases)
    func 初期リストはその言語で作られる(_ language: Language) {
        let store = Store.starter(language: language)
        #expect(store.lists.count == 3)
        let names = Preset.all(language).filter { ["town", "commute", "trip-domestic"].contains($0.id) }.map(\.name)
        #expect(store.lists.map(\.name) == names)
    }
}

extension Preset: CustomTestStringConvertible {
    public var testDescription: String { name }
}
