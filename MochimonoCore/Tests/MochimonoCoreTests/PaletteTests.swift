import Foundation
import Testing
@testable import MochimonoCore

/// 配色。**目視で確認しない。全部測る。**
///
/// プロトタイプの段階で3回踏んだ。
/// 1. 文字色をHSLの明度で白黒に振り分けたら、112組が4.5:1未満だった
///    （黄や緑は明度が同じでも輝度が高い）
/// 2. 読めるまで明度を動かしたら、今度は「まだ」と「持った」が近づいて12組が見分けられなくなった
/// 3. 同系色とモノクロは段の向きが逆で、段が進むほど2つが近づき最後は同色になった
struct PaletteTests {

    static let schemes: [Scheme] = [.light, .dark]
    static let groups = Array(0..<10)

    @Test(arguments: Palette.allCases)
    func 文字が読める(_ palette: Palette) {
        for scheme in Self.schemes {
            for g in Self.groups {
                for packed in [false, true] {
                    let t = palette.tone(group: g, isPacked: packed, scheme: scheme)
                    let r = Contrast.ratio(t.fill, t.label)
                    #expect(r >= Contrast.text,
                            "\(palette.name)/\(scheme)/G\(g)/\(packed ? "済" : "未") = \(r)")
                }
            }
        }
    }

    @Test(arguments: Palette.allCases)
    func まだと持ったが見分けられる(_ palette: Palette) {
        for scheme in Self.schemes {
            for g in Self.groups {
                let off = palette.tone(group: g, isPacked: false, scheme: scheme)
                let on = palette.tone(group: g, isPacked: true, scheme: scheme)
                let r = Contrast.ratio(off.fill, on.fill)
                #expect(r >= Contrast.state, "\(palette.name)/\(scheme)/G\(g) = \(r)")
            }
        }
    }

    /// 隣り合うグループが同じに見えると、空行で分けた意味がなくなる。
    @Test(arguments: Palette.allCases)
    func 隣のグループと見分けられる(_ palette: Palette) {
        for scheme in Self.schemes {
            for g in 0..<5 {
                let a = palette.tone(group: g, isPacked: false, scheme: scheme).fill
                let b = palette.tone(group: g + 1, isPacked: false, scheme: scheme).fill
                let dh = min(abs(a.hue - b.hue), 360 - abs(a.hue - b.hue))
                let dl = abs(a.lightness - b.lightness)
                #expect(dh >= 10 || dl >= 5,
                        "\(palette.name)/\(scheme)/G\(g)-G\(g+1) 色差\(dh) 明度差\(dl)")
            }
        }
    }

    /// 段で分けるモードは、「まだ」と「持った」を同じ向きに動かす。
    /// 逆向きだと段が進むほど2つが近づく（実際に最小1.12まで潰れた）。
    @Test func 段は同じ向きに動く() {
        for palette in [Palette.tonal, .mono] {
            for scheme in Self.schemes {
                let off = (0..<5).map { palette.wantedLightness(group: $0, isPacked: false, scheme: scheme) }
                let on = (0..<5).map { palette.wantedLightness(group: $0, isPacked: true, scheme: scheme) }
                let offRising = off[4] > off[0]
                let onRising = on[4] > on[0]
                #expect(offRising == onRising, "\(palette.name)/\(scheme)")
            }
        }
    }

    @Test func モノクロは無彩色() {
        for scheme in Self.schemes {
            for g in 0..<5 {
                #expect(Palette.mono.tone(group: g, isPacked: true, scheme: scheme).fill.saturation == 0)
            }
        }
    }

    /// 保存に入るので、値が変わると過去のリストの配色が変わってしまう。
    @Test func 保存する名前は変えない() {
        #expect(Palette.allCases.map(\.rawValue)
                == ["colorful", "rainbow", "tonal", "warmCool", "muted", "vivid", "pastel", "mono"])
    }

    @Test func 輝度の計算が合っている() {
        let white = HSL(hue: 0, saturation: 0, lightness: 100)
        let black = HSL(hue: 0, saturation: 0, lightness: 0)
        #expect(abs(Contrast.luminance(white) - 1) < 0.001)
        #expect(abs(Contrast.luminance(black)) < 0.001)
        #expect(abs(Contrast.ratio(white, black) - 21) < 0.01)
    }
}
