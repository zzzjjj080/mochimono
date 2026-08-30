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

    @Test func 初回は例のリストが入っている() {
        let model = AppModel(defaults: freshDefaults())
        #expect(model.store.lists.map(\.name) == ["街中", "野球"])
        #expect(model.saveError == nil)
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
        for item in model.list(id)!.items.prefix(3) { model.toggle(item.id, in: id) }
        #expect(model.list(id)?.packedCount == 3)
        model.clearAllPacked(in: id)
        #expect(model.list(id)?.packedCount == 0)
        #expect(model.list(id)?.items.count == 11)   // 中身は消さない
    }

    /// 配色はリストごと。片方を変えても、もう片方は変わらない。
    @Test func 配色はリストごとに独立している() {
        let model = AppModel(defaults: freshDefaults())
        let machi = model.store.lists[0].id
        let yakyu = model.store.lists[1].id
        model.setPalette(.mono, for: yakyu)
        #expect(model.list(yakyu)?.palette == .mono)
        #expect(model.list(machi)?.palette == .colorful)
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

    @Test func 追加と削除() {
        let model = AppModel(defaults: freshDefaults())
        let id = model.addList()
        #expect(model.store.lists.count == 3)
        model.remove(id)
        #expect(model.store.lists.count == 2)
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
        #expect(model.store.lists.count == 1)
    }
}
