import Foundation
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

@Suite("読み上げの間隔")
struct ReadAloudGapTests {
    @Test func 既定は段のどれか() {
        #expect(ReadAloudGap.steps.contains(ReadAloudGap.default))
    }

    @Test func 既定は最短() {
        #expect(ReadAloudGap.default == 0.3)
        #expect(ReadAloudGap.isShortest(ReadAloudGap.default))
    }

    @Test func 周の切れ目は間の3倍() {
        let head = ReadAloudOrder.Step(item: Item(text: "財布", group: 0), startsRound: true)
        let middle = ReadAloudOrder.Step(item: Item(text: "鍵", group: 0), startsRound: false)
        #expect(ReadAloudGap.pause(before: head, isFirst: false, gap: 0.3) == 0.3 * 3)
        #expect(ReadAloudGap.pause(before: middle, isFirst: false, gap: 0.3) == 0.3)
        #expect(ReadAloudGap.pause(before: head, isFirst: true, gap: 0.3) == 0)   // 押してすぐ読む
        #expect(ReadAloudGap.pause(before: head, isFirst: false, gap: 2) == 6)
    }

    @Test func 一段ずつ送る() {
        #expect(ReadAloudGap.step(1, longer: true) == 1.5)
        #expect(ReadAloudGap.step(1, longer: false) == 0.8)
    }

    @Test func 端では止まる() {
        #expect(ReadAloudGap.step(0.3, longer: false) == 0.3)
        #expect(ReadAloudGap.step(5, longer: true) == 5)
        #expect(ReadAloudGap.isShortest(0.3))
        #expect(ReadAloudGap.isLongest(5))
    }

    @Test func 段に無い値は近い段に寄せる() {
        #expect(ReadAloudGap.snapped(3.5) == 3)
        #expect(ReadAloudGap.snapped(0) == 0.3)
        #expect(ReadAloudGap.step(1.2, longer: true) == 1.5)
    }

    @Test func 保存しておける() throws {
        var store = Store()
        #expect(store.readAloudGap == ReadAloudGap.default)
        store.readAloudGap = 2
        let back = try JSONDecoder().decode(Store.self, from: JSONEncoder().encode(store))
        #expect(back.readAloudGap == 2)
    }

    /// 1.2 までの保存（間隔の項目が無い）を読んでも既定になる
    @Test func 古い保存は既定になる() throws {
        let old = #"{"appearance":"dark","lists":[]}"#.data(using: .utf8)!
        let store = try JSONDecoder().decode(Store.self, from: old)
        #expect(store.readAloudGap == ReadAloudGap.default)
        #expect(store.appearance == .dark)
    }
}

@Suite("声の言語")
struct SpeechCodeTests {
    @Test func 声の言語の札() {
        #expect(Language.ja.speechCode(region: "JP") == "ja-JP")
        #expect(Language.es.speechCode(region: "MX") == "es-MX")
        #expect(Language.es.speechCode(region: "JP") == "es-ES")
        #expect(Language.zhHant.speechCode(region: nil) == "zh-TW")
        #expect(Language.en.speechCode(region: "GB") == "en-GB")
    }
}

@Suite("声の選択肢")
struct VoiceMenuTests {
    typealias V = VoiceMenu.Voice
    // 実際の iPhone の日本語：自然な声は Kyoko だけ、残りは Eloquence（性別が返らない）
    let kyoko = V(id: "com.apple.voice.compact.ja-JP.Kyoko", name: "Kyoko", quality: .standard, gender: .female)
    let eddy = V(id: "com.apple.eloquence.ja-JP.Eddy", name: "Eddy", quality: .standard)
    let reed = V(id: "com.apple.eloquence.ja-JP.Reed", name: "Reed", quality: .standard)
    let flo = V(id: "com.apple.eloquence.ja-JP.Flo", name: "Flo", quality: .standard)
    let grandpa = V(id: "com.apple.eloquence.ja-JP.Grandpa", name: "Grandpa", quality: .standard)
    let otoya = V(id: "com.apple.voice.enhanced.ja-JP.Otoya", name: "Otoya", quality: .enhanced, gender: .male)
    let bahh = V(id: "com.apple.speech.synthesis.voice.Bahh", name: "Bahh", quality: .standard)

    var iphone: [V] { [eddy, flo, grandpa, kyoko, reed] }

    @Test func いつでも5つで全部違う() {
        for voices in [[], [kyoko], iphone, iphone + [otoya]] {
            let v = VoiceMenu.variants(voices: voices, preferred: voices.first?.id)
            #expect(v.count == 5)
            #expect(Set(v).count == 5)
        }
    }

    @Test func 一番はいままでの声のまま() {
        let v = VoiceMenu.variants(voices: iphone, preferred: kyoko.id)
        #expect(v[0] == .init(voiceID: kyoko.id, pitch: 1, rate: 1))
    }

    let rocko = V(id: "com.apple.eloquence.ja-JP.Rocko", name: "Rocko", quality: .standard)

    @Test func 二番は明るい男() {
        let v = VoiceMenu.variants(voices: iphone, preferred: kyoko.id)
        #expect(v[1].voiceID == eddy.id)                     // 性別は名前で補う
        #expect(v[1].pitch > 1)                              // 暗くしない
    }

    @Test func 男は自然な声があればそちらを先に() {
        let v = VoiceMenu.variants(voices: iphone + [otoya], preferred: kyoko.id)
        #expect(v[1].voiceID == otoya.id)
    }

    @Test func 三番はいつもの声のまま速く() {
        let v = VoiceMenu.variants(voices: iphone, preferred: kyoko.id)
        #expect(v[2].voiceID == kyoko.id)
        #expect(v[2].rate >= 1.25)
        #expect(v[2].rate > v[1].rate && v[2].rate > v[3].rate)   // いちばん速い
    }

    @Test func 四番は可愛い女の子で自然な声を使う() {
        let v = VoiceMenu.variants(voices: iphone, preferred: kyoko.id)
        #expect(v[3].voiceID == kyoko.id)                          // 機械声の Flo より Kyoko
        #expect(v[3].pitch >= 1.5)
    }

    @Test func 五番はロボット() {
        #expect(VoiceMenu.variants(voices: iphone + [rocko], preferred: kyoko.id)[4].voiceID == rocko.id)
        let v = VoiceMenu.variants(voices: iphone, preferred: kyoko.id)[4]
        #expect(v.voiceID?.hasPrefix("com.apple.eloquence.") == true)   // Rocko が無くても機械声
        #expect(v.pitch > 1)
    }

    @Test func 機械声が無ければ五番は低くゆっくり() {
        let v = VoiceMenu.variants(voices: [kyoko], preferred: kyoko.id)[4]
        #expect(v.voiceID == kyoko.id)
        #expect(v.pitch < 1 && v.rate < 1)
    }

    @Test func 年寄りと効果音の声は使わない() {
        let v = VoiceMenu.variants(voices: iphone + [bahh], preferred: kyoko.id)
        #expect(!v.contains { $0.voiceID == grandpa.id || $0.voiceID == bahh.id })
    }

    @Test func 男の声が無ければ既定の声で埋める() {
        let v = VoiceMenu.variants(voices: [kyoko], preferred: kyoko.id)
        #expect(v.allSatisfy { $0.voiceID == kyoko.id })
    }

    @Test func 送ると一周する() {
        #expect(VoiceMenu.step(4, forward: true) == 0)
        #expect(VoiceMenu.step(0, forward: false) == 4)
        #expect(VoiceMenu.step(1, forward: true) == 2)
    }

    @Test func 声の番号を保存しておける() throws {
        var store = Store()
        #expect(store.readAloudVoice == 0)
        store.readAloudVoice = 3
        let back = try JSONDecoder().decode(Store.self, from: JSONEncoder().encode(store))
        #expect(back.readAloudVoice == 3)
        let old = try JSONDecoder().decode(Store.self, from: #"{"lists":[]}"#.data(using: .utf8)!)
        #expect(old.readAloudVoice == 0)
    }
}
