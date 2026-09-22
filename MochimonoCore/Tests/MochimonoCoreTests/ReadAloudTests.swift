import Testing
@testable import MochimonoCore

@Suite("読み上げの順番")
struct ReadAloudOrderTests {
    let items = ["財布", "鍵", "スマホ", "ハンカチ"].enumerated().map {
        Item(text: $0.element, group: 0, isPacked: $0.offset == 1)   // 鍵だけ持った
    }

    @Test func 最初はまだの先頭から周の頭として読む() {
        let s = ReadAloudOrder.next(after: nil, in: items)
        #expect(s?.item.text == "財布")
        #expect(s?.startsRound == true)
    }

    @Test func 持った物は飛ばす() {
        let s = ReadAloudOrder.next(after: items[0].id, in: items)
        #expect(s?.item.text == "スマホ")
        #expect(s?.startsRound == false)
    }

    @Test func 末尾まで来たら頭へ戻る() {
        let s = ReadAloudOrder.next(after: items[3].id, in: items)
        #expect(s?.item.text == "財布")
        #expect(s?.startsRound == true)
    }

    @Test func いま読んだ物に手で印を付けても次へ進む() {
        var changed = items
        changed[2].isPacked = true
        #expect(ReadAloudOrder.next(after: changed[2].id, in: changed)?.item.text == "ハンカチ")
    }

    @Test func 残りが1つなら同じ物を読み直す() {
        var changed = items
        for i in changed.indices where i != 3 { changed[i].isPacked = true }
        let s = ReadAloudOrder.next(after: changed[3].id, in: changed)
        #expect(s?.item.text == "ハンカチ")
        #expect(s?.startsRound == true)
    }

    @Test func 編集で消えた物のあとは頭から() {
        #expect(ReadAloudOrder.next(after: Item(text: "消えた", group: 0).id, in: items)?.item.text == "財布")
    }

    @Test func そろったら読まない() {
        let all = items.map { Item(id: $0.id, text: $0.text, group: 0, isPacked: true) }
        #expect(ReadAloudOrder.next(after: nil, in: all) == nil)
    }
}

@Suite("声の合図")
struct VoiceCommandTests {
    /// 表の語をそれだけ言ったら、その合図になること。
    /// **ほかの合図の語を含んでしまう語が混ざると、ここで落ちる。**
    @Test(arguments: Language.allCases)
    func 表の語はそれぞれ自分の合図になる(_ language: Language) {
        for command in VoiceCommand.allCases {
            for word in VoiceCommands.words(command, language) {
                #expect(VoiceCommands.match(word, language: language) == command,
                        "\(language.rawValue)「\(word)」")
            }
        }
    }

    @Test(arguments: Language.allCases)
    func 全言語に4つの合図がある(_ language: Language) {
        for command in VoiceCommand.allCases {
            #expect((VoiceCommands.table[language]?[command] ?? []).count > 0, "\(language.rawValue) \(command)")
        }
    }

    @Test func 打ち消しは持ったにしない() {
        #expect(VoiceCommands.match("持ってない", language: .ja) == .next)
        #expect(VoiceCommands.match("まだ持ってない", language: .ja) == .next)
        #expect(VoiceCommands.match("I don't have it", language: .en) == .next)
        #expect(VoiceCommands.match("No, not yet", language: .en) == .next)
        #expect(VoiceCommands.match("no lo tengo", language: .es) == .next)
        #expect(VoiceCommands.match("je ne l'ai pas", language: .fr) == .next)
        #expect(VoiceCommands.match("hab ich nicht", language: .de) == .next)
        #expect(VoiceCommands.match("não tenho", language: .ptBR) == .next)
        #expect(VoiceCommands.match("还没拿", language: .zhHans) == .next)
        #expect(VoiceCommands.match("아직 없어", language: .ko) == .next)
        #expect(VoiceCommands.match("нет ещё", language: .ru) == .next)
    }

    @Test func 言い方の揺れを拾う() {
        #expect(VoiceCommands.match("持ったよ。", language: .ja) == .packed)
        #expect(VoiceCommands.match("ＯＫ", language: .ja) == .packed)
        #expect(VoiceCommands.match("Got it!", language: .en) == .packed)
        #expect(VoiceCommands.match("Okay", language: .en) == .packed)
        #expect(VoiceCommands.match("Si", language: .es) == .packed)        // アクセントを落として聞き取られても
        #expect(VoiceCommands.match("C’est bon", language: .fr) == .packed)  // 曲がった ’ でも
        #expect(VoiceCommands.match("Ja, hab ich", language: .de) == .packed)
        #expect(VoiceCommands.match("Да", language: .ru) == .packed)
        #expect(VoiceCommands.match("好了", language: .zhHans) == .packed)
        #expect(VoiceCommands.match("네", language: .ko) == .packed)
        #expect(VoiceCommands.match("نعم", language: .ar) == .packed)
    }

    @Test func 止めるともう一回() {
        #expect(VoiceCommands.match("ストップ", language: .ja) == .stop)
        #expect(VoiceCommands.match("もう一回", language: .ja) == .again)
        #expect(VoiceCommands.match("Stop please", language: .en) == .stop)
        #expect(VoiceCommands.match("Say that again", language: .en) == .again)
        #expect(VoiceCommands.match("pas encore", language: .fr) == .next)   // 「encore」だけに釣られない
    }

    @Test func 語の途中には当たらない() {
        #expect(VoiceCommands.match("now", language: .en) == nil)          // no
        #expect(VoiceCommands.match("knot", language: .en) == nil)         // not
        #expect(VoiceCommands.match("pasta", language: .it) == nil)
        #expect(VoiceCommands.match("", language: .ja) == nil)
        #expect(VoiceCommands.match("えーと", language: .ja) == nil)
    }

    @Test func 声の言語の札() {
        #expect(Language.ja.speechCode(region: "JP") == "ja-JP")
        #expect(Language.es.speechCode(region: "MX") == "es-MX")
        #expect(Language.es.speechCode(region: "JP") == "es-ES")
        #expect(Language.zhHant.speechCode(region: nil) == "zh-TW")
        #expect(Language.en.speechCode(region: "GB") == "en-GB")
    }
}
