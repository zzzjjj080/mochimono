import Foundation
import Testing
@testable import MochimonoCore

/// 編集でチェックが飛ばないこと。
///
/// **このアプリで一番壊れやすいのがここ。** 出かける直前に書き足したら
/// それまでのチェックが全部消えた、では使い物にならない。
struct ReconcileTests {

    private func list() -> PackingList {
        var l = PackingList(name: "野球", text: "帽子\nソックス\n\nグローブ\nバット")
        l.toggle(l.items[0].id)   // 帽子
        l.toggle(l.items[2].id)   // グローブ
        return l
    }

    @Test func 並べ替えても引き継ぐ() {
        var l = list()
        l.updateText("ソックス\n帽子\n\nバット\nグローブ")
        let packed = l.items.filter(\.isPacked).map(\.text)
        #expect(Set(packed) == ["帽子", "グローブ"])
    }

    @Test func 足しても既のチェックは残り_足したものは未チェック() {
        var l = list()
        l.updateText("帽子\nソックス\nスパイク\n\nグローブ\nバット")
        #expect(l.items.first { $0.text == "帽子" }?.isPacked == true)
        #expect(l.items.first { $0.text == "スパイク" }?.isPacked == false)
        #expect(l.packedCount == 2)
    }

    @Test func 消したものは消える() {
        var l = list()
        l.updateText("ソックス\n\nバット")
        #expect(l.items.map(\.text) == ["ソックス", "バット"])
        #expect(l.packedCount == 0)
    }

    /// IDで記録しているので、名前が同じなら別物にならない。
    @Test func IDを引き継ぐ() {
        var l = list()
        let before = l.items[0].id
        l.updateText("ソックス\n帽子\n\nグローブ\nバット")
        #expect(l.items.first { $0.text == "帽子" }?.id == before)
    }

    /// グループをまたいで動かしても、チェックは付いてくる。
    @Test func グループをまたいでも引き継ぐ() {
        var l = PackingList(name: "x", text: "タオル\n\n水筒")
        l.toggle(l.items[0].id)
        l.updateText("水筒\n\nタオル")
        #expect(l.items.first { $0.text == "タオル" }?.isPacked == true)
        #expect(l.items.first { $0.text == "水筒" }?.isPacked == false)
    }

    /// 同じ名前が2つあるときは、順番で対応させる。
    @Test func 同名は順番で対応する() {
        var l = PackingList(name: "x", text: "電池\n電池")
        l.toggle(l.items[0].id)
        l.updateText("電池\n電池")
        #expect(l.items.map(\.isPacked) == [true, false])
    }

    /// 消えたIDへの操作で落ちないこと（引き継ぎ書 4-10）。
    @Test func 消えたIDへの操作は無視される() {
        var l = list()
        let gone = l.items[0].id
        l.updateText("バット")
        l.toggle(gone)              // 落ちない
        #expect(l.packedCount == 0)
    }

    @Test func 全部外すは全部外す() {
        var l = list()
        #expect(l.packedCount == 2)
        l.clearAllPacked()
        #expect(l.packedCount == 0)
        #expect(l.items.count == 4)   // 中身は消さない
    }

    @Test func そろったかどうか() {
        var l = PackingList(name: "x", text: "A\nB")
        #expect(!l.isComplete)
        l.items.forEach { l.toggle($0.id) }
        #expect(l.isComplete)
        #expect(PackingList(name: "空", text: "").isComplete == false)   // 空はそろっていない
    }

    @Test func グループ番号は出た順に並ぶ() {
        let l = PackingList(name: "x", text: "A\n\nB\n\nC")
        #expect(l.groups == [0, 1, 2])
    }
}
