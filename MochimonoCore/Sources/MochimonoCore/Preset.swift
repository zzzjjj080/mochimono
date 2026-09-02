import Foundation

/// はじめから用意しておくリストの雛形。
///
/// 白紙から書き始めるのは難しい。**「近いものを持ってきて、要らない行を消す」ほうが速い。**
/// 選んだ時点でただのリストになるので、あとは好きに書き換えられる（雛形とは繋がらない）。
public struct Preset: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    /// 何のためのリストかの一言。名前だけでは中身が想像できない。
    public let detail: String
    public let text: String
    public let palette: Palette
    public let columns: Columns

    public init(id: String, name: String, detail: String,
                palette: Palette, columns: Columns = .four, text: String) {
        self.id = id
        self.name = name
        self.detail = detail
        self.text = text
        self.palette = palette
        self.columns = columns
    }

    /// 雛形から実際のリストを作る。以後は雛形と関係なく編集できる。
    public func makeList() -> PackingList {
        PackingList(name: name, text: text, columns: columns, palette: palette)
    }

    /// 中身を見せるための下ごしらえ。
    public var items: [Item] { PackingList.parse(text, preserving: []) }

    /// 使われているグループ番号。順番どおり。
    public var groups: [Int] {
        var seen = Set<Int>()
        return items.map(\.group).filter { seen.insert($0).inserted }
    }
}

extension Preset {
    /// 項目名は短くする。4列だと長い名前は縮んで読みにくい。
    /// この上限は `PresetTests` で機械的に守る。
    public static let maxItemLength = 8

    public static let all: [Preset] = [
        Preset(id: "town", name: "街中", detail: "ちょっと外出するとき",
               palette: Palette(1), text: """
                財布
                スマホ
                鍵
                ハンカチ

                イヤホン
                充電器
                モバイル充電

                目薬
                リップ
                マスク
                """),

        Preset(id: "commute", name: "通勤・通学", detail: "毎日のかばんの中身",
               palette: Palette(2), text: """
                財布
                スマホ
                鍵
                社員証

                定期券
                ICカード

                ノートPC
                充電器
                手帳
                ペン

                弁当
                水筒
                折りたたみ傘
                """),

        Preset(id: "trip-domestic", name: "国内旅行", detail: "1〜2泊のふつうの旅行",
               palette: Palette(3), text: """
                財布
                スマホ
                鍵
                免許証

                着替え
                下着
                靴下
                パジャマ

                歯ブラシ
                洗顔
                化粧品
                タオル

                充電器
                モバイル充電
                イヤホン

                常備薬
                絆創膏
                マスク

                エコバッグ
                ビニール袋
                """),

        Preset(id: "trip-abroad", name: "海外旅行", detail: "現地で買えないものを先に",
               palette: Palette(4), text: """
                パスポート
                航空券
                財布
                現金

                クレカ
                保険証書
                eSIM

                変換プラグ
                充電器
                モバイル充電

                着替え
                下着
                靴下
                上着

                歯ブラシ
                洗面用具
                化粧品

                常備薬
                酔い止め
                マスク

                アイマスク
                耳栓
                ネックピロー
                """),

        Preset(id: "business", name: "出張", detail: "1泊の仕事の遠出",
               palette: Palette(5), text: """
                財布
                スマホ
                社員証
                名刺

                ノートPC
                充電器
                マウス

                資料
                手帳
                ペン

                着替え
                下着
                ワイシャツ

                歯ブラシ
                洗面用具

                常備薬
                折りたたみ傘
                """),

        Preset(id: "gym", name: "ジム・運動", detail: "運動しに行くとき",
               palette: Palette(6), text: """
                ウェア
                短パン
                靴下

                シューズ
                タオル
                着替え

                水筒
                プロテイン

                会員証
                ロッカー鍵

                シャンプー
                ボディソープ
                """),

        Preset(id: "camp", name: "キャンプ・BBQ", detail: "外で火を使うとき",
               palette: Palette(7), text: """
                テント
                ペグ
                ハンマー

                寝袋
                マット
                ランタン

                コンロ
                炭
                着火剤
                トング

                クーラー
                食材
                飲み物

                食器
                箸
                調味料

                軍手
                ゴミ袋
                虫除け
                """),

        Preset(id: "onsen", name: "温泉・銭湯", detail: "お風呂に行くとき",
               palette: Palette(8), text: """
                タオル
                バスタオル
                着替え

                下着
                靴下

                シャンプー
                洗顔
                化粧水

                髪ゴム
                小銭
                飲み物
                """),

        Preset(id: "kids", name: "子どもとおでかけ", detail: "小さい子を連れて出るとき",
               palette: Palette(9), text: """
                おむつ
                おしりふき
                ビニール袋

                着替え
                スタイ
                タオル

                ミルク
                哺乳瓶
                麦茶

                おやつ
                おもちゃ
                絵本

                母子手帳
                保険証
                診察券

                抱っこ紐
                日焼け止め
                帽子
                """),

        Preset(id: "hospital", name: "通院", detail: "病院へ行くとき",
               palette: Palette(10), text: """
                保険証
                診察券
                お薬手帳

                財布
                現金
                スマホ

                紹介状
                検査結果

                マスク
                飲み物
                """),

        Preset(id: "ceremony", name: "冠婚葬祭", detail: "急に必要になるもの",
               palette: Palette(11), text: """
                礼服
                ネクタイ
                黒靴下

                袱紗
                香典
                ご祝儀袋

                数珠
                ハンカチ
                筆ペン

                財布
                スマホ
                """),

        Preset(id: "disaster", name: "防災", detail: "持ち出し袋の中身",
               palette: Palette(12), text: """
                水
                非常食
                携帯ラジオ

                懐中電灯
                電池
                モバイル充電

                救急セット
                常備薬
                マスク

                現金
                身分証コピー
                通帳

                軍手
                ホイッスル
                レインコート

                タオル
                歯ブラシ
                携帯トイレ
                """),
    ]

    public static func preset(id: String) -> Preset? { all.first { $0.id == id } }
}
