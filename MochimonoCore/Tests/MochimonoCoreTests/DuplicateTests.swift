import Foundation
import Testing
@testable import MochimonoCore

/// リストの複製。
///
/// 雛形より、**自分が書いたリストのほうが出発点として近い**。
/// 「国内旅行」から「海外旅行」を作るための道。
struct DuplicateTests {

    private func make() -> Store {
        Store(lists: [
            PackingList(name: "国内旅行", text: "財布\nスマホ\n\n着替え"),
            PackingList(name: "通勤", text: "定期券"),
        ])
    }

    @Test func 中身がそのまま写る() {
        var store = make()
        let newID = store.duplicate(id: store.lists[0].id)
        let copy = store.lists.first { $0.id == newID }
        #expect(copy?.text == "財布\nスマホ\n\n着替え")
        #expect(copy?.items.map(\.text) == ["財布", "スマホ", "着替え"])
        #expect(copy?.items.map(\.group) == [0, 0, 1])
    }

    /// 列数と配色も写す。写さないと、複製したとたんに見た目が変わって別物に見える。
    @Test func 見た目の設定も写る() {
        var store = make()
        store.lists[0].columns = .three
        store.lists[0].palette = Palette(7)
        store.duplicate(id: store.lists[0].id)
        #expect(store.lists[1].columns == .three)
        #expect(store.lists[1].palette == Palette(7))
    }

    /// 写すのは「何を書いたか」であって、前の回の進み具合ではない。
    @Test func チェックとそろった日時は持ち越さない() {
        var store = make()
        for item in store.lists[0].items { store.lists[0].toggle(item.id) }
        #expect(store.lists[0].isComplete)
        #expect(store.lists[0].lastCompletedAt != nil)

        store.duplicate(id: store.lists[0].id)
        #expect(store.lists[1].packedCount == 0)
        #expect(store.lists[1].lastCompletedAt == nil)
    }

    /// 末尾に足すと、本数が増えたときに元と離れて見比べられない。
    @Test func 元のすぐ下に入る() {
        var store = make()
        store.duplicate(id: store.lists[0].id)
        #expect(store.lists.map(\.name) == ["国内旅行", "国内旅行のコピー", "通勤"])
    }

    @Test func 名前は重ならない() {
        var store = make()
        store.duplicate(id: store.lists[0].id)
        store.duplicate(id: store.lists[0].id)
        store.duplicate(id: store.lists[0].id)
        #expect(store.lists.map(\.name)
                == ["国内旅行", "国内旅行のコピー3", "国内旅行のコピー2", "国内旅行のコピー", "通勤"])
    }

    /// 別のIDになっていないと、片方を触るともう片方まで変わる。
    @Test func 項目のIDまで作り直す() {
        var store = make()
        store.duplicate(id: store.lists[0].id)
        let original = Set(store.lists[0].items.map(\.id))
        let copy = Set(store.lists[1].items.map(\.id))
        #expect(store.lists[0].id != store.lists[1].id)
        #expect(original.isDisjoint(with: copy))
    }

    @Test func 消えたIDを複製しても落ちない() {
        var store = make()
        #expect(store.duplicate(id: UUID()) == nil)
        #expect(store.lists.count == 2)
    }
}
