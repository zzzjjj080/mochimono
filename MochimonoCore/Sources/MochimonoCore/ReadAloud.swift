import Foundation

/// 読み上げの順番。**まだの物だけを、盤面の並び順に、ぐるぐる回す。**
///
/// 1周したら先頭のまだの物へ戻る。手で付けた物・声で付けた物は、次の周から自然に抜ける。
/// 手ぶらで準備している人は画面を見ないので、「どこまで読んだか」を覚えるのはこちらの役目。
public enum ReadAloudOrder {
    public struct Step: Equatable, Sendable {
        public let item: Item
        /// 周の頭か。頭では「残り◯個」を先に言う。
        public let startsRound: Bool

        public init(item: Item, startsRound: Bool) {
            self.item = item
            self.startsRound = startsRound
        }
    }

    /// `current` の次に読む物。`current` が無い（最初・消えた）ときは先頭から。
    /// まだの物が1つも無ければ nil（そろった）。
    public static func next(after current: Item.ID?, in items: [Item]) -> Step? {
        let pending = items.filter { !$0.isPacked }
        guard let first = pending.first else { return nil }
        guard let current, let at = items.firstIndex(where: { $0.id == current }) else {
            return Step(item: first, startsRound: true)
        }
        if let later = items[(at + 1)...].first(where: { !$0.isPacked }) {
            return Step(item: later, startsRound: false)
        }
        return Step(item: first, startsRound: true)          // 末尾まで来たので、頭へ戻る
    }
}

/// 読み上げ中に声で返す合図。
public enum VoiceCommand: String, CaseIterable, Sendable {
    /// 持った。いま読んだ物に印を付ける
    case packed
    /// まだ・飛ばす。印を付けずに次へ
    case next
    /// もう一回言って
    case again
    /// 読み上げを終える
    case stop
}

/// 聞き取った言葉から合図を拾う。
///
/// **これは画面に出す文言ではなく、聞き分けるための語の表。** 訳の置き場（`translations/`）ではなく、
/// テストと一緒にここへ置く。語を足すときは、ほかの合図の語を含んでしまわないか必ず確かめる
/// （フランス語の「pas encore（まだ）」が「encore（もう一回）」に当たる、など）。
public enum VoiceCommands {
    /// 見る順番。**打ち消し（まだ・ない）を「持った」より先に見る。**
    /// 「持ってない」「no tengo」を「持った」と取り違えると、持っていない物に印が付く。
    static let priority: [VoiceCommand] = [.stop, .again, .next, .packed]

    public static func match(_ heard: String, language: Language) -> VoiceCommand? {
        let text = normalize(heard, language: language)
        guard !text.isEmpty else { return nil }
        for command in priority {
            for word in words(command, language) {
                let w = normalize(word, language: language)
                if language.isCJK ? text.contains(w) : " \(text) ".contains(" \(w) ") {
                    return command
                }
            }
        }
        return nil
    }

    /// 聞き取りを助けるために渡す語（`contextualStrings`）。
    public static func allWords(_ language: Language) -> [String] {
        VoiceCommand.allCases.flatMap { words($0, language) }
    }

    /// 大小・幅・記号の揺れをならす。
    ///
    /// 中日韓は語の区切りに空白を使わないので、空白も記号も消して部分一致で見る。
    /// それ以外は語の単位で見る（「no」が「now」に当たらないように）。
    /// **中日韓では濁点を落とさない。** 落とすと「パス」が「ハス」になり、別の語に当たりやすくなる。
    static func normalize(_ s: String, language: Language) -> String {
        let options: String.CompareOptions = language.isCJK
            ? [.caseInsensitive, .widthInsensitive]
            : [.caseInsensitive, .widthInsensitive, .diacriticInsensitive]
        let folded = s.replacingOccurrences(of: "’", with: "'")
            .folding(options: options, locale: nil)
        let kept = folded.unicodeScalars.map { c -> String in
            if CharacterSet.letters.contains(c) || CharacterSet.decimalDigits.contains(c)
                || CharacterSet.nonBaseCharacters.contains(c) || c == "'" { return String(c) }
            return " "
        }.joined()
        if language.isCJK { return kept.replacingOccurrences(of: " ", with: "") }
        return kept.split(separator: " ").joined(separator: " ")
    }

    public static func words(_ command: VoiceCommand, _ language: Language) -> [String] {
        table[language]?[command] ?? table[.en]![command]!
    }

    static let table: [Language: [VoiceCommand: [String]]] = [
        .ja: [
            .packed: ["持った", "もった", "持ってる", "もってる", "ある", "あった", "入れた", "いれた",
                      "よし", "ヨシ", "オッケー", "OK", "はい", "済み", "すみ"],
            .next: ["次", "つぎ", "パス", "スキップ", "まだ", "ない", "あとで", "後で"],
            .again: ["もう一回", "もういっかい", "もう一度", "もういちど", "何", "なに"],
            .stop: ["止めて", "とめて", "止める", "とめる", "ストップ", "終わり", "おわり", "終了", "やめ"],
        ],
        .en: [
            .packed: ["got it", "got", "yes", "yeah", "yep", "ok", "okay", "check", "done", "packed", "have it"],
            .next: ["next", "skip", "pass", "no", "nope", "not", "don't", "haven't", "not yet", "later"],
            .again: ["again", "repeat", "what", "pardon", "sorry"],
            .stop: ["stop", "quit", "finish", "end", "that's all"],
        ],
        .zhHans: [
            .packed: ["好了", "有了", "拿了", "带了", "收到", "可以", "好", "是", "对", "OK"],
            .next: ["下一个", "跳过", "没有", "还没", "没", "不", "等下"],
            .again: ["再说一遍", "再说一次", "重复", "什么"],
            .stop: ["停", "停止", "结束"],
        ],
        .zhHant: [
            .packed: ["好了", "有了", "拿了", "帶了", "收到", "可以", "好", "是", "對", "OK"],
            .next: ["下一個", "跳過", "沒有", "還沒", "沒", "不", "等下"],
            .again: ["再說一遍", "再說一次", "重複", "什麼"],
            .stop: ["停", "停止", "結束"],
        ],
        .ko: [
            .packed: ["됐어", "챙겼어", "있어", "네", "응", "예", "오케이", "좋아", "완료", "OK"],
            .next: ["다음", "패스", "없어", "아직", "건너뛰어"],
            .again: ["다시", "한번 더", "뭐"],
            .stop: ["그만", "멈춰", "정지", "끝"],
        ],
        .es: [
            .packed: ["sí", "listo", "lo tengo", "tengo", "vale", "ok", "hecho", "ya"],
            .next: ["siguiente", "paso", "salta", "no", "todavía no", "luego"],
            .again: ["otra vez", "repite", "qué", "cómo"],
            .stop: ["para", "parar", "stop", "basta", "fin", "terminar"],
        ],
        .fr: [
            .packed: ["oui", "ok", "c'est bon", "bon", "j'ai", "pris", "fait", "d'accord", "voilà"],
            .next: ["suivant", "passe", "non", "pas", "pas encore", "plus tard"],
            .again: ["répète", "répéter", "encore une fois", "quoi", "pardon", "comment"],
            .stop: ["stop", "arrête", "arrêter", "fini", "terminé"],
        ],
        .de: [
            .packed: ["ja", "ok", "okay", "hab ich", "habe ich", "erledigt", "gepackt", "fertig", "passt", "check"],
            .next: ["weiter", "nächste", "nächstes", "nein", "nicht", "kein", "noch nicht", "später", "überspringen"],
            .again: ["nochmal", "noch mal", "wiederholen", "wie bitte", "was"],
            .stop: ["stopp", "stop", "halt", "aufhören", "ende", "beenden"],
        ],
        .it: [
            .packed: ["sì", "ok", "fatto", "preso", "ce l'ho", "va bene", "pronto", "certo"],
            .next: ["prossimo", "avanti", "salta", "no", "non", "non ancora", "dopo"],
            .again: ["ripeti", "ancora una volta", "cosa", "come"],
            .stop: ["stop", "basta", "fine", "ferma", "fermati"],
        ],
        .ptBR: [
            .packed: ["sim", "ok", "peguei", "tenho", "pronto", "feito", "beleza", "certo", "já"],
            .next: ["próximo", "pula", "pular", "não", "ainda não", "depois"],
            .again: ["repete", "de novo", "o quê", "como"],
            .stop: ["para", "parar", "pare", "chega", "fim", "stop"],
        ],
        .ru: [
            .packed: ["да", "есть", "взял", "взяла", "готово", "положил", "положила", "хорошо", "ок", "окей"],
            .next: ["дальше", "следующий", "следующее", "пропусти", "нет", "не", "ещё нет", "потом"],
            .again: ["повтори", "ещё раз", "что"],
            .stop: ["стоп", "хватит", "конец", "закончить", "остановись"],
        ],
        .ar: [
            .packed: ["نعم", "أجل", "تمام", "حسنا", "موجود", "أخذته", "جاهز", "خلاص", "أوكي", "ok"],
            .next: ["التالي", "تخطى", "تخطي", "لا", "ليس بعد", "لاحقا", "بعدين"],
            .again: ["أعد", "كرر", "مرة أخرى", "ماذا"],
            .stop: ["توقف", "قف", "كفى", "انتهى", "إنهاء"],
        ],
    ]
}

extension Language {
    /// 読み上げと聞き取りに使う言語の札（BCP 47）。
    /// スペイン語とポルトガル語は、端末の地域が合えばそちらの声にする（メキシコの人にスペインの発音を当てない）。
    public func speechCode(region: String?) -> String {
        switch self {
        case .ja: return "ja-JP"
        case .en: return ["GB", "AU", "IN", "IE", "ZA"].contains(region ?? "") ? "en-\(region!)" : "en-US"
        case .zhHans: return "zh-CN"
        case .zhHant: return region == "HK" ? "zh-HK" : "zh-TW"
        case .ko: return "ko-KR"
        case .es: return ["MX", "US", "AR", "CO", "CL"].contains(region ?? "") ? "es-\(region!)" : "es-ES"
        case .fr: return region == "CA" ? "fr-CA" : "fr-FR"
        case .de: return "de-DE"
        case .it: return "it-IT"
        case .ptBR: return "pt-BR"
        case .ru: return "ru-RU"
        case .ar: return "ar-SA"
        }
    }
}
