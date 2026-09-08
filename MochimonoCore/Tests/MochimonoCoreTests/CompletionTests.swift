import Foundation
import Testing
@testable import MochimonoCore

/// 「前回そろった日時」と「残り」。
///
/// 使い回すリストは、**いつ使ったか**が次の判断材料になる。
struct CompletionTests {

    private let 基準 = Date(timeIntervalSince1970: 1_757_000_000)

    private func make() -> PackingList {
        PackingList(name: "通勤", text: "財布\nスマホ")
    }

    @Test func 最初は記録がない() {
        #expect(make().lastCompletedAt == nil)
    }

    @Test func 全部そろった瞬間に日時が入る() {
        var list = make()
        list.toggle(list.items[0].id, now: 基準)
        #expect(list.lastCompletedAt == nil)      // まだ途中
        list.toggle(list.items[1].id, now: 基準)
        #expect(list.lastCompletedAt == 基準)
    }

    /// 外したのはチェックであって記録ではない。
    @Test func 全部外しても記録は残る() {
        var list = make()
        for item in list.items { list.toggle(item.id, now: 基準) }
        list.clearAllPacked()
        #expect(list.packedCount == 0)
        #expect(list.lastCompletedAt == 基準)
    }

    /// 1つ外して付け直したら、新しいほうの日時になる。
    @Test func 付け直すと日時が新しくなる() {
        var list = make()
        for item in list.items { list.toggle(item.id, now: 基準) }
        let あとで = 基準.addingTimeInterval(86_400)
        list.toggle(list.items[0].id, now: あとで)   // 外す
        #expect(list.lastCompletedAt == 基準)
        list.toggle(list.items[0].id, now: あとで)   // 付け直す
        #expect(list.lastCompletedAt == あとで)
    }

    /// 空のリストは `isComplete` が false。日時が入ってはいけない。
    @Test func 空のリストでは記録されない() {
        var list = PackingList(name: "空", text: "")
        list.toggle(UUID(), now: 基準)
        #expect(list.lastCompletedAt == nil)
    }

    @Test func 保存して読み戻しても日時が残る() throws {
        var list = make()
        for item in list.items { list.toggle(item.id, now: 基準) }
        let back = try JSONDecoder().decode(
            PackingList.self, from: JSONEncoder().encode(list))
        #expect(back.lastCompletedAt == 基準)
    }

    /// 日時を持っていない古いJSONも読めること（引き継ぎ書 4-21）。
    @Test func 日時が無い古いJSONも読める() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"古い","text":"財布","columns":4,"palette":1,"items":[]}
        """
        let list = try JSONDecoder().decode(PackingList.self, from: Data(json.utf8))
        #expect(list.lastCompletedAt == nil)
        #expect(list.name == "古い")
    }

    @Test func 残りは順番どおりに並ぶ() {
        var list = PackingList(name: "旅", text: "財布\nスマホ\n鍵")
        list.toggle(list.items[1].id, now: 基準)
        #expect(list.remainingItems.map(\.text) == ["財布", "鍵"])
    }

    @Test func そろったら残りは空になる() {
        var list = make()
        for item in list.items { list.toggle(item.id, now: 基準) }
        #expect(list.remainingItems.isEmpty)
    }
}
