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

/// 編集画面を開かずに1行足す道。
struct AppendTests {

    @Test func 末尾に足される() {
        var l = PackingList(name: "x", text: "帽子\nバット")
        l.append("グローブ")
        #expect(l.items.map(\.text) == ["帽子", "バット", "グローブ"])
        #expect(l.items.last?.group == 0)
    }

    /// 末尾に空行が残っていると、足したものだけ別グループになってしまう。
    @Test func 末尾の空行があっても最後のグループに入る() {
        var l = PackingList(name: "x", text: "帽子\n\nグローブ\n\n")
        l.append("バット")
        #expect(l.items.map { "\($0.text):\($0.group)" } == ["帽子:0", "グローブ:1", "バット:1"])
    }

    @Test func 空のリストにも足せる() {
        var l = PackingList(name: "x", text: "")
        l.append("財布")
        #expect(l.items.map(\.text) == ["財布"])
        #expect(l.text == "財布")
    }

    @Test func 空白だけなら何もしない() {
        var l = PackingList(name: "x", text: "帽子")
        l.append("   ")
        l.append("\n")
        #expect(l.items.count == 1)
    }

    @Test func 前後の空白は落ちる() {
        var l = PackingList(name: "x", text: "帽子")
        l.append("  バット  ")
        #expect(l.items.last?.text == "バット")
    }

    /// 足しても、既に付いているチェックは消えない。
    @Test func 既のチェックは残る() {
        var l = PackingList(name: "x", text: "帽子\nバット")
        l.toggle(l.items[0].id)
        l.append("グローブ")
        #expect(l.items.first { $0.text == "帽子" }?.isPacked == true)
        #expect(l.items.last?.isPacked == false)
        #expect(l.packedCount == 1)
    }

    /// テキストが正本なので、足したぶんが本文にも入っていること。
    @Test func テキストにも入る() {
        var l = PackingList(name: "x", text: "帽子\n\nグローブ")
        l.append("バット")
        #expect(l.text == "帽子\n\nグローブ\nバット")
    }
}

/// 貼り付けたテキストから作る。
/// **書き出したものをそのまま読み戻せること**が、この道具の芯。
struct PasteTests {

    @Test func テキストから盤面になる() {
        let l = PackingList.fromPastedText("財布\nスマホ\n\n充電器")
        #expect(l?.items.map { "\($0.text):\($0.group)" } == ["財布:0", "スマホ:0", "充電器:1"])
    }

    /// 書き出し → 読み戻しで、中身が変わらないこと。
    @Test func 書き出して読み戻しても変わらない() {
        var original = PackingList(name: "野球", text: "帽子\nバット\n\nタオル\n水筒")
        original.toggle(original.items[0].id)
        let restored = PackingList.fromPastedText(original.text, name: original.name)
        #expect(restored?.text == original.text)
        #expect(restored?.items.map(\.text) == original.items.map(\.text))
        #expect(restored?.items.map(\.group) == original.items.map(\.group))
        // チェックは持ち越さない。渡した相手の準備状況まで押し付けない
        #expect(restored?.packedCount == 0)
    }

    @Test func 名前を渡さなければ最初の項目から借りる() {
        #expect(PackingList.fromPastedText("財布\nスマホ")?.name == "財布")
        let long = PackingList.fromPastedText("とてもながいなまえのもちもの\nスマホ")
        #expect(long?.name.count == 10)
    }

    @Test func 中身が無ければ作らない() {
        #expect(PackingList.fromPastedText("") == nil)
        #expect(PackingList.fromPastedText("\n \n\t\n") == nil)
    }

    /// 他のアプリで書いたテキストも、そのまま受け取れること。
    @Test func 箇条書きの記号が混ざっていても読める() {
        let l = PackingList.fromPastedText("  財布  \r\nスマホ\r\n\r\n充電器")
        #expect(l?.items.map(\.text) == ["財布", "スマホ", "充電器"])
    }
}
