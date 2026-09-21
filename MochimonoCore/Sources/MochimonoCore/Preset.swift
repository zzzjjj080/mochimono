import Foundation

/// はじめから用意しておくリストの雛形。
///
/// 白紙から書き始めるのは難しい。**「近いものを持ってきて、要らない行を消す」ほうが速い。**
/// 選んだ時点でただのリストになるので、あとは好きに書き換えられる（雛形とは繋がらない）。
public struct Preset: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    /// 何のためのリストかの一言。名前だけでは中身が想像できない。
    public let detail: String
    public let text: String
    public let palette: Palette
    public let columns: Columns

    public init(id: String, name: String, detail: String,
                palette: Palette, columns: Columns = .four, text: String) {
        self.id = id
        self.name = name
        self.detail = detail
        self.text = text
        self.palette = palette
        self.columns = columns
    }

    /// 雛形から実際のリストを作る。以後は雛形と関係なく編集できる。
    public func makeList() -> PackingList {
        PackingList(name: name, text: text, columns: columns, palette: palette)
    }

    /// 中身を見せるための下ごしらえ。
    public var items: [Item] { PackingList.parse(text, preserving: []) }

    /// 使われているグループ番号。順番どおり。
    public var groups: [Int] {
        var seen = Set<Int>()
        return items.map(\.group).filter { seen.insert($0).inserted }
    }
}

extension Preset {
    /// 項目名の上限。4列だと長い名前は縮んで読みにくい。
    /// **中日韓は8文字、それ以外は20文字。** 1文字の幅がまるで違うので、同じ数では決められない。
    /// この上限は `PresetTests` と `Tools-GenCore.py` の両方で機械的に守る。
    public static func maxItemLength(_ language: Language) -> Int { language.isCJK ? 8 : 20 }

    /// その言語の雛形。**中身は `translations/core.json`**（生成物 `Core.generated.swift`）。
    /// どの言語でも id・配色・並び順は同じ。
    public static func all(_ language: Language) -> [Preset] { table(language) }

    public static func preset(id: String, language: Language) -> Preset? {
        all(language).first { $0.id == id }
    }
}
