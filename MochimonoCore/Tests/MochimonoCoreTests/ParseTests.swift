import Foundation
import Testing
@testable import MochimonoCore

/// テキストの解釈。ここが崩れると、書いたものと並ぶものが食い違う。
struct ParseTests {

    @Test func 一行一つになる() {
        let items = PackingList.parse("帽子\nソックス\nバット", preserving: [])
        #expect(items.map(\.text) == ["帽子", "ソックス", "バット"])
        #expect(items.allSatisfy { $0.group == 0 })
        #expect(items.allSatisfy { !$0.isPacked })
    }

    @Test func 空行でグループが分かれる() {
        let items = PackingList.parse("帽子\nソックス\n\nグローブ\nバット", preserving: [])
        #expect(items.map(\.group) == [0, 0, 1, 1])
    }

    /// 連続した空行・先頭や末尾の空行でグループを進めると、
    /// 使われない番号ができて色が飛ぶ。
    @Test func 余分な空行ではグループが進まない() {
        let items = PackingList.parse("\n\n帽子\n\n\n\nバット\n\n", preserving: [])
        #expect(items.map { "\($0.text):\($0.group)" } == ["帽子:0", "バット:1"])
    }

    @Test func 前後の空白は落とす() {
        let items = PackingList.parse("  帽子  \n\t バット", preserving: [])
        #expect(items.map(\.text) == ["帽子", "バット"])
    }

    @Test func 空のテキストは空になる() {
        #expect(PackingList.parse("", preserving: []).isEmpty)
        #expect(PackingList.parse("\n \n\t\n", preserving: []).isEmpty)
    }

    @Test func 改行コードが混ざっても読める() {
        let items = PackingList.parse("帽子\r\nソックス\r\r\nバット", preserving: [])
        #expect(items.map(\.text) == ["帽子", "ソックス", "バット"])
    }
}
