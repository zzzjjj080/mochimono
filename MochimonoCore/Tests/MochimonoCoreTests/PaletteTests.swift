import Foundation
import Testing
@testable import MochimonoCore

/// 配色。**目視で確認しない。全部測る。**
///
/// プロトタイプの段階で3回踏んだ。
/// 1. 文字色をHSLの明度で白黒に振り分けたら、112組が4.5:1未満だった
///    （黄や緑は明度が同じでも輝度が高い）
/// 2. 読めるまで明度を動かしたら、今度は「まだ」と「持った」が近づいて見分けられなくなった
/// 3. 段で分ける配色は、段が進むほど2つが近づいて最後は同色になった
///    → 同系色の濃淡と無彩色そのものを廃止した
struct PaletteTests {

    static let schemes: [Scheme] = [.light, .dark]
    static let groups = Array(0..<10)

    @Test func 番号は1から一周ぶん() {
        #expect(Palette.count == 12)
        #expect(Palette.all.map(\.number) == Array(1...Palette.count))
    }

    /// 一周すると元の色に戻る。送り続けても迷子にならない。
    @Test func 一周すると戻る() {
        var p = Palette(1)
        for _ in 0..<Palette.count { p = p.next() }
        #expect(p == Palette(1))
        for g in 0..<6 {
            #expect(abs(Palette(1).hue(group: g) - p.hue(group: g)) < 0.001)
        }
    }

    /// 端まで送ったら反対の端へ回る。行き止まると送り続けられない。
    @Test func 端で折り返す() {
        #expect(Palette(1).previous() == Palette(Palette.count))
        #expect(Palette(Palette.count).next() == Palette(1))
        #expect(Palette(0) == Palette(Palette.count))
        #expect(Palette(Palette.count + 1) == Palette(1))
        #expect(Palette(-1) == Palette(Palette.count - 1))
    }

    @Test(arguments: Palette.all)
    func 文字が読める(_ palette: Palette) {
        for scheme in Self.schemes {
            for g in Self.groups {
                for packed in [false, true] {
                    let t = palette.tone(group: g, isPacked: packed, scheme: scheme)
                    let r = Contrast.ratio(t.fill, t.label)
                    #expect(r >= Contrast.text,
                            "配色\(palette.number)/\(scheme)/G\(g)/\(packed ? "済" : "未") = \(r)")
                }
            }
        }
    }

    @Test(arguments: Palette.all)
    func まだと持ったが見分けられる(_ palette: Palette) {
        for scheme in Self.schemes {
            for g in Self.groups {
                let off = palette.tone(group: g, isPacked: false, scheme: scheme)
                let on = palette.tone(group: g, isPacked: true, scheme: scheme)
                let r = Contrast.ratio(off.fill, on.fill)
                #expect(r >= Contrast.state, "配色\(palette.number)/\(scheme)/G\(g) = \(r)")
            }
        }
    }

    /// 隣り合うグループが同じに見えると、空行で分けた意味がなくなる。
    @Test(arguments: Palette.all)
    func 隣のグループと見分けられる(_ palette: Palette) {
        for g in 0..<5 {
            let a = palette.hue(group: g), b = palette.hue(group: g + 1)
            let dh = min(abs(a - b), 360 - abs(a - b))
            #expect(dh >= 12, "配色\(palette.number)/G\(g)-G\(g+1) 色相差\(dh)")
        }
    }

    /// **同系色の濃淡は置かない。** グループの切れ目が読み取りにくいと分かったため。
    /// どの配色も、6グループ使ったときに色相が十分に散っていること。
    @Test(arguments: Palette.all)
    func 色相が散っている(_ palette: Palette) {
        #expect(Palette.baseHues.count >= 6, "色数が足りない")
        let hues = (0..<6).map { palette.hue(group: $0) }
        let spread = hues.max()! - hues.min()!
        #expect(spread >= 90, "配色\(palette.number) の色相の広がりが \(spread) しかない")
    }

    /// **無彩色は置かない。** 持ったものだけが目立つ代わりに、グループが読めなくなる。
    @Test(arguments: Palette.all)
    func 無彩色ではない(_ palette: Palette) {
        #expect(palette.saturation >= 0.6, "配色\(palette.number) の彩度が低すぎる")
        for scheme in Self.schemes {
            let t = palette.tone(group: 0, isPacked: true, scheme: scheme)
            #expect(t.fill.saturation > 0, "配色\(palette.number)/\(scheme)")
        }
    }

    /// 番号ごとに違って見えること。同じ色の並びが2つあると、送っても変わらない番号ができる。
    @Test func 番号ごとに違う配色になっている() {
        var seen: [[Double]: Int] = [:]
        for p in Palette.all {
            let key = (0..<6).map { p.hue(group: $0) }
            if let other = seen[key] {
                Issue.record("配色\(p.number) と 配色\(other) の色の並びが同じ")
            }
            seen[key] = p.number
        }
    }

    /// **隣り合う番号は「少しずつ」違うこと。**
    /// 押すたびに全然違う色になると、目当ての色を通り過ぎて選べない。
    /// かといって同じでは押す意味がない。**上と下の両方を見る。**
    /// 端から端へ回るので、最後と最初の間も見る。
    @Test func 隣の番号は少しずつ変わる() {
        func hueDistance(_ a: Double, _ b: Double) -> Double {
            let d = abs(a - b).truncatingRemainder(dividingBy: 360)
            return min(d, 360 - d)
        }
        /// 色相の平均差を主に、彩度と明るさの性格差を足したもの。
        func distance(_ a: Palette, _ b: Palette) -> Double {
            let hue = (0..<6).map { hueDistance(a.hue(group: $0), b.hue(group: $0)) }
                .reduce(0, +) / 6
            let sat = abs(log(a.saturation / b.saturation)) * 60
            let light = abs(a.offLight - b.offLight) * 1.2
            return hue + sat + light
        }
        for i in 0..<Palette.count {
            let a = Palette(i + 1), b = a.next()
            let d = distance(a, b)
            #expect(d >= 20, "配色\(a.number)と配色\(b.number)が同じすぎる（\(d)）")
            #expect(d <= 60, "配色\(a.number)と配色\(b.number)が離れすぎ。1歩で変わりすぎる（\(d)）")
        }

        // どの2つも、同じには見えないこと（意味のない番号を作らない）
        for i in 1..<Palette.count {          // 最後の番号から始めると範囲が逆になる
            for j in (i + 1)...Palette.count {
                let d = distance(Palette(i), Palette(j))
                #expect(d >= 20, "配色\(i)と配色\(j)が同じすぎる（\(d)）")
            }
        }
    }

    /// 保存には番号が入る。文字列で保存していた頃のデータも読めること。
    @Test func 番号で保存され_古い文字列も読める() throws {
        let data = try JSONEncoder().encode(Palette(7))
        #expect(String(data: data, encoding: .utf8) == "7")
        #expect(try JSONDecoder().decode(Palette.self, from: data) == Palette(7))

        // 昔の名前は「近い性格の番号」へ寄せてある
        for (old, expected) in [("colorful", 1), ("rainbow", 1), ("tonal", 1), ("mono", 1),
                                ("vivid", 4), ("pastel", 10), ("muted", 10), ("warmCool", 7)] {
            let json = Data("\"\(old)\"".utf8)
            #expect(try JSONDecoder().decode(Palette.self, from: json) == Palette(expected),
                    "古い値 \(old)")
        }
        // 見覚えのない値でも落とさない
        #expect(try JSONDecoder().decode(Palette.self, from: Data("\"nazo\"".utf8)) == Palette(1))
    }

    @Test func 輝度の計算が合っている() {
        let white = HSL(hue: 0, saturation: 0, lightness: 100)
        let black = HSL(hue: 0, saturation: 0, lightness: 0)
        #expect(abs(Contrast.luminance(white) - 1) < 0.001)
        #expect(abs(Contrast.luminance(black)) < 0.001)
        #expect(abs(Contrast.ratio(white, black) - 21) < 0.01)
    }
}

extension Palette: CustomTestStringConvertible {
    public var testDescription: String { "配色\(number)" }
}
