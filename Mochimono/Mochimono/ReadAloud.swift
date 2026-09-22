import AVFoundation
import SwiftUI
import MochimonoCore

/// 手ぶらで準備するための読み上げ。
///
/// **まだの物を1つずつ読み、間を置いて、次へ。** 周が終わったら頭から繰り返す。
/// 答えは盤面のマスを押す（または下の「持った」）。付いた物は次の周から読まない。
///
/// - **声で答える仕組みは入れない**（2026-09-22 本人判断）。マイクの許可を求めず、読むだけにする
/// - 間隔は下の段で変えられる（`ReadAloudGap`）。**読んでいる途中に変えても、次の間から効く**
/// - 待っている間にいま読んだ物が付いたら、残りの間を待たずに次へ進む
/// - 読み上げ中は画面を消さない。消えると読み上げも止まる
@Observable @MainActor
final class ReadAloudSession {
    private(set) var isRunning = false
    private(set) var currentID: Item.ID?

    private let speechCode: String
    private let synthesizer = AVSpeechSynthesizer()
    private let speaker = Speaker()
    private var loop: Task<Void, Never>?
    /// 画面のボタンから来た合図。待ちを打ち切って、これを使う
    private var pending: Command?

    enum Command { case packed, next }

    init(language: Language) {
        speechCode = language.speechCode(region: Locale.current.region?.identifier)
        synthesizer.delegate = speaker
    }

    // MARK: - 始める・止める

    /// - Parameters:
    ///   - items: いまの盤面を返す。**毎回取り直す**（手で付けた印・編集を拾うため）
    ///   - gap: いまの間隔（秒）。毎回取り直す
    ///   - mark: 印を付ける
    func start(items: @escaping () -> [Item]?, gap: @escaping () -> Double,
               mark: @escaping (Item.ID) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        currentID = nil
        pending = nil
        UIApplication.shared.isIdleTimerDisabled = true
        let session = AVAudioSession.sharedInstance()
        // 流している音楽は止めずに小さくする。準備しながら聞いていることが多い
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        loop = Task { [weak self] in
            guard let self else { return }
            await self.run(items: items, gap: gap, mark: mark)
            self.finish()
        }
    }

    func stop() {
        guard isRunning else { return }
        loop?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// 画面のボタン（持った・次へ）。読んでいる途中なら、読むのをやめてすぐ進む。
    func send(_ command: Command) {
        guard isRunning else { return }
        pending = command
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func finish() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
        currentID = nil
        loop = nil
    }

    // MARK: - 本体

    private func run(items: () -> [Item]?, gap: () -> Double, mark: (Item.ID) -> Void) async {
        while !Task.isCancelled {
            guard let list = items() else { return }                 // リストが消えた
            guard let step = ReadAloudOrder.next(after: currentID, in: list) else {
                await say(String(localized: "ヨシ！ 全部そろいました"))
                return
            }
            currentID = step.item.id

            if step.startsRound {
                await say(String(localized: "残り\(list.filter { !$0.isPacked }.count)個"))
            }
            if pending == nil { await say(step.item.text) }
            if pending == nil { await wait(gap(), unlessPacked: step.item.id, items: items) }

            if pending == .packed,
               items()?.first(where: { $0.id == step.item.id })?.isPacked == false {
                mark(step.item.id)                // 付けるだけ。手で付けていたら外さない
            }
            pending = nil
        }
    }

    /// 間を置く。**そのあいだに、いま読んだ物が付いたら待たずに進む**（マスを押した＝答えた）。
    private func wait(_ seconds: Double, unlessPacked id: Item.ID, items: () -> [Item]?) async {
        let end = ContinuousClock.now + .milliseconds(Int(seconds * 1000))
        while ContinuousClock.now < end, pending == nil, !Task.isCancelled {
            if items()?.first(where: { $0.id == id })?.isPacked == true { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func say(_ text: String) async {
        guard !Task.isCancelled else { return }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: speechCode)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        await withCheckedContinuation { c in
            speaker.onFinish = { c.resume() }
            synthesizer.speak(u)
        }
    }
}

/// 読み終わりを知らせる。代理は MainActor の外から呼ばれるので、別の型に分ける。
private final class Speaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    @MainActor var onFinish: (() -> Void)?

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { done() }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { done() }

    private nonisolated func done() {
        Task { @MainActor in
            let f = self.onFinish
            self.onFinish = nil       // 1回だけ。2回呼ぶと待ちが壊れる
            f?()
        }
    }
}
