import Foundation

/// 配色。違いは「グループの色をどう選ぶか」だけ。
///
/// リストごとに選べるようにしてある。街中はパステル、野球はビビッド、のように分けられる。
public enum Palette: String, Codable, CaseIterable, Identifiable, Sendable {
    case colorful, rainbow, tonal, warmCool, muted, vivid, pastel, mono

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .colorful: "カラフル"
        case .rainbow:  "にじ"
        case .tonal:    "同系色"
        case .warmCool: "暖色⇔寒色"
        case .muted:    "くすみ"
        case .vivid:    "ビビッド"
        case .pastel:   "パステル"
        case .mono:     "モノクロ"
        }
    }

    public var detail: String {
        switch self {
        case .colorful: "色を大きく飛ばす"
        case .rainbow:  "色相を順に回す"
        case .tonal:    "1色の濃淡だけで分ける"
        case .warmCool: "暖かい色から冷たい色へ"
        case .muted:    "彩度を落として静かに"
        case .vivid:    "彩度を上げて強く"
        case .pastel:   "淡くやわらかく"
        case .mono:     "無彩色。持ったものだけ目立つ"
        }
    }

    /// そのグループの色相。
    func hue(group g: Int) -> Double {
        switch self {
        case .colorful: [210, 145, 28, 340, 265, 190, 55, 8, 300, 168][g % 10]
        case .rainbow:  Double((206 + g * 40) % 360)
        case .tonal:    214
        case .warmCool: [16, 40, 352, 318, 272, 224, 196, 162][g % 8]
        case .muted:    [206, 148, 32, 344, 264, 188, 52, 12][g % 8]
        case .vivid:    [222, 150, 36, 338, 276, 192, 58, 0][g % 8]
        case .pastel:   [212, 152, 34, 342, 268, 190, 54, 10][g % 8]
        case .mono:     220
        }
    }

    var saturation: Double {
        switch self {
        case .muted:  0.42
        case .vivid:  1.4
        case .pastel: 0.8
        case .mono:   0
        default:      1
        }
    }

    /// 色相ではなく明度の段でグループを分けるか。
    var usesLightnessSteps: Bool { self == .tonal || self == .mono }

    /// 狙いの明度。段は「まだ」と「持った」を**同じ向き**に動かす。
    /// 逆向きにすると、段が進むほど2つが近づいて最後は同色になる。
    func wantedLightness(group g: Int, isPacked: Bool, scheme: Scheme) -> Double {
        let step = usesLightnessSteps ? Double(g % 5) * 6 : 0
        switch scheme {
        case .dark:  return (isPacked ? onDark  : offDark)  + step
        case .light: return (isPacked ? onLight : offLight) - step
        }
    }

    var offLight: Double { self == .vivid ? 89 : self == .pastel ? 95 : 92 }
    var onLight:  Double { self == .vivid ? 42 : self == .pastel ? 60 : 44 }
    var offDark:  Double { self == .vivid ? 17 : self == .pastel ? 28 : 19 }
    var onDark:   Double { self == .vivid ? 58 : self == .pastel ? 74 : 56 }
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

        let offL = pickLightness(
            hue: hue, saturation: unpackedSaturation,
            wanted: wantedLightness(group: g, isPacked: false, scheme: scheme),
            isAcceptable: { label(hue: hue, saturation: unpackedSaturation, lightness: $0).ratio >= Contrast.text }
        ) ?? wantedLightness(group: g, isPacked: false, scheme: scheme)

        guard isPacked else { return tone(hue: hue, saturation: unpackedSaturation, lightness: offL) }

        let unpackedLuminance = Contrast.luminance(
            HSL(hue: hue, saturation: unpackedSaturation, lightness: offL))
        let wanted = wantedLightness(group: g, isPacked: true, scheme: scheme)

        let readable: (Double) -> Bool = {
            label(hue: hue, saturation: packedSaturation, lightness: $0).ratio >= Contrast.text
        }
        let distinct: (Double) -> Bool = {
            let l = Contrast.luminance(HSL(hue: hue, saturation: packedSaturation, lightness: $0))
            return Contrast.ratio(l, unpackedLuminance) >= Contrast.state
        }

        let onL = pickLightness(hue: hue, saturation: packedSaturation, wanted: wanted,
                                isAcceptable: { readable($0) && distinct($0) })
            ?? pickLightness(hue: hue, saturation: packedSaturation, wanted: wanted,
                             isAcceptable: readable)
            ?? wanted
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
    private func pickLightness(
        hue: Double, saturation: Double, wanted: Double,
        isAcceptable: (Double) -> Bool
    ) -> Double? {
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
