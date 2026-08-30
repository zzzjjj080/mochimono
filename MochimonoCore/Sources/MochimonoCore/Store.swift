import Foundation

/// 保存するもの全部。
public struct Store: Equatable, Codable, Sendable {
    public var appearance: Appearance
    public var lists: [PackingList]

    public init(appearance: Appearance = .system, lists: [PackingList] = []) {
        self.appearance = appearance
        self.lists = lists
    }

    // 項目を足しても、既に保存してある記録を失わないようにする（引き継ぎ書 4-21）。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .system
        lists = try c.decodeIfPresent([PackingList].self, forKey: .lists) ?? []
    }

    public subscript(id: PackingList.ID) -> PackingList? {
        get { lists.first { $0.id == id } }
        set {
            guard let i = lists.firstIndex(where: { $0.id == id }) else { return }
            guard let newValue else { lists.remove(at: i); return }
            lists[i] = newValue
        }
    }

    public mutating func remove(id: PackingList.ID) {
        lists.removeAll { $0.id == id }
    }

    /// 初回に入れておくリスト。
    ///
    /// 空っぽで始めると、何をどう書けばいいのかが分からない。
    /// **よく使う3本を最初から入れておく。** 残りは「追加」から雛形として選べる。
    public static var starter: Store {
        Store(appearance: .system,
              lists: ["town", "commute", "trip-domestic"]
                .compactMap { Preset.preset(id: $0)?.makeList() })
    }

}
