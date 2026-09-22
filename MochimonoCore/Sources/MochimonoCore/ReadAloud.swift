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
/// 端末に入っている声は機種・言語・追加した声で違う。数が足りないときは、
/// 同じ声の高さを変えたものを足して、**いつでも5つそろえる**。番号の数が端末ごとに変わると、送った先が読めない。
public enum VoiceMenu {
    public static let count = 5

    /// 端末の声1つぶん（`AVSpeechSynthesisVoice` から、Core で扱う分だけ写す）。
    public struct Voice: Equatable, Sendable {
        public enum Quality: Int, Sendable { case standard = 1, enhanced = 2, premium = 3 }
        public let id: String
        public let name: String
        public let quality: Quality
        public init(id: String, name: String, quality: Quality) {
            self.id = id; self.name = name; self.quality = quality
        }
    }

    /// 1つの選択肢。`voiceID` が nil なら端末の既定の声。
    public struct Variant: Hashable, Sendable {
        public let voiceID: String?
        public let pitch: Float
    }

    /// 高さを変えて足すときの段。上げ下げを交互にして、似た声が並ばないようにする。
    static let pitches: [Float] = [1.25, 0.8, 1.45, 0.65]

    /// - Parameters:
    ///   - voices: その言語の声
    ///   - preferred: 端末の既定の声（いままで聞いていた声）。**これを1番にする**
    public static func variants(voices: [Voice], preferred: String?) -> [Variant] {
        // ざらついた効果音の声（Bahh・Bells など）は除く。持ち物を読ませる声ではない
        let usable = voices.filter { !$0.id.hasPrefix("com.apple.speech.synthesis.voice.") }
        let first = usable.first { $0.id == preferred }
        let others = usable.filter { $0.id != preferred }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
        var result = ([first].compactMap { $0 } + others).prefix(count).map { Variant(voiceID: $0.id, pitch: 1) }
        if result.isEmpty { result = [Variant(voiceID: nil, pitch: 1)] }
        let bases = result
        var i = 0
        while result.count < count {
            result.append(Variant(voiceID: bases[i % bases.count].voiceID,
                                  pitch: pitches[i % pitches.count]))
            i += 1
        }
        return result
    }

    /// 1つ送る。端まで来たら反対の端へ（配色の矢印と同じく一周する）。
    public static func step(_ index: Int, forward: Bool) -> Int {
        (index + (forward ? 1 : count - 1)) % count
    }
}
