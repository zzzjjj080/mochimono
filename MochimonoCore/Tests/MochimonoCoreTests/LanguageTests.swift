import Foundation
import Testing
@testable import MochimonoCore

/// 端末の言語から、どの訳を出すかを決める。
struct LanguageTests {

    /// 中国語とポルトガル語は、言語コードだけでは決まらない（引き継ぎ書 4-158）。
    @Test(arguments: [
        ("ja-JP", Language.ja), ("en-US", .en), ("en-GB", .en),
        ("zh-Hans-CN", .zhHans), ("zh-Hant-TW", .zhHant), ("zh-TW", .zhHant), ("zh-HK", .zhHant),
        ("zh-CN", .zhHans), ("ko-KR", .ko), ("es-MX", .es), ("fr-CA", .fr), ("de-AT", .de),
        ("it-IT", .it), ("pt-BR", .ptBR), ("pt-PT", .en), ("ru-RU", .ru), ("ar-SA", .ar),
        ("sv-SE", .en), ("th-TH", .en),
    ])
    func 端末の言語から決まる(_ id: String, _ expected: Language) {
        #expect(Language.forLocale(Locale(identifier: id)) == expected, "\(id)")
    }

    /// 画面の言語（Bundle の preferredLocalizations）の書き方でも引けること。
    @Test func 画面の言語の書き方でも引ける() {
        #expect(Language.forLocalization("zh-Hant") == .zhHant)
        #expect(Language.forLocalization("zh-Hans") == .zhHans)
        #expect(Language.forLocalization("pt-BR") == .ptBR)
        #expect(Language.forLocalization("ja") == .ja)
        #expect(Language.forLocalization(nil) == .en)
    }

    /// 文言は全言語そろっている。欠けると英語に落ちて、1語だけ英語が混ざる。
    @Test(arguments: Language.allCases)
    func Coreの文言は全言語そろっている(_ language: Language) {
        for key in CoreText.Key.allCases {
            #expect(CoreText.table[key]?[language]?.isEmpty == false, "\(key)/\(language)")
        }
    }

    /// 書式の差し込みが合っていないと実行時に落ちる。組み立てて、名前が入ることまで見る。
    @Test(arguments: Language.allCases)
    func 複製の名前が組み立てられる(_ language: Language) {
        let one = String(format: CoreText.get(.copyOf, language), "Tile")
        let two = String(format: CoreText.get(.copyOfNumbered, language), "Tile", 2)
        #expect(one.contains("Tile") && one != "Tile")
        #expect(two.contains("Tile") && two.contains("2"))
    }

    @Test(arguments: Language.allCases)
    func 明るさの名前が3つとも違う(_ language: Language) {
        let names = Appearance.allCases.map { $0.label(language) }
        #expect(Set(names).count == 3, "\(language): \(names)")
    }
}
