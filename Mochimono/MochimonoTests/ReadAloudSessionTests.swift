import AVFoundation
import Foundation
import Testing
import MochimonoCore
@testable import Mochimono

/// 読み上げの止まり方。**止まらずに「止める」のまま戻らない**のがいちばん困るので、そこを見る。
@MainActor
@Suite(.serialized)
struct ReadAloudSessionTests {
    let items = ["財布", "スマホ", "鍵"].map { Item(text: $0, group: 0) }

    private func started(gap: Double = 5) async throws -> ReadAloudSession {
        let s = ReadAloudSession(language: .ja)
        s.start(items: { [items] in items }, gap: { gap }, voice: { 0 })
        try await until { s.currentID != nil }
        #expect(s.isRunning)
        return s
    }

    /// 条件がそろうまで少しずつ待つ（最大5秒）
    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(50)) }
    }

    @Test func 止めると止まる() async throws {
        let s = try await started()
        s.stop()
        try await until { !s.isRunning }
        #expect(!s.isRunning)
        #expect(s.currentID == nil)
    }

    @Test func 読む前の間でも止めると止まる() async throws {
        let s = try await started(gap: 5)
        try await Task.sleep(for: .seconds(1.5))      // 1つ目を読み終えて、5秒の間に入ったところ
        s.stop()
        try await until { !s.isRunning }
        #expect(!s.isRunning)
    }

    @Test func 電話などで音を奪われたら止まる() async throws {
        let s = try await started()
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        try await until { !s.isRunning }
        #expect(!s.isRunning)
    }

    @Test func イヤホンを抜いたら止まる() async throws {
        let s = try await started()
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        try await until { !s.isRunning }
        #expect(!s.isRunning)
    }

    /// イヤホンを挿したとき（新しい機器が増えた）は止めない
    @Test func イヤホンを挿しても止まらない() async throws {
        let s = try await started()
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue])
        try await Task.sleep(for: .milliseconds(300))
        #expect(s.isRunning)
        s.stop()
        try await until { !s.isRunning }
    }

    @Test func 全部そろっていれば読まずに止まる() async throws {
        let done = items.map { Item(id: $0.id, text: $0.text, group: 0, isPacked: true) }
        let s = ReadAloudSession(language: .ja)
        s.start(items: { done }, gap: { 0.3 }, voice: { 0 })
        try await until { !s.isRunning }
        #expect(!s.isRunning)
    }

    @Test func リストが消えたら止まる() async throws {
        var alive = true
        let s = ReadAloudSession(language: .ja)
        s.start(items: { [items] in alive ? items : nil }, gap: { 0.3 }, voice: { 0 })
        try await until { s.currentID != nil }
        alive = false
        try await until { !s.isRunning }
        #expect(!s.isRunning)
    }

    /// 声の番号が範囲外（古い保存・選択肢が減った）でも落ちない
    @Test func 声の番号が範囲外でも落ちない() async throws {
        let s = ReadAloudSession(language: .en)
        s.start(items: { [items] in items }, gap: { 0.3 }, voice: { 99 })
        try await until { s.currentID != nil }
        #expect(s.isRunning)
        s.stop()
        try await until { !s.isRunning }
    }

    @Test(arguments: Language.allCases)
    func どの言語でも声の選択肢は5つ(_ language: Language) {
        #expect(ReadAloudSession(language: language).slots.count == VoiceMenu.count)
    }
}
