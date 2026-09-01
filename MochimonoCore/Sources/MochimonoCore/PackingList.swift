import Foundation

/// 持ち物ひとつ。
///
/// **表示名ではなくIDで指す。** 名前で対応付けると、書き換えた瞬間に記録が迷子になる。
public struct Item: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    /// 表示する名前。テキストの1行そのまま。
    public var text: String
    /// 何番目のグループか（0始まり）。空行で1つ進む。
    public var group: Int
    /// 持ったか。
    public var isPacked: Bool

    public init(id: UUID = UUID(), text: String, group: Int, isPacked: Bool = false) {
        self.id = id
        self.text = text
        self.group = group
        self.isPacked = isPacked
    }
}

/// 1画面に何列並べるか。
///
/// 0や7を作れないように型で塞ぐ。`Int` で持つと、あり得ない値が保存に混ざる。
public enum Columns: Int, Codable, CaseIterable, Sendable {
    case two = 2, three = 3, four = 4, five = 5

    /// セルの横縦比。和名は横に伸びるので、横長のほうが1行に収まって字が大きくなる。
    public var aspectRatio: Double {
        switch self {
        case .two: 2.6
        case .three: 1.9
        case .four: 1.55
        case .five: 1.35
        }
    }
}

/// 持ち物リスト1本。
///
/// **正本は `text`。** `items` は text から作り、チェックの状態だけを持ち越す。
public struct PackingList: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    /// プレーンテキスト。1行1つ、空行でグループが分かれる。
    public private(set) var text: String
    public var columns: Columns
    public var palette: Palette
    public private(set) var items: [Item]

    public init(id: UUID = UUID(), name: String, text: String,
                columns: Columns = .four, palette: Palette = .first) {
        self.id = id
        self.name = name
        self.text = text
        self.columns = columns
        self.palette = palette
        self.items = Self.parse(text, preserving: [])
    }

    // 保存済みのJSONに項目が足りなくても読めるようにする。
    // `decode` は1つでも欠けると全部を失う（引き継ぎ書 4-21）。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "名前のないリスト"
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        columns = try c.decodeIfPresent(Columns.self, forKey: .columns) ?? .four
        palette = try c.decodeIfPresent(Palette.self, forKey: .palette) ?? .first
        let saved = try c.decodeIfPresent([Item].self, forKey: .items)
        items = saved ?? Self.parse(text, preserving: [])
    }

    // MARK: - 集計

    public var packedCount: Int { items.filter(\.isPacked).count }
    public var isComplete: Bool { !items.isEmpty && packedCount == items.count }
    /// 使われているグループ番号。順番どおり。
    public var groups: [Int] {
        var seen = Set<Int>()
        return items.map(\.group).filter { seen.insert($0).inserted }
    }

    // MARK: - 操作（すべてIDで指す）

    /// 1つだけ入り切りする。**消えたIDへの操作は黙って無視する。**
    /// 取りこぼしがあっても落ちないようにしておく（引き継ぎ書 4-10）。
    public mutating func toggle(_ id: Item.ID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isPacked.toggle()
    }

    /// チェックを全部外す。**破壊的な操作はこの1本に集約する。**
    /// 経路を増やすと、確認ダイアログを迂回する道ができる（引き継ぎ書 4-12）。
    public mutating func clearAllPacked() {
        for i in items.indices { items[i].isPacked = false }
    }

    /// 1つだけ足す。編集画面を開かずに書き足すための道。
    ///
    /// **末尾の空行を落としてから足す。** 落とさずに足すと、
    /// 「空行＝グループの区切り」の解釈で、足したものだけが新しいグループになる。
    /// 書いた本人は最後の塊に足したつもりなので、色が変わると驚く。
    public mutating func append(_ line: String) {
        let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var base = text
        while base.hasSuffix("\n") || base.hasSuffix(" ") { base.removeLast() }
        updateText(base.isEmpty ? name : base + "\n" + name)
    }

    /// テキストを書き換える。チェックの状態は名前で突き合わせて引き継ぐ。
    public mutating func updateText(_ newText: String) {
        text = newText
        items = Self.parse(newText, preserving: items)
    }

    // MARK: - 解釈

    /// テキストを持ち物に変える。
    ///
    /// - 1行 = 1つ。前後の空白は落とす。
    /// - 空行でグループが1つ進む。**連続した空行・先頭や末尾の空行では進めない。**
    ///   進めてしまうと、使われないグループ番号ができて色が飛ぶ。
    /// - `preserving` に同じ名前があれば、チェックの状態とIDを引き継ぐ。
    ///   同じグループのものを優先し、無ければ全体から1つ消費する。
    public static func parse(_ text: String, preserving old: [Item]) -> [Item] {
        var result: [Item] = []
        var group = 0
        var groupHasItem = false
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
        {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if groupHasItem { group += 1; groupHasItem = false }
                continue
            }
            result.append(Item(text: line, group: group))
            groupHasItem = true
        }

        var pool = old
        for i in result.indices {
            let match = pool.firstIndex { $0.text == result[i].text && $0.group == result[i].group }
                ?? pool.firstIndex { $0.text == result[i].text }
            guard let match else { continue }
            result[i] = Item(id: pool[match].id, text: result[i].text,
                             group: result[i].group, isPacked: pool[match].isPacked)
            pool.remove(at: match)
        }
        return result
    }
}
