import AVFoundation
import Speech
import SwiftUI
import MochimonoCore

/// 手ぶらで準備するための読み上げ。
///
/// **まだの物を1つずつ読み、少し待って、次へ。** 周が終わったら頭から繰り返す。
/// 読んだあと「持った」と言えば印を付け、「次」で飛ばし、「止めて」で終わる。
///
/// - 聞き取りは**端末の中だけ**（`requiresOnDeviceRecognition`）。声を外へ送らない。
///   端末内で聞き取れない言語・許可が無いときは、声の合図なしで読むだけにする（画面のボタンは使える）
/// - **聞くのは読み終えてから。** 読んでいる間も聞くと、自分の声（品名）を拾ってしまう
/// - 読み上げ中は画面を消さない。消えると読み上げも止まる
@Observable @MainActor
final class ReadAloudSession {
    enum Phase: Equatable { case idle, speaking, listening, waiting }
    /// 声の合図が使えるか。使えないときは理由を画面に出す
    enum Voice: Equatable { case unknown, ready, denied, unsupported }

    private(set) var isRunning = false
    private(set) var currentID: Item.ID?
    private(set) var phase: Phase = .idle
    private(set) var voice: Voice = .unknown

    private let language: Language
    private let speechCode: String
    private let synthesizer = AVSpeechSynthesizer()
    private let speaker = Speaker()
    private let listener: Listener?
    private var loop: Task<Void, Never>?
    /// 画面のボタンから来た合図。聞いている最中なら聞き取りを打ち切って、これを使う
    private var pending: VoiceCommand?

    /// 読み終えてから待つ長さ。声の合図がないときは、手で押すぶん少し長めに待つ
    private var listenWindow: Duration { voice == .ready ? .seconds(3.5) : .seconds(3) }

    /// UI テストでは、マイクの許可の窓で止まらないよう、声の合図を使わない
    static let silentForTesting = ProcessInfo.processInfo.arguments.contains("-ReadAloudNoMic")

    init(language: Language) {
        self.language = language
        speechCode = language.speechCode(region: Locale.current.region?.identifier)
        listener = Listener(locale: Locale(identifier: speechCode), language: language)
        synthesizer.delegate = speaker
    }

    // MARK: - 始める・止める

    /// - Parameters:
    ///   - items: いまの盤面を返す。**毎回取り直す**（手で付けた印・編集を拾うため）
    ///   - mark: 印を付ける
    func start(items: @escaping () -> [Item]?, mark: @escaping (Item.ID) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        currentID = nil
        pending = nil
        UIApplication.shared.isIdleTimerDisabled = true
        loop = Task { [weak self] in
            guard let self else { return }
            await self.prepareVoice()
            await self.run(items: items, mark: mark)
            self.finish()
        }
    }

    func stop() {
        guard isRunning else { return }
        pending = .stop
        listener?.cancel()
        waiter?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
        loop?.cancel()
    }

    /// 画面のボタン（持った・次へ）。声と同じ道を通す。
    func send(_ command: VoiceCommand) {
        guard isRunning else { return }
        pending = command
        listener?.cancel()
        if phase == .speaking { synthesizer.stopSpeaking(at: .immediate) }
        if phase == .waiting { waiter?.cancel() }
    }

    private var waiter: Task<Void, Never>?

    private func finish() {
        listener?.shutDown()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
        phase = .idle
        currentID = nil
        loop = nil
    }

    // MARK: - 本体

    private func run(items: () -> [Item]?, mark: (Item.ID) -> Void) async {
        var readAgain = false
        while !Task.isCancelled && isRunning {
            guard let list = items() else { return }                 // リストが消えた
            let step: ReadAloudOrder.Step
            if readAgain, let id = currentID, let same = list.first(where: { $0.id == id && !$0.isPacked }) {
                step = .init(item: same, startsRound: false)
            } else if let s = ReadAloudOrder.next(after: currentID, in: list) {
                step = s
            } else {
                await say(String(localized: "ヨシ！ 全部そろいました"))
                return
            }
            readAgain = false
            currentID = step.item.id

            if step.startsRound {
                let left = list.filter { !$0.isPacked }.count
                await say(String(localized: "残り\(left)個"), rate: 0.55)
            }
            if pending == nil { await say(step.item.text) }

            let command = pending == nil ? await awaitAnswer() : nil
            let decided = pending ?? command
            pending = nil
            switch decided {
            case .packed:
                // 読んでいる間に手で付けていたら、付け直して外さない
                if list.first(where: { $0.id == step.item.id })?.isPacked == false,
                   items()?.first(where: { $0.id == step.item.id })?.isPacked == false {
                    mark(step.item.id)
                }
                if items()?.contains(where: { !$0.isPacked }) == true {
                    await say(String(localized: "ヨシ"), rate: 0.6)
                }
            case .again: readAgain = true
            case .stop: return
            case .next, nil: break
            }
        }
    }

    /// 読み終えたあとの待ち。声の合図が使えれば聞き、使えなければ黙って待つ。
    private func awaitAnswer() async -> VoiceCommand? {
        if voice == .ready, let listener {
            phase = .listening
            defer { phase = .idle }
            return await listener.listen(for: listenWindow)
        }
        phase = .waiting
        defer { phase = .idle }
        let window = listenWindow
        let t = Task { _ = try? await Task.sleep(for: window) }
        waiter = t
        await t.value
        return nil
    }

    private func say(_ text: String, rate: Float = 0.5) async {
        guard isRunning, !Task.isCancelled else { return }
        phase = .speaking
        defer { phase = .idle }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: speechCode)
        u.rate = rate * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
            + AVSpeechUtteranceMinimumSpeechRate
        u.postUtteranceDelay = 0.1
        await withCheckedContinuation { c in
            speaker.onFinish = { c.resume() }
            synthesizer.speak(u)
        }
    }

    // MARK: - 許可と音の道

    private func prepareVoice() async {
        let session = AVAudioSession.sharedInstance()
        if voice == .unknown { voice = await Self.requestVoice(listener) }
        do {
            if voice == .ready {
                // 読むのと聞くのを1つの道で。スピーカーから出し、ほかの音楽は小さくする
                try session.setCategory(.playAndRecord, mode: .default,
                                        options: [.duckOthers, .defaultToSpeaker,
                                                  .allowBluetoothHFP, .allowBluetoothA2DP])
            } else {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            }
            try session.setActive(true)
            if voice == .ready, listener?.startEngine() == false { voice = .unsupported }
        } catch {
            voice = voice == .ready ? .unsupported : voice
        }
    }

    private static func requestVoice(_ listener: Listener?) async -> Voice {
        guard !silentForTesting else { return .unsupported }
        guard let listener, listener.supportsOnDevice else { return .unsupported }
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speech == .authorized else { return .denied }
        guard await AVAudioApplication.requestRecordPermission() else { return .denied }
        return .ready
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

/// 端末の中だけで聞き取る。**1回聞くごとに新しい依頼を作る**（長く聞き続けると1分で切られる）。
@MainActor
private final class Listener {
    private let recognizer: SFSpeechRecognizer?
    private let language: Language
    private let engine = AVAudioEngine()
    private let feed = Feed()
    private var task: SFSpeechRecognitionTask?
    private var answer: CheckedContinuation<VoiceCommand?, Never>?
    private var timeout: Task<Void, Never>?

    init?(locale: Locale, language: Language) {
        recognizer = SFSpeechRecognizer(locale: locale)
        self.language = language
        guard recognizer != nil else { return nil }
    }

    var supportsOnDevice: Bool { recognizer?.supportsOnDeviceRecognition == true }

    func startEngine() -> Bool {
        guard !engine.isRunning else { return true }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return false }       // マイクが無い（シミュレータなど）
        let feed = feed
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            feed.append(buffer)                                  // 聞いている間だけ依頼へ流れる
        }
        engine.prepare()
        do { try engine.start() } catch { input.removeTap(onBus: 0); return false }
        return true
    }

    func shutDown() {
        cancel()
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    func listen(for window: Duration) async -> VoiceCommand? {
        guard let recognizer else { return nil }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true       // 声を外へ送らない
        request.shouldReportPartialResults = true        // 言い終わりを待たずに拾う
        request.taskHint = .confirmation
        request.contextualStrings = VoiceCommands.allWords(language)
        feed.request = request
        let language = language
        return await withCheckedContinuation { c in
            answer = c
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let heard = result?.bestTranscription.formattedString ?? ""
                let command = VoiceCommands.match(heard, language: language)
                let ended = error != nil || result?.isFinal == true
                guard command != nil || ended else { return }
                Task { @MainActor in self?.resolve(command) }
            }
            timeout = Task { [weak self] in
                try? await Task.sleep(for: window)
                guard !Task.isCancelled else { return }
                self?.resolve(nil)
            }
        }
    }

    func cancel() { resolve(nil) }

    private func resolve(_ command: VoiceCommand?) {
        feed.request?.endAudio()
        feed.request = nil
        task?.cancel(); task = nil
        timeout?.cancel(); timeout = nil
        let c = answer
        answer = nil          // 1回だけ返す
        c?.resume(returning: command)
    }
}

/// マイクの音を、いま聞いている依頼へ渡す。音はオーディオの糸から来るので鍵で守る。
private final class Feed: @unchecked Sendable {
    private let lock = NSLock()
    private var _request: SFSpeechAudioBufferRecognitionRequest?
    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { _request } }
        set { lock.withLock { _request = newValue } }
    }
    func append(_ buffer: AVAudioPCMBuffer) { request?.append(buffer) }
}
