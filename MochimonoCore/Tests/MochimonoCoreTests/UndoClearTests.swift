import Foundation
import Testing
@testable import MochimonoCore

/// 「全部外す」の取り消し。
///
/// 全部そろった盤面では確認を出さずに外すので、**戻す道が要る。**
struct UndoClearTests {

    private let 基準 = Date(timeIntervalSince1970: 1_757_000_000)

    private func packed() -> PackingList {
        var list = PackingList(name: "街中", text: "財布\nスマホ\n\n鍵")
        for item in list.items { list.toggle(item.id, now: 基準) }
        return list
    }

    @Test func 外してから戻すと元どおりになる() {
        var list = packed()
        let before = list.packedSnapshot()
        list.clearAllPacked()
        #expect(list.packedCount == 0)

        list.restore(before)
        #expect(list.packedCount == 3)
        #expect(list.isComplete)
    }

    /// 途中まで進んでいた状態も、そのまま戻ること。全部入りに化けない。
    @Test func 途中の状態も同じところへ戻る() {
        var list = PackingList(name: "街中", text: "財布\nスマホ\n\n鍵")
        list.toggle(list.items[1].id, now: 基準)
        let before = list.packedSnapshot()
        list.clearAllPacked()

        list.restore(before)
        #expect(list.items.map(\.isPacked) == [false, true, false])
    }

    /// そろった日時まで戻す。戻したのに「前回」だけ書き換わっていると辻褄が合わない。
    @Test func そろった日時も戻る() {
        var list = packed()
        let before = list.packedSnapshot()
        #expect(before.lastCompletedAt == 基準)

        list.clearAllPacked()
        list.restore(before)
        #expect(list.lastCompletedAt == 基準)
    }

    /// 取り消すまでの間に書き換えられていても落ちない（引き継ぎ書 4-10）。
    @Test func 撮ったあとに消えた項目があっても落ちない() {
        var list = packed()
        let before = list.packedSnapshot()
        list.clearAllPacked()
        list.updateText("財布\n\n傘")          // スマホと鍵が消えて、傘が増えた

        list.restore(before)
        #expect(list.items.map(\.text) == ["財布", "傘"])
        #expect(list.items.map(\.isPacked) == [true, false])
    }

    @Test func 空のリストでも落ちない() {
        var list = PackingList(name: "空", text: "")
        let before = list.packedSnapshot()
        list.clearAllPacked()
        list.restore(before)
        #expect(list.items.isEmpty)
    }
}
