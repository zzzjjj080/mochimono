import Foundation

/// 色は HSL で持つ。UIには依存しない（Core は SwiftUI を読まない）。
///
/// **HSLの明度は「明るく見えるか」ではない。** 同じ明度でも黄や緑は眩しく、
/// 青や紫は沈む。文字が読めるかどうかは、必ず `Contrast` で測ること。
public struct HSL: Equatable, Hashable, Sendable {
    public var hue: Double          // 0..<360
    public var saturation: Double   // 0...100
    public var lightness: Double    // 0...100

    public init(hue: Double, saturation: Double, lightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }

    /// 0...1 のRGB。
    public var rgb: (red: Double, green: Double, blue: Double) {
        let s = saturation / 100, l = lightness / 100
        let a = s * min(l, 1 - l)
        func f(_ n: Double) -> Double {
            let k = (n + hue / 30).truncatingRemainder(dividingBy: 12)
            return l - a * max(-1, min(k - 3, min(9 - k, 1)))
        }
        return (f(0), f(8), f(4))
    }
}

/// 塗りと、その上に載せる文字の組。
public struct Tone: Equatable, Hashable, Sendable {
    public var fill: HSL
    public var label: HSL
    public init(fill: HSL, label: HSL) { self.fill = fill; self.label = label }
}

/// コントラストの実測。**目視で決めない。**
public enum Contrast {
    /// 文字が読める下限（WCAG AA）。
    public static let text = 4.5
    /// 「まだ」と「持った」が見分けられる下限。
    public static let state = 2.0

    public static func luminance(_ c: HSL) -> Double {
        func lin(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = c.rgb
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    public static func ratio(_ a: HSL, _ b: HSL) -> Double {
        ratio(luminance(a), luminance(b))
    }

    public static func ratio(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// 明暗。`Appearance` と違い、こちらは「いま実際にどちらで描くか」の確定値。
public enum Scheme: Sendable { case light, dark }

/// 設定としての明暗。`system` は端末の設定に従う。
public enum Appearance: String, Codable, CaseIterable, Sendable {
    case system, light, dark
    public var label: String {
        switch self {
        case .system: "自動"
        case .light:  "ライト"
        case .dark:   "ダーク"
        }
    }
}
