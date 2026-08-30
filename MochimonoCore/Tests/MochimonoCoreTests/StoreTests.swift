import Foundation
import Testing
@testable import MochimonoCore

/// 保存の読み書き。
///
/// **旧版のJSONを直書きしたテストを必ず置く。**
/// 項目を1つ足しただけのつもりで、同じ入れ物の記録まで失うことがある（引き継ぎ書 4-21）。
struct StoreTests {

    @Test func 往復しても変わらない() throws {
        var store = Store.starter
        store.lists[0].toggle(store.lists[0].items[1].id)
        store.appearance = .dark
        let data = try JSONEncoder().encode(store)
        let back = try JSONDecoder().decode(Store.self, from: data)
        #expect(back == store)
    }

    /// 配色も列数も明暗も無かった頃のJSON。既定値で埋めて必ず読めること。
    @Test func 項目が足りない古いJSONも読める() throws {
        let json = """
        {
          "lists": [
            {
              "id": "1B4E28BA-2FA1-11D2-883F-B9A761BDE3FB",
              "name": "野球",
              "text": "帽子\\nバット",
              "items": [
                {"id":"1B4E28BA-2FA1-11D2-883F-B9A761BDE3FA","text":"帽子","group":0,"isPacked":true},
                {"id":"1B4E28BA-2FA1-11D2-883F-B9A761BDE3FC","text":"バット","group":0,"isPacked":false}
              ]
            }
          ]
        }
        """
        let store = try JSONDecoder().decode(Store.self, from: Data(json.utf8))
        #expect(store.appearance == .system)
        #expect(store.lists.count == 1)
        #expect(store.lists[0].columns == .four)
        #expect(store.lists[0].palette == .colorful)
        #expect(store.lists[0].packedCount == 1)      // チェックが消えていない
    }

    /// items が丸ごと無くても、text から作り直せること。
    @Test func itemsが無ければテキストから作る() throws {
        let json = #"{"lists":[{"id":"1B4E28BA-2FA1-11D2-883F-B9A761BDE3FB","name":"x","text":"A\n\nB"}]}"#
        let store = try JSONDecoder().decode(Store.self, from: Data(json.utf8))
        #expect(store.lists[0].items.map { "\($0.text):\($0.group)" } == ["A:0", "B:1"])
    }

    @Test func 添字でリストを差し替えられる() {
        var store = Store.starter
        let before = store.lists.count
        let id = store.lists[0].id
        var l = store[id]!
        l.name = "改名"
        store[id] = l
        #expect(store.lists[0].name == "改名")
        #expect(store.lists.count == before)      // 差し替えであって追加ではない
    }

    @Test func 削除は該当だけ消す() {
        var store = Store.starter
        let before = store.lists.count
        let removed = store.lists[0]
        let rest = store.lists.dropFirst().map(\.name)
        store.remove(id: removed.id)
        #expect(store.lists.count == before - 1)
        #expect(store.lists.map(\.name) == Array(rest))
    }

    /// 保存に入るので、値が変わると列数の設定が壊れる。
    @Test func 列数の保存値() {
        #expect(Columns.allCases.map(\.rawValue) == [2, 3, 4, 5])
    }
}
