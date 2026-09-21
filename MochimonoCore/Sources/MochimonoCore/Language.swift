import Foundation

/// 画面と雛形を出す言語。
///
/// **訳はコードに直書きしない。** 雛形と Core の文言は `translations/core.json`、
/// 画面の文言は String Catalog に置く（引き継ぎ書 4-158）。
public enum Language: String, Codable, Sendable, CaseIterable {
    case ja, en
    case zhHans = "zh-Hans", zhHant = "zh-Hant"
    case ko, es, fr, de, it
    case ptBR = "pt-BR"
    case ru, ar

    /// 訳が無いときに落ちる先。英語は必ず全項目そろえてある。
    public static let fallback: Language = .en

    /// 漢字・かな・ハングルの言語。1文字の幅が広いので、項目名の上限を別に持つ。
    public var isCJK: Bool { [.ja, .zhHans, .zhHant, .ko].contains(self) }

    /// 端末の言語から決める。訳を持たない言語は英語にする。
    ///
    /// 中国語とポルトガル語は、地域まで見ないと簡体字か繁体字か、ブラジルか欧州かが決まらない。
    /// `languageCode` だけで振り分けると、台湾の端末に簡体字を出してしまう。（引き継ぎ書 4-158）
    public static func forLocale(_ locale: Locale) -> Language {
        guard let code = locale.language.languageCode?.identifier else { return fallback }
        switch code {
        case "zh":
            if let script = locale.language.script?.identifier {
                return script == "Hant" ? .zhHant : .zhHans
            }
            let region = locale.language.region?.identifier ?? ""
            return ["TW", "HK", "MO"].contains(region) ? .zhHant : .zhHans
        case "pt":
            return locale.language.region?.identifier == "BR" ? .ptBR : fallback
        default:
            return Language(rawValue: code) ?? fallback
        }
    }

    /// アプリが実際に出している言語から決める。
    ///
    /// **`Locale.current` は使わない。** あちらは日付や数字の書式の地域で、
    /// 画面の言語とは限らない（英語の画面で地域だけ日本、はよくある）。
    /// 画面は String Catalog が `preferredLocalizations` で選ぶので、雛形も同じものに合わせる。
    /// 合わせないと、英語の画面に日本語の雛形が並ぶ。
    public static func forLocalization(_ identifier: String?) -> Language {
        forLocale(Locale(identifier: identifier ?? fallback.rawValue))
    }
}

/// Core が持つ文言。中身は生成物 `Core.generated.swift` の表。
public enum CoreText {
    public enum Key: String, CaseIterable, Sendable {
        case untitledList, newList, copyOf, copyOfNumbered
        case appearanceSystem, appearanceLight, appearanceDark
    }

    /// その言語に無ければ英語、それも無ければキーをそのまま返す。
    /// 訳し終えていない言語があっても、画面が空にならない。
    public static func get(_ key: Key, _ language: Language) -> String {
        table[key]?[language] ?? table[key]?[.fallback] ?? key.rawValue
    }
}
