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
    let kyoko = V(id: "ja.kyoko", name: "Kyoko", quality: .standard)
    let otoya = V(id: "ja.otoya", name: "Otoya", quality: .standard)
    let premium = V(id: "ja.kyoko.premium", name: "Kyoko", quality: .premium)
    let bahh = V(id: "com.apple.speech.synthesis.voice.Bahh", name: "Bahh", quality: .standard)

    @Test func いつでも5つ() {
        #expect(VoiceMenu.variants(voices: [], preferred: nil).count == 5)
        #expect(VoiceMenu.variants(voices: [kyoko], preferred: "ja.kyoko").count == 5)
        let many = (0..<9).map { V(id: "v\($0)", name: "V\($0)", quality: .standard) }
        #expect(VoiceMenu.variants(voices: many, preferred: nil).count == 5)
    }

    @Test func 一番はいままでの声() {
        let v = VoiceMenu.variants(voices: [premium, otoya, kyoko], preferred: "ja.kyoko")
        #expect(v[0] == .init(voiceID: "ja.kyoko", pitch: 1))
        #expect(v[1].voiceID == "ja.kyoko.premium")      // 残りは質の高い順
    }

    @Test func 足りない分は高さを変えて足す() {
        let v = VoiceMenu.variants(voices: [kyoko, otoya], preferred: "ja.kyoko")
        #expect(v.map(\.voiceID) == ["ja.kyoko", "ja.otoya", "ja.kyoko", "ja.otoya", "ja.kyoko"])
        #expect(v.map(\.pitch) == [1, 1, 1.25, 0.8, 1.45])
        #expect(Set(v).count == 5)                        // 同じものが並ばない
    }

    @Test func 効果音の声は使わない() {
        let v = VoiceMenu.variants(voices: [bahh, kyoko], preferred: nil)
        #expect(!v.contains { $0.voiceID == bahh.id })
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
