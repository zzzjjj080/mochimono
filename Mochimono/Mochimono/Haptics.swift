import UIKit

/// 触覚フィードバック。
///
/// 生成器は使い回して `prepare()` しておく。毎回作ると1打目が鳴らない。
/// `intensity` を明示しないと端末側の判断で弱まる（引き継ぎ書 4-29）。
/// **シミュレータでは鳴らない。確認は実機で行う。**
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    static func warmUp() {
        rigid.prepare(); heavy.prepare(); notice.prepare()
    }

    /// 持ち物を入り切りした。ONのほうを強くして、付けたことが指で分かるようにする。
    static func check(on: Bool) {
        if on { heavy.impactOccurred(intensity: 1.0) }
        else { rigid.impactOccurred(intensity: 0.9) }
        warmUp()
    }

    /// 選ぶ・切り替える。`UISelectionFeedbackGenerator` は弱いので当たりで代用する。
    static func select() { rigid.impactOccurred(intensity: 0.85); warmUp() }

    /// 操作が終わった。
    static func done() { notice.notificationOccurred(.success); warmUp() }

    /// 消した・できなかった。
    static func warn() { notice.notificationOccurred(.warning); warmUp() }

    /// 全部そろった。区切りのあとに一発足す。
    static func complete() {
        notice.notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            heavy.impactOccurred(intensity: 1.0)
        }
        warmUp()
    }
}
