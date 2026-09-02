import Foundation
import Testing
import MochimonoCore
@testable import Mochimono

/// アプリ層。Coreには無い「保存して、次に開いたときに戻る」ところを見る。
@MainActor
struct AppModelTests {

    /// テストごとにまっさらな保存先を作る。共有すると前のテストの結果に引きずられる。
    private func freshDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func 初回は雛形から3本入っている() {
        let model = AppModel(defaults: freshDefaults())
        #expect(model.store.lists.map(\.name) == ["街中", "通勤・通学", "国内旅行"])
        #expect(model.store.lists.allSatisfy { !$0.items.isEmpty })
        #expect(model.saveError == nil)
    }

    /// 雛形から作ると、中身が入った独立したリストになる。
    @Test func 雛形から追加できる() {
        let model = AppModel(defaults: freshDefaults())
        let before = model.store.lists.count
        let preset = Preset.preset(id: "camp")!
        let id = model.addList(from: preset)
        #expect(model.store.lists.count == before + 1)
        #expect(model.list(id)?.name == "キャンプ・BBQ")
        #expect(model.list(id)?.items.count == preset.items.count)
        #expect(model.list(id)?.palette == preset.palette)
        #expect(model.list(id)?.packedCount == 0)
    }

    /// 同じ雛形から2本作っても、片方の編集がもう片方に及ばない。
    @Test func 雛形から2本作っても互いに影響しない() {
        let model = AppModel(defaults: freshDefaults())
        let preset = Preset.preset(id: "gym")!
        let a = model.addList(from: preset)
        let b = model.addList(from: preset)
        #expect(a != b)
        model.updateContents(of: a, name: "ジムA", text: "タオルだけ")
        #expect(model.list(b)?.items.count == preset.items.count)
        #expect(model.list(b)?.name == "ジム・運動")
    }

    /// チェックしてアプリを閉じても、次に開いたら残っている。
    @Test func チェックが保存されて復元される() {
        let defaults = freshDefaults()
        let listID: PackingList.ID
        let itemID: Item.ID
        do {
            let model = AppModel(defaults: defaults)
            listID = model.store.lists[1].id
            itemID = model.store.lists[1].items[0].id
            model.toggle(itemID, in: listID)
            #expect(model.list(listID)?.packedCount == 1)
        }
        let reopened = AppModel(defaults: defaults)
        #expect(reopened.list(listID)?.items.first { $0.id == itemID }?.isPacked == true)
    }

    @Test func 全部外すと0になる() {
        let model = AppModel(defaults: freshDefaults())
        let id = model.store.lists[1].id
        let total = model.list(id)!.items.count
        for item in model.list(id)!.items.prefix(3) { model.toggle(item.id, in: id) }
        #expect(model.list(id)?.packedCount == 3)
        model.clearAllPacked(in: id)
        #expect(model.list(id)?.packedCount == 0)
        #expect(model.list(id)?.items.count == total)   // 中身は消さない
    }

    /// 配色はリストごと。片方を変えても、もう片方は変わらない。
    /// 配色はリストごと。片方を送っても、もう片方は動かない。
    @Test func 配色はリストごとに独立している() {
        let model = AppModel(defaults: freshDefaults())
        let first = model.store.lists[0].id
        let second = model.store.lists[1].id
        let firstBefore = model.list(first)!.palette
        let secondBefore = model.list(second)!.palette
        model.cyclePalette(forward: true, for: second)
        #expect(model.list(second)?.palette == secondBefore.next())
        #expect(model.list(first)?.palette == firstBefore)
    }

    /// 送って戻せば元どおり。端でも行き止まらない。
    @Test func 配色を送って戻せる() {
        let model = AppModel(defaults: freshDefaults())
        let id = model.store.lists[0].id
        let before = model.list(id)!.palette
        model.cyclePalette(forward: true, for: id)
        #expect(model.list(id)?.palette != before)
        model.cyclePalette(forward: false, for: id)
        #expect(model.list(id)?.palette == before)

        // 20回送れば一周して戻る
        for _ in 0..<Palette.count { model.cyclePalette(forward: true, for: id) }
        #expect(model.list(id)?.palette == before)
    }

    @Test func 配色が保存される() {
        let defaults = freshDefaults()
        let id: PackingList.ID
        let after: Palette
        do {
            let model = AppModel(defaults: defaults)
            id = model.store.lists[0].id
            model.cyclePalette(forward: true, for: id)
            after = model.list(id)!.palette
        }
        #expect(AppModel(defaults: defaults).list(id)?.palette == after)
    }

    /// 明るさはアプリ全体。
    @Test func 明るさは全体に効いて保存される() {
        let defaults = freshDefaults()
        do {
            let model = AppModel(defaults: defaults)
            model.setAppearance(.dark)
        }
        #expect(AppModel(defaults: defaults).store.appearance == .dark)
    }

    @Test func 名前が空なら既定の名前になる() {
        let model = AppModel(defaults: freshDefaults())
        let id = model.store.lists[0].id
        model.updateContents(of: id, name: "   ", text: "A")
        #expect(model.list(id)?.name == "名前のないリスト")
    }

    /// 編集画面を開かずに1つ足せること。
    @Test func ひとつだけ足せる() {
        let model = AppModel(defaults: freshDefaults())
        let id = model.store.lists[0].id
        let before = model.list(id)!.items.count
        model.append("折りたたみ傘", to: id)
        #expect(model.list(id)?.items.count == before + 1)
        #expect(model.list(id)?.items.last?.text == "折りたたみ傘")
        #expect(model.list(id)?.items.last?.isPacked == false)
    }

    @Test func 空白だけ足しても何も起きない() {
        let model = AppModel(defaults: freshDefaults())
        let id = model.store.lists[0].id
        let before = model.list(id)!.items.count
        model.append("   ", to: id)
        #expect(model.list(id)?.items.count == before)
    }

    @Test func 足したものが保存される() {
        let defaults = freshDefaults()
        let id: PackingList.ID
        do {
            let model = AppModel(defaults: defaults)
            id = model.store.lists[0].id
            model.append("虫除け", to: id)
        }
        #expect(AppModel(defaults: defaults).list(id)?.items.last?.text == "虫除け")
    }

    /// 並べ替えが保存されること。次に開いたとき元に戻っていては意味がない。
    @Test func 並べ替えが保存される() {
        let defaults = freshDefaults()
        do {
            let model = AppModel(defaults: defaults)
            model.moveLists(from: IndexSet(integer: 2), to: 0)
            #expect(model.store.lists.map(\.name) == ["国内旅行", "街中", "通勤・通学"])
        }
        #expect(AppModel(defaults: defaults).store.lists.map(\.name)
                == ["国内旅行", "街中", "通勤・通学"])
    }

    /// 貼り付けたテキストから盤面になること。**この道具の芯なので落とせない。**
    @Test func 貼り付けたテキストからリストを作れる() {
        let model = AppModel(defaults: freshDefaults())
        let before = model.store.lists.count
        let id = model.addList(fromPastedText: "財布\nスマホ\n\n充電器")
        #expect(id != nil)
        #expect(model.store.lists.count == before + 1)
        #expect(model.list(id!)?.items.map(\.text) == ["財布", "スマホ", "充電器"])
        #expect(model.list(id!)?.items.map(\.group) == [0, 0, 1])
    }

    /// 書き出したテキストを読み戻すと、同じ盤面になること。
    @Test func 書き出して読み戻すと同じ盤面になる() {
        let model = AppModel(defaults: freshDefaults())
        let source = model.store.lists[2]                 // 国内旅行
        let id = model.addList(fromPastedText: source.text)
        #expect(model.list(id!)?.items.map(\.text) == source.items.map(\.text))
        #expect(model.list(id!)?.items.map(\.group) == source.items.map(\.group))
    }

    @Test func 中身の無いテキストでは作らない() {
        let model = AppModel(defaults: freshDefaults())
        let before = model.store.lists.count
        #expect(model.addList(fromPastedText: "   \n\n ") == nil)
        #expect(model.store.lists.count == before)
    }

    @Test func 白紙の追加と削除() {
        let model = AppModel(defaults: freshDefaults())
        let before = model.store.lists.count
        let id = model.addBlankList()
        #expect(model.store.lists.count == before + 1)
        #expect(model.list(id)?.items.isEmpty == true)
        model.remove(id)
        #expect(model.store.lists.count == before)
        #expect(model.list(id) == nil)
    }

    /// 消えたリストへの操作で落ちないこと。
    @Test func 消えたリストへの操作は無視される() {
        let model = AppModel(defaults: freshDefaults())
        let id = model.store.lists[0].id
        model.remove(id)
        model.clearAllPacked(in: id)
        model.setColumns(.two, for: id)
        model.updateContents(of: id, name: "x", text: "y")
        #expect(model.store.lists.count == 2)
    }
}
