import XCTest

/// 掲載用スクリーンショットの素材を撮る。**言語を選んで撮れる。**
///
/// **画面をタップして手で撮ると毎回ずれる**うえ、他のセッションがシミュレータを
/// 使っていると別アプリが写り込む（引き継ぎ書 4-46）。UIテストから撮れば毎回同じものが出る。
/// 撮れた画像は `xcrun xcresulttool export attachments` で取り出す。
///
/// 言語は環境変数で渡す。xcodebuild には `TEST_RUNNER_` を付けて渡すと、テストの側に届く。
///
///     TEST_RUNNER_SHOT_LANG=en xcodebuild … -only-testing:MochimonoUITests/StoreShotUITests test
///
/// **表示の言葉では引かない。** 言語ごとに変わるので、名札（identifier）と位置で引く。
final class StoreShotUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// 言語と、日付や数字の書式の地域。`ja_JA` のような作り方をすると効かない（引き継ぎ書 4-157）。
    private static let locales: [String: String] = [
        "ja": "ja_JP", "en": "en_US", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW", "ko": "ko_KR",
        "es": "es_ES", "fr": "fr_FR", "de": "de_DE", "it": "it_IT", "pt-BR": "pt_BR",
        "ru": "ru_RU", "ar": "ar_SA", "sv": "sv_SE",
    ]

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func first(_ app: XCUIApplication, _ prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    func test掲載用の素材を撮る() {
        let lang = ProcessInfo.processInfo.environment["SHOT_LANG"] ?? "ja"
        let app = XCUIApplication()
        app.launchArguments = ["-screenshot-demo",
                               "-AppleLanguages", "(\(lang))",
                               "-AppleLocale", Self.locales[lang] ?? "en_US"]
        app.launch()

        // ① リストの一覧。リストごとに配色が違うことが見える
        let firstList = first(app, "list-")
        XCTAssertTrue(firstList.waitForExistence(timeout: 15))
        shot(app, "home")

        // ② 盤面（見本の1本目は国内旅行にあたる雛形）
        firstList.tapWhenReady()
        XCTAssertTrue(first(app, "item-").waitForExistence(timeout: 10))
        shot(app, "board")

        // ③ もとになるテキスト
        app.buttons["openEdit"].tapWhenReady()
        XCTAssertTrue(app.textViews["listText"].waitForExistence(timeout: 10))
        shot(app, "text")
        app.buttons["cancelEdit"].tapWhenReady()

        // ④ テキストに戻せること
        app.buttons["openSettings"].tapWhenReady()
        // **下まで送らない。** 送ると投げ銭の行まで写り、
        // 掲載画像と提出するビルドの中身が食い違う。書き出しの節は上のほうにある。
        XCTAssertTrue(app.buttons["exportText"].waitForExistence(timeout: 10), "書き出しの節が見つからない")
        shot(app, "export")

        // ⑤ 貼るだけで盤面になること
        app.navigationBars.buttons.element(boundBy: 0).tapWhenReady()
        app.navigationBars.buttons.element(boundBy: 0).tapWhenReady()
        app.buttons["addList"].tapWhenReady()
        _ = app.buttons["startBlank"].waitForExistence(timeout: 10)
        shot(app, "paste")
    }
}
