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

    /// 並べ替え。SwiftUI の `move(fromOffsets:toOffset:)` と同じ規則で動く。
    ///
    /// `destination` は**動かす前の並びでの挿入位置**なので、
    /// 先に取り除いてから入れると、前に詰まったぶんだけ位置がずれる。
    /// 取り除いた個数を引いて補正する。
    public mutating func moveLists(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().compactMap { lists.indices.contains($0) ? lists[$0] : nil }
        guard !moving.isEmpty else { return }
        for i in source.sorted(by: >) where lists.indices.contains(i) { lists.remove(at: i) }
        let shift = source.filter { $0 < destination }.count
        let at = min(max(destination - shift, 0), lists.count)
        lists.insert(contentsOf: moving, at: at)
    }

    /// 1本を丸ごと写して、**元のすぐ下に**入れる。
    ///
    /// 末尾に足すと、本数が増えたときに元と離れて見比べられない。
    /// 名前は重ならないようにする。同じ名前が並ぶと、どちらを開いたのか分からなくなる。
    @discardableResult
    public mutating func duplicate(id: PackingList.ID) -> PackingList.ID? {
        guard let i = lists.firstIndex(where: { $0.id == id }) else { return nil }
        let copy = lists[i].duplicated(name: unusedName(basedOn: lists[i].name))
        lists.insert(copy, at: i + 1)
        return copy.id
    }

    /// 「◯◯のコピー」。既にあれば 2, 3 … と数字を足す。
    func unusedName(basedOn name: String) -> String {
        let base = name + "のコピー"
        let taken = Set(lists.map(\.name))
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base)\(n)") { n += 1 }
        return "\(base)\(n)"
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
