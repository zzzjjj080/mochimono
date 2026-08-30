import Foundation
import Testing
@testable import MochimonoCore

/// はじめから用意する雛形。
///
/// **中身は目で見て決めない。** 4列に並べたときに読めるか、グループが分かれているかを機械で守る。
struct PresetTests {

    @Test func 雛形がひととおり揃っている() {
        #expect(Preset.all.count >= 10)
        let names = Preset.all.map(\.name)
        // よくある場面が抜けていないこと
        for expected in ["街中", "通勤・通学", "国内旅行", "海外旅行"] {
            #expect(names.contains(expected), "「\(expected)」の雛形が無い")
        }
    }

    /// idは保存には入らないが、初期リストの指定に使う。重複すると別物を引く。
    @Test func idと名前が重複していない() {
        #expect(Set(Preset.all.map(\.id)).count == Preset.all.count)
        #expect(Set(Preset.all.map(\.name)).count == Preset.all.count)
    }

    /// 項目名が長いと、4列では縮んで読めなくなる。
    @Test(arguments: Preset.all)
    func 項目名が短い(_ preset: Preset) {
        for item in preset.items {
            #expect(item.text.count <= Preset.maxItemLength,
                    "\(preset.name) の「\(item.text)」が \(item.text.count)文字")
        }
    }

    /// 空行で分ける意味があること。1グループしか無いなら色分けが効かない。
    @Test(arguments: Preset.all)
    func グループが2つ以上ある(_ preset: Preset) {
        #expect(preset.items.count >= 6, "\(preset.name) の項目が少なすぎる")
        #expect(preset.groups.count >= 2, "\(preset.name) のグループが1つしかない")
    }

    /// 使われないグループ番号があると、色が飛ぶ。
    @Test(arguments: Preset.all)
    func グループ番号が飛んでいない(_ preset: Preset) {
        #expect(preset.groups == Array(0..<preset.groups.count), "\(preset.name)")
    }

    @Test(arguments: Preset.all)
    func 同じ名前の項目が入っていない(_ preset: Preset) {
        let names = preset.items.map(\.text)
        #expect(Set(names).count == names.count, "\(preset.name) に同じ名前がある")
    }

    /// 選んだ時点でただのリストになり、雛形とは切り離される。
    @Test func 雛形から作ると独立したリストになる() {
        let preset = Preset.preset(id: "trip-domestic")!
        var a = preset.makeList()
        let b = preset.makeList()
        #expect(a.id != b.id)
        #expect(a.name == preset.name)
        #expect(a.palette == preset.palette)
        #expect(a.items.allSatisfy { !$0.isPacked })

        a.updateText("財布のみ")
        #expect(b.items.count > 1)                    // もう一方は変わらない
        #expect(Preset.preset(id: "trip-domestic")!.items.count > 1)   // 雛形も変わらない
    }

    @Test func 初期リストは雛形から作られる() {
        let store = Store.starter
        #expect(store.lists.map(\.name) == ["街中", "通勤・通学", "国内旅行"])
        #expect(store.lists.allSatisfy { !$0.items.isEmpty })
        #expect(store.lists.allSatisfy { $0.packedCount == 0 })
    }
}

extension Preset: CustomTestStringConvertible {
    public var testDescription: String { name }
}
