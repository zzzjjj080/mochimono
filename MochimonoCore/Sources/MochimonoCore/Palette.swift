import Foundation

/// 配色。**番号で選ぶ。** 名前も説明も持たない。
///
/// 設定画面を開かずに、リストを見ながら矢印で送って決められるようにするため、
/// 「どれがどれか」を言葉で覚えさせない作りにしてある。
/// 同系色の濃淡と無彩色は、グループの切れ目が読み取りにくいので置いていない。
/// **どの番号も、色相の違うカラフルな組み合わせ。**
public struct Palette: Equatable, Hashable, Sendable {
    /// 1...count。範囲外を渡しても端で折り返す。
    public let number: Int

    public static let count = 20
    public static let first = Palette(1)

    public init(_ number: Int) {
        let wrapped = ((number - 1) % Self.count + Self.count) % Self.count + 1
        self.number = wrapped
    }

    /// 次・前。端まで行ったら反対の端へ回る。送っているうちに行き止まるのは煩わしい。
    public func next() -> Palette { Palette(number + 1) }
    public func previous() -> Palette { Palette(number - 1) }

    public static let all: [Palette] = (1...count).map(Palette.init)

    // MARK: - 調合

    /// 1つの配色の中身。色相の並びと、彩度・明度の性格だけを持つ。
    struct Recipe {
        let hues: [Double]
        let saturation: Double
        let offLight: Double
        let onLight: Double
        let offDark: Double
        let onDark: Double

        init(_ hues: [Double], _ saturation: Double,
             offLight: Double = 92, onLight: Double = 44,
             offDark: Double = 19, onDark: Double = 56) {
            self.hues = hues
            self.saturation = saturation
            self.offLight = offLight
            self.onLight = onLight
            self.offDark = offDark
            self.onDark = onDark
        }
    }

    /// 濃いめ・淡めの性格。数字を散らかさないよう、ここでまとめて持つ。
    private static let deep = (offLight: 89.0, onLight: 42.0, offDark: 17.0, onDark: 58.0)
    private static let soft = (offLight: 95.0, onLight: 60.0, offDark: 28.0, onDark: 74.0)

    static let recipes: [Recipe] = [
        /*  1 */ Recipe([210, 145, 28, 340, 265, 190, 55, 8, 300, 168], 1.00),
        /*  2 */ Recipe([262, 330, 192, 148, 44, 0, 220], 1.25,
                        offLight: deep.offLight, onLight: deep.onLight,
                        offDark: deep.offDark, onDark: deep.onDark),
        /*  3 */ Recipe([206, 148, 32, 344, 264, 188, 52, 12], 0.45),
        /*  4 */ Recipe([322, 344, 286, 204, 46, 14, 168], 1.10),
        /*  5 */ Recipe([212, 152, 34, 342, 268, 190, 54, 10], 0.80,
                        offLight: soft.offLight, onLight: soft.onLight,
                        offDark: soft.offDark, onDark: soft.onDark),
        /*  6 */ Recipe([86, 112, 142, 168, 56, 34, 196], 1.00),
        /*  7 */ Recipe([222, 150, 36, 338, 276, 192, 58, 0], 1.40,
                        offLight: deep.offLight, onLight: deep.onLight,
                        offDark: deep.offDark, onDark: deep.onDark),
        /*  8 */ Recipe([216, 242, 194, 286, 20, 340, 160], 0.70,
                        offLight: soft.offLight, onLight: soft.onLight,
                        offDark: soft.offDark, onDark: soft.onDark),
        /*  9 */ Recipe([300, 180, 60, 340, 200, 120, 20], 1.45,
                        offLight: deep.offLight, onLight: deep.onLight,
                        offDark: deep.offDark, onDark: deep.onDark),
        /* 10 */ Recipe([330, 20, 50, 160, 200, 280, 110], 0.95,
                        offLight: soft.offLight, onLight: soft.onLight,
                        offDark: soft.offDark, onDark: soft.onDark),
        /* 11 */ Recipe([196, 224, 272, 318, 352, 40, 16, 162], 1.00),
        /* 12 */ Recipe([340, 20, 60, 100, 190, 270, 150], 0.90,
                        offLight: soft.offLight, onLight: soft.onLight,
                        offDark: soft.offDark, onDark: soft.onDark),
        /* 13 */ Recipe([206, 246, 286, 326, 6, 46, 86, 126, 166], 1.00),
        /* 14 */ Recipe([348, 18, 45, 92, 300, 262, 200], 1.15),
        /* 15 */ Recipe([196, 214, 236, 172, 254, 158, 190], 1.05),
        /* 16 */ Recipe([28, 10, 45, 350, 300, 80, 190], 0.95),
        /* 17 */ Recipe([165, 186, 42, 14, 300, 256, 120], 1.30,
                        offLight: deep.offLight, onLight: deep.onLight,
                        offDark: deep.offDark, onDark: deep.onDark),
        /* 18 */ Recipe([16, 40, 352, 318, 272, 224, 196, 162], 1.00),
        /* 19 */ Recipe([100, 140, 62, 32, 16, 178, 208], 0.85),
        /* 20 */ Recipe([14, 34, 350, 320, 274, 238, 50], 1.20),
    ]

    var recipe: Recipe { Self.recipes[number - 1] }

    func hue(group g: Int) -> Double {
        let hues = recipe.hues
        return hues[((g % hues.count) + hues.count) % hues.count]
    }
}

// MARK: - 保存

extension Palette: Codable {
    /// 番号だけを書く。
    ///
    /// **昔は `"colorful"` のような文字列で保存していた。**
    /// 読めないまま落とすとリストごと失うので、古い値は近い番号に読み替える（引き継ぎ書 4-21）。
    private static let legacy: [String: Int] = [
        "colorful": 1, "vivid": 7, "pastel": 5, "muted": 3,
        "rainbow": 13, "warmCool": 18,
        "tonal": 1, "mono": 1,          // 廃止した2つは標準へ寄せる
    ]

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Int.self) { self.init(n); return }
        if let s = try? c.decode(String.self) { self.init(Self.legacy[s] ?? 1); return }
        self.init(1)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(number)
    }
}

// MARK: - 色の決定

extension Palette {
    /// そのグループの色。
    ///
    /// 白か黒かを決め打ちせず、輝度を測って読めるほうを選ぶ。
    /// そのうえで「まだ」と十分に違って見える明度を選ぶ。
    ///
    /// **「読めるまで動かす」と「まだと離すまで動かす」を順に走らせてはいけない。**
    /// 互いに押し戻して振動する。候補を走査して一度に決める。
    public func tone(group g: Int, isPacked: Bool, scheme: Scheme) -> Tone {
        let r = recipe
        let hue = hue(group: g)
        let unpackedSaturation = 58 * r.saturation
        let packedSaturation = 64 * r.saturation
        let wantOff = scheme == .dark ? r.offDark : r.offLight
        let wantOn = scheme == .dark ? r.onDark : r.onLight

        let offL = pickLightness(hue: hue, saturation: unpackedSaturation, wanted: wantOff) {
            label(hue: hue, saturation: unpackedSaturation, lightness: $0).ratio >= Contrast.text
        } ?? wantOff

        guard isPacked else { return tone(hue: hue, saturation: unpackedSaturation, lightness: offL) }

        let unpackedLuminance = Contrast.luminance(
            HSL(hue: hue, saturation: unpackedSaturation, lightness: offL))
        let readable: (Double) -> Bool = {
            label(hue: hue, saturation: packedSaturation, lightness: $0).ratio >= Contrast.text
        }
        let distinct: (Double) -> Bool = {
            let l = Contrast.luminance(HSL(hue: hue, saturation: packedSaturation, lightness: $0))
            return Contrast.ratio(l, unpackedLuminance) >= Contrast.state
        }
        let onL = pickLightness(hue: hue, saturation: packedSaturation, wanted: wantOn,
                                isAcceptable: { readable($0) && distinct($0) })
            ?? pickLightness(hue: hue, saturation: packedSaturation, wanted: wantOn,
                             isAcceptable: readable)
            ?? wantOn
        return tone(hue: hue, saturation: packedSaturation, lightness: onL)
    }

    private func tone(hue: Double, saturation: Double, lightness: Double) -> Tone {
        Tone(fill: HSL(hue: hue, saturation: saturation, lightness: lightness),
             label: label(hue: hue, saturation: saturation, lightness: lightness).color)
    }

    /// 塗りの上で読める文字色を、輝度で選ぶ。
    private func label(hue: Double, saturation s: Double, lightness l: Double)
        -> (color: HSL, ratio: Double)
    {
        let dark = HSL(hue: hue, saturation: min(45, s), lightness: 15)
        let light = HSL(hue: hue, saturation: min(38, s), lightness: 94)
        let fill = Contrast.luminance(HSL(hue: hue, saturation: s, lightness: l))
        let onDarkText = Contrast.ratio(fill, Contrast.luminance(dark))
        let onLightText = Contrast.ratio(fill, Contrast.luminance(light))
        return onDarkText >= onLightText ? (dark, onDarkText) : (light, onLightText)
    }

    /// 条件を満たす明度のうち、狙いに一番近いもの。
    private func pickLightness(hue: Double, saturation: Double, wanted: Double,
                               isAcceptable: (Double) -> Bool) -> Double?
    {
        var best: Double?
        var bestDistance = Double.infinity
        var l = 4.0
        while l <= 98 {
            defer { l += 0.5 }
            guard isAcceptable(l) else { continue }
            let d = abs(l - wanted)
            if d < bestDistance { bestDistance = d; best = l }
        }
        return best
    }
}
