import Foundation

/// 読み上げの順番。**まだの物だけを、盤面の並び順に、ぐるぐる回す。**
///
/// 1周したら先頭のまだの物へ戻る。手で付けた物・声で付けた物は、次の周から自然に抜ける。
/// 手ぶらで準備している人は画面を見ないので、「どこまで読んだか」を覚えるのはこちらの役目。
public enum ReadAloudOrder {
    public struct Step: Equatable, Sendable {
        public let item: Item
        /// 周の頭か。2周目からの頭では、間を長めに取って区切りを耳で分かるようにする。
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

/// 読み上げの間隔（1つ読み終えてから次を読むまで）。**アプリ全体で1つ。**
///
/// 最初は3.5秒待っていたが「遅すぎる」と言われ、0.8秒でもまだ長く、**既定は最短の0.3秒**にした（2026-09-22）。
/// 送った先が1つ飛びにならないよう、段は表で持つ。
public enum ReadAloudGap {
    public static let steps: [Double] = [0.3, 0.5, 0.8, 1, 1.5, 2, 3, 5]
    public static let `default`: Double = 0.3
    /// 周の切れ目は、ふだんの間の何倍空けるか。
    /// 「残り◯個」と言う代わりに、**間の長さで「頭に戻った」を伝える**（2026-09-22 本人指定）。
    public static let roundBreak: Double = 3

    /// この1つを読む前に空ける間（秒）。最初の1つは待たない。
    public static func pause(before step: ReadAloudOrder.Step, isFirst: Bool, gap: Double) -> Double {
        if isFirst { return 0 }
        return step.startsRound ? gap * roundBreak : gap
    }

    /// 保存してある値を、いちばん近い段に寄せる（段を変えても古い値で迷子にならない）。
    public static func snapped(_ seconds: Double) -> Double {
        steps.min { abs($0 - seconds) < abs($1 - seconds) } ?? `default`
    }

    /// 1段短く・長く。端では止まる（一周させない。最短の次が最長だと驚く）。
    public static func step(_ seconds: Double, longer: Bool) -> Double {
        let i = steps.firstIndex(of: snapped(seconds)) ?? 0
        return steps[min(max(i + (longer ? 1 : -1), 0), steps.count - 1)]
    }

    public static func isShortest(_ s: Double) -> Bool { snapped(s) == steps.first }
    public static func isLongest(_ s: Double) -> Bool { snapped(s) == steps.last }
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

/// 読み上げの声の選び方。**名前は出さず、番号（1〜5）で送る**（配色と同じ扱い）。
///
/// 並び（2026-09-22 本人指定）：
/// 1 端末の既定の声（それまで聞いていた声） / 2 明るい男 / 3 きびきびした早口 /
/// 4 可愛い女の子 / 5 ロボット。3と5は「自由な発想で」と任された枠。
/// 3 は**準備を急ぐ人向けに速さで**、5 は**機械声をあえて機械らしく高めに**して、ほかの4つと聞き分けられるようにした。
/// 最初は「その言語の声を名前順」にしたら、日本語では機械声（Eloquence の Eddy・Grandpa…）が並び、
/// 「暗い男ばかり」と言われた。**声の性別と自然さで選び、高さと速さで性格を付ける。**
/// 同じ声を使い回しても、高さ・速さが違うので5つは必ず別物になる。
public enum VoiceMenu {
    public static let count = 5

    /// 端末の声1つぶん（`AVSpeechSynthesisVoice` から、Core で扱う分だけ写す）。
    public struct Voice: Equatable, Sendable {
        public enum Quality: Int, Sendable { case standard = 1, enhanced = 2, premium = 3 }
        public enum Gender: Sendable { case male, female, unknown }
        public let id: String
        public let name: String
        public let quality: Quality
        public let gender: Gender
        public init(id: String, name: String, quality: Quality, gender: Gender = .unknown) {
            self.id = id; self.name = name; self.quality = quality; self.gender = gender
        }

        /// 機械っぽい合成声（Eloquence）。自然な声が無いときだけ使う
        var isRobotic: Bool { id.hasPrefix("com.apple.eloquence.") }

        /// 性別。**Eloquence は端末が性別を返さない**ので、名前で補う。
        var resolvedGender: Gender {
            if gender != .unknown { return gender }
            if ["Eddy", "Reed", "Rocko"].contains(name) { return .male }
            if ["Flo", "Sandy", "Shelley"].contains(name) { return .female }
            return .unknown
        }
    }

    /// 1つの選択肢。`voiceID` が nil なら端末の既定の声。`rate` は標準の速さに掛ける倍率。
    public struct Variant: Hashable, Sendable {
        public let voiceID: String?
        public let pitch: Float
        public let rate: Float
        public init(voiceID: String?, pitch: Float, rate: Float = 1) {
            self.voiceID = voiceID; self.pitch = pitch; self.rate = rate
        }
    }

    /// 性格ごとの高さと速さ。**明るい男は少しだけ高く、可愛い女の子はかなり高く、どちらも少し速く。**
    /// 男を高くしすぎると裏声に、女の子を速くしすぎると早口に聞こえるので、この幅に留める。
    static let brightMale = (pitch: Float(1.12), rate: Float(1.05))
    static let cuteGirl = (pitch: Float(1.5), rate: Float(1.06))
    /// きびきび：いつもの声のまま、ぐっと速く。高さはほぼ変えない（変えると別人に聞こえて速さが伝わらない）
    static let brisk = (pitch: Float(1.05), rate: Float(1.3))
    /// ロボット：機械声を高めに、少し速く。機械声が無い端末では、いつもの声をうんと低く・ゆっくりにする
    static let robot = (pitch: Float(1.5), rate: Float(1.15))
    static let robotFallback = (pitch: Float(0.6), rate: Float(0.9))

    /// - Parameters:
    ///   - voices: その言語の声
    ///   - preferred: 端末の既定の声（いままで聞いていた声）。**これを1番にする**
    public static func variants(voices: [Voice], preferred: String?) -> [Variant] {
        // 効果音の声（Bahh など）と、年寄りの声（Grandma・Grandpa）は使わない
        let usable = voices.filter {
            !$0.id.hasPrefix("com.apple.speech.synthesis.voice.")
                && !["Grandma", "Grandpa"].contains($0.name)
        }
        let first = usable.first { $0.id == preferred }?.id ?? preferred ?? usable.first?.id
        let male = ranked(usable, .male).first
        let female = ranked(usable, .female).first
        // ロボットは Rocko（名前も声もロボットらしい）を先に。無ければ機械声のどれか
        let robotic = usable.filter(\.isRobotic)
        let machine = (robotic.first { $0.name == "Rocko" } ?? robotic.first)?.id
        return [
            Variant(voiceID: first, pitch: 1),
            Variant(voiceID: male ?? first, pitch: brightMale.pitch, rate: brightMale.rate),
            Variant(voiceID: first, pitch: brisk.pitch, rate: brisk.rate),
            Variant(voiceID: female ?? first, pitch: cuteGirl.pitch, rate: cuteGirl.rate),
            machine.map { Variant(voiceID: $0, pitch: robot.pitch, rate: robot.rate) }
                ?? Variant(voiceID: first, pitch: robotFallback.pitch, rate: robotFallback.rate),
        ]
    }

    /// その性別の声を、**自然な声を先に**、質の高い順に並べる。
    static func ranked(_ voices: [Voice], _ gender: Voice.Gender) -> [String] {
        voices.filter { $0.resolvedGender == gender }
            .sorted { a, b in
                if a.isRobotic != b.isRobotic { return !a.isRobotic }
                if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
                return a.name < b.name
            }
            .map(\.id)
    }

    /// 1つ送る。端まで来たら反対の端へ（配色の矢印と同じく一周する）。
    public static func step(_ index: Int, forward: Bool) -> Int {
        (index + (forward ? 1 : count - 1)) % count
    }
}
