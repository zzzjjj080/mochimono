import Foundation
import Testing
@testable import MochimonoCore

/// カラーモード。オンならグループごとに色が変わり、オフなら全部が同じ1色になる。
struct ColorModeTests {

    private func make() -> PackingList {
        PackingList(name: "旅", text: "財布\nスマホ\n\n着替え\n\n充電器")
    }

    /// 空行で色が変わるのがこのアプリの芯。最初からそれが見えていること。
    @Test func 既定はオン() {
        let list = make()
        #expect(list.isColorful)
        #expect(list.toneGroups == [0, 1, 2])
        #expect(list.items.map { list.toneGroup($0.group) } == [0, 0, 1, 2])
    }

    @Test func オフなら全部が同じ色で塗られる() {
        var list = make()
        list.isColorful = false
        #expect(list.toneGroups == [0])
        #expect(list.items.map { list.toneGroup($0.group) } == [0, 0, 0, 0])
    }

    /// 塗り方だけを変える。グループの区切りそのものは失わない。
    /// 失うと、オンに戻したときに空行で分けたとおりの色へ戻れない。
    @Test func オフにしてもグループの区切りは残る() {
        var list = make()
        list.isColorful = false
        #expect(list.items.map(\.group) == [0, 0, 1, 2])
        list.isColorful = true
        #expect(list.items.map { list.toneGroup($0.group) } == [0, 0, 1, 2])
    }

    /// 1色でも「まだ」と「持った」は見分けられること。
    /// オフのときは全部0番の色なので、0番がどの配色でも条件を満たしていればよい。
    @Test(arguments: Palette.all)
    func オフでも読めて見分けられる(_ palette: Palette) {
        for scheme in [Scheme.light, .dark] {
            let off = palette.tone(group: 0, isPacked: false, scheme: scheme)
            let on = palette.tone(group: 0, isPacked: true, scheme: scheme)
            #expect(Contrast.ratio(off.fill, off.label) >= Contrast.text)
            #expect(Contrast.ratio(on.fill, on.label) >= Contrast.text)
            #expect(Contrast.ratio(off.fill, on.fill) >= Contrast.state,
                    "配色\(palette.number)/\(scheme)")
        }
    }

    @Test func 空のリストでは色を用意しない() {
        var list = PackingList(name: "空", text: "")
        list.isColorful = false
        #expect(list.toneGroups.isEmpty)
    }

    @Test func テキストを書き換えてもカラーモードは変わらない() {
        var list = make()
        list.isColorful = false
        list.updateText("財布\n\n鍵")
        list.append("傘")
        #expect(!list.isColorful)
    }

    @Test func 複製にも写る() {
        var store = Store(lists: [make()])
        store.lists[0].isColorful = false
        store.duplicate(id: store.lists[0].id)
        #expect(store.lists[1].isColorful == false)
    }

    @Test func 保存して読み戻しても残る() throws {
        var list = make()
        list.isColorful = false
        let back = try JSONDecoder().decode(PackingList.self, from: JSONEncoder().encode(list))
        #expect(back.isColorful == false)
    }

    /// カラーモードが無かった頃のJSON。読めて、オンになること（引き継ぎ書 4-21）。
    @Test func カラーモードが無い古いJSONはオンで読める() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"古い","text":"財布\\n\\n鍵","columns":4,"palette":3}
        """
        let list = try JSONDecoder().decode(PackingList.self, from: Data(json.utf8))
        #expect(list.isColorful)
        #expect(list.palette == Palette(3))
    }

    /// 12種類だった頃に11・12を選んでいたリストも、落とさずに読めること。
    @Test func 前の版で11や12を選んでいたリストも読める() throws {
        for (saved, expected) in [(11, 1), (12, 2)] {
            let json = """
            {"id":"\(UUID().uuidString)","name":"古い","text":"財布","palette":\(saved)}
            """
            let list = try JSONDecoder().decode(PackingList.self, from: Data(json.utf8))
            #expect(list.palette == Palette(expected), "保存されていた \(saved)")
        }
    }
}
