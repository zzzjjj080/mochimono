import Foundation

/// 配色。**番号で選ぶ。** 名前も説明も持たない。
///
/// 設定画面を開かずに、リストを見ながら矢印で送って決められるようにするため、
/// 「どれがどれか」を言葉で覚えさせない作りにしてある。
///
/// **1つ送るごとに、色相が少しずつ回る。** 押すたびに全然違う色になると、
/// 目当ての色を通り過ぎてしまって選べない。
/// 一周（\(count)回）すると元に戻る。
///
/// 同系色の濃淡と無彩色は置いていない。グループの切れ目が読み取りにくいため。
/// **どの番号も、色相の違うカラフルな組み合わせ。**
public struct Palette: Equatable, Hashable, Sendable {
    /// 1...count。範囲外を渡しても端で折り返す。
    public let number: Int

    /// 一周の数。30度ずつ回して12で元に戻る。
    /// 数を増やせば1歩は細かくなるが、送り切るのに時間がかかる。
    public static let count = 12
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

    /// もとになる色の並び。**グループどうしが十分に離れるように選んである。**
    /// これを回すだけなので、どの番号でも「隣のグループと紛らわしい」は起きない。
    static let baseHues: [Double] = [210, 145, 28, 340, 265, 190, 55, 8, 300, 168]

    /// 何度回すか。
    var rotation: Double { Double(number - 1) * (360 / Double(Self.count)) }

    /// 一周のどこにいるか（-1...1）。彩度をなだらかに変えるのに使う。
    private var phase: Double { sin(2 * .pi * Double(number - 1) / Double(Self.count)) }

    /// 彩度。回転だけだと単調なので、一周のあいだで濃い側と淡い側をゆっくり往復する。
    var saturation: Double { 1.0 + 0.32 * phase }

    var offLight: Double { 92 - 2.5 * phase }
    var onLight: Double { 44 - 2.5 * phase }
    var offDark: Double { 19 + 2.0 * phase }
    var onDark: Double { 56 + 2.0 * phase }

    func hue(group g: Int) -> Double {
        let base = Self.baseHues[((g % Self.baseHues.count) + Self.baseHues.count) % Self.baseHues.count]
        return (base + rotation).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - 保存

extension Palette: Codable {
    /// 番号だけを書く。
    ///
    /// **昔は `"colorful"` のような文字列で保存していた。**
    /// 読めないまま落とすとリストごと失うので、古い値は近い番号に読み替える（引き継ぎ書 4-21）。
    private static let legacy: [String: Int] = [
        "colorful": 1, "rainbow": 1, "tonal": 1, "mono": 1,
        "vivid": 4,          // 彩度が高いあたり
        "pastel": 10, "muted": 10,   // 彩度が低いあたり
        "warmCool": 7,
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
        let hue = hue(group: g)
        let unpackedSaturation = 58 * saturation
        let packedSaturation = 64 * saturation
        let wantOff = scheme == .dark ? offDark : offLight
        let wantOn = scheme == .dark ? onDark : onLight

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
