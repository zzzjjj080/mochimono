import AVFoundation
import SwiftUI
import MochimonoCore

/// 手ぶらで準備するための読み上げ。
///
/// **まだの物を1つずつ読み、間を置いて、次へ。** 周が終わったら、長めに間を置いて頭から繰り返す。
/// 答えは盤面のマスを押す。付いた物は次の周から読まない。
///
/// - **声で答える仕組みは入れない**（2026-09-22 本人判断）。マイクの許可を求めず、読むだけにする
/// - 「次へ」「持った」のボタンも「残り◯個」の読み上げも置かない（同日 本人判断）。
///   **周の切れ目は、間を3倍にして耳で分かるようにする**（`ReadAloudGap.roundBreak`）
/// - 間隔は下の段で変えられる。**読んでいる途中に変えても、次の間から効く**
/// - 間の途中で、いま読んだ物が付いたら残りを待たずに次へ進む（周の切れ目は縮めない）
/// - 読み上げ中は画面を消さない。消えると読み上げも止まる
/// - **電話・Siri・アラームで音が奪われたら止める。イヤホンを抜いたら止める**（Apple の決まり：
///   抜いた瞬間にスピーカーから鳴り出してはいけない）。止めずにいると、読み終わりの知らせが来ずに
///   待ちが残り、ボタンが「止める」のまま戻らなくなる
@Observable @MainActor
final class ReadAloudSession {
    private(set) var isRunning = false
    private(set) var currentID: Item.ID?

    private let speechCode: String
    private let synthesizer = AVSpeechSynthesizer()
    private let speaker = Speaker()
    private var loop: Task<Void, Never>?
    /// 割り込み（電話など）とイヤホンの抜き差しの見張り。読んでいる間だけ置く
    private var watchers: [NSObjectProtocol] = []
    /// 声の選択肢（5つ）。端末に入っている声から、開いたときに組む
    let slots: [VoiceMenu.Slot]
    /// 読み始めてから読んだ品の数。交互に読む声（4・5番）の順番に使う
    private var spoken = 0

    init(language: Language) {
        let code = language.speechCode(region: Locale.current.region?.identifier)
        speechCode = code
        synthesizer.delegate = speaker
        slots = Self.menu(for: code)
    }

    /// その言語の声を集める。地域まで合う声（ja-JP）が無ければ、言語だけ合う声（ja-*）で組む。
    private static func menu(for code: String) -> [VoiceMenu.Slot] {
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { !$0.voiceTraits.contains(.isPersonalVoice) }
        let lang = String(code.prefix { $0 != "-" })
        let exact = all.filter { $0.language == code }
        let pool = exact.isEmpty ? all.filter { $0.language.hasPrefix(lang + "-") } : exact
        let voices = pool.map { v in
            let quality: VoiceMenu.Voice.Quality = switch v.quality {
                case .premium: .premium
                case .enhanced: .enhanced
                default: .standard
            }
            let gender: VoiceMenu.Voice.Gender = switch v.gender {
                case .male: .male
                case .female: .female
                default: .unknown
            }
            return VoiceMenu.Voice(id: v.identifier, name: v.name, quality: quality, gender: gender)
        }
        return VoiceMenu.slots(voices: voices,
                                  preferred: AVSpeechSynthesisVoice(language: code)?.identifier)
    }

    // MARK: - 始める・止める

    /// - Parameters:
    ///   - items: いまの盤面を返す。**毎回取り直す**（手で付けた印・編集を拾うため）
    ///   - gap: いまの間隔（秒）。毎回取り直す
    ///   - voice: いまの声の番号。毎回取り直す（読みながら送って聞き比べられるように）
    func start(items: @escaping () -> [Item]?, gap: @escaping () -> Double,
               voice: @escaping () -> Int) {
        self.voice = voice
        guard !isRunning else { return }
        isRunning = true
        currentID = nil
        spoken = 0
        UIApplication.shared.isIdleTimerDisabled = true
        let session = AVAudioSession.sharedInstance()
        // 流している音楽は止めずに小さくする。準備しながら聞いていることが多い
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        watch(session)
        loop = Task { [weak self] in
            guard let self else { return }
            await self.run(items: items, gap: gap)
            self.finish()
        }
    }

    func stop() {
        guard isRunning else { return }
        loop?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
        // 読み始める直前・読み終えた直後に押されると、読み終わりの知らせが来ない。待ちはこちらで解く
        speaker.finishNow()
    }

    private var voice: () -> Int = { 0 }

    private func watch(_ session: AVAudioSession) {
        let center = NotificationCenter.default
        watchers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: session,
                               queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw.flatMap(AVAudioSession.InterruptionType.init) == .began else { return }
                MainActor.assumeIsolated { self?.stop() }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session,
                               queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                guard raw.flatMap(AVAudioSession.RouteChangeReason.init) == .oldDeviceUnavailable else { return }
                MainActor.assumeIsolated { self?.stop() }
            },
        ]
    }

    private func finish() {
        watchers.forEach(NotificationCenter.default.removeObserver)
        watchers = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
        currentID = nil
        loop = nil
    }

    // MARK: - 本体

    private func run(items: () -> [Item]?, gap: () -> Double) async {
        while !Task.isCancelled {
            guard let list = items() else { return }                 // リストが消えた
            guard let planned = ReadAloudOrder.next(after: currentID, in: list) else {
                await say(String(localized: "ヨシ！ 全部そろいました"))
                return
            }
            let pause = ReadAloudGap.pause(before: planned, isFirst: currentID == nil, gap: gap())
            // 周の切れ目は押されても縮めない。縮めると頭に戻ったことが分からない
            await wait(pause, unlessPacked: planned.startsRound ? nil : currentID, items: items)

            // 待っている間に付いた物があるので、読む物は取り直す
            guard let now = items() else { return }
            guard let step = ReadAloudOrder.next(after: currentID, in: now) else { continue }
            currentID = step.item.id
            await say(step.item.text)
            spoken += 1
        }
    }

    /// 間を置く。`id` が付いたら（マスを押した＝答えた）残りを待たずに戻る。
    private func wait(_ seconds: Double, unlessPacked id: Item.ID?, items: () -> [Item]?) async {
        let end = ContinuousClock.now + .milliseconds(Int(seconds * 1000))
        while ContinuousClock.now < end, !Task.isCancelled {
            if let id, items()?.first(where: { $0.id == id })?.isPacked == true { return }
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    private func say(_ text: String) async {
        guard !Task.isCancelled else { return }
        let u = AVSpeechUtterance(string: text)
        let variant = slots[min(max(voice(), 0), slots.count - 1)].variant(at: spoken)
        u.voice = variant.voiceID.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: speechCode)
        u.pitchMultiplier = variant.pitch
        u.rate = min(AVSpeechUtteranceDefaultSpeechRate * variant.rate, AVSpeechUtteranceMaximumSpeechRate)
        // **時間切れも付ける。** 音の道が奪われたまま知らせが来ないと、読み上げが止まったまま戻らない。
        // 1文字0.4秒＋3秒あれば、どの言語・どの速さでも読み終わる
        let limit = Duration.milliseconds(3000 + text.count * 400)
        let guardTask = Task { [speaker, synthesizer] in
            try? await Task.sleep(for: limit)
            guard !Task.isCancelled else { return }
            synthesizer.stopSpeaking(at: .immediate)
            speaker.finishNow()
        }
        await withCheckedContinuation { c in
            speaker.onFinish = { c.resume() }
            synthesizer.speak(u)
        }
        guardTask.cancel()
    }
}

/// 読み終わりを知らせる。代理は MainActor の外から呼ばれるので、別の型に分ける。
private final class Speaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    @MainActor var onFinish: (() -> Void)?

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { done() }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { done() }

    private nonisolated func done() {
        Task { @MainActor in self.finishNow() }
    }

    /// 待っている読み上げを終わらせる。何度呼んでもよい（2回目以降は何もしない）
    @MainActor func finishNow() {
        let f = onFinish
        onFinish = nil       // 1回だけ。2回呼ぶと待ちが壊れる
        f?()
    }
}
