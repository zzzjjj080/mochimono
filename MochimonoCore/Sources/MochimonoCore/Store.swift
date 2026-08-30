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

    /// 初回に入れておく例。何が書けるのかが分からないと、そもそも始められない。
    public static var starter: Store {
        Store(appearance: .system, lists: [
            PackingList(name: "街中",
                        text: """
                              財布
                              スマホ
                              鍵
                              ハンカチ

                              イヤホン
                              モバイルバッテリー
                              充電ケーブル

                              目薬
                              リップ
                              """,
                        palette: .colorful),
            PackingList(name: "野球",
                        text: """
                              帽子
                              ソックス
                              アンダーシャツ
                              ベルト

                              グローブ
                              バット
                              スパイク

                              タオル
                              水筒
                              日焼け止め
                              保険証
                              """,
                        palette: .vivid),
        ])
    }
}
