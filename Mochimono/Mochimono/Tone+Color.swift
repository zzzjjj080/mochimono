import SwiftUI
import MochimonoCore

extension HSL {
    var color: Color {
        let (r, g, b) = rgb
        return Color(red: r, green: g, blue: b)
    }
}

extension ColorScheme {
    var scheme: Scheme { self == .dark ? .dark : .light }
}

/// グループごとの色を1回だけ作って使い回す。
/// 明度の走査が入るので、セルごとに毎回計算させない。
struct ToneTable {
    private let table: [Int: (off: Tone, on: Tone)]

    init(palette: Palette, groups: [Int], scheme: Scheme) {
        var t: [Int: (off: Tone, on: Tone)] = [:]
        for g in groups {
            t[g] = (palette.tone(group: g, isPacked: false, scheme: scheme),
                    palette.tone(group: g, isPacked: true, scheme: scheme))
        }
        table = t
    }

    func tone(group: Int, isPacked: Bool) -> Tone {
        guard let pair = table[group] else {
            return Tone(fill: HSL(hue: 220, saturation: 0, lightness: 50),
                        label: HSL(hue: 220, saturation: 0, lightness: 100))
        }
        return isPacked ? pair.on : pair.off
    }
}
