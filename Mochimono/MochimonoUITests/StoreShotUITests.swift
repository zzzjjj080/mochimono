import XCTest

/// 掲載用スクリーンショットの素材を撮る。
///
/// **画面をタップして手で撮ると毎回ずれる**うえ、他のセッションがシミュレータを
/// 使っていると別アプリが写り込む（引き継ぎ書 4-46）。UIテストから撮れば毎回同じものが出る。
/// 撮れた画像は `xcrun xcresulttool export attachments` で取り出す。
final class StoreShotUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func test掲載用の素材を撮る() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshot-demo"]
        app.launch()

        // ① リストの一覧。リストごとに配色が違うことが見える
        XCTAssertTrue(app.buttons["list-国内旅行"].waitForExistence(timeout: 15))
        shot(app, "home")

        // ② 盤面
        app.buttons["list-国内旅行"].tapWhenReady()
        XCTAssertTrue(app.buttons["item-財布"].waitForExistence(timeout: 10))
        shot(app, "board")

        // ③ もとになるテキスト
        app.buttons["openEdit"].tapWhenReady()
        XCTAssertTrue(app.textViews["listText"].waitForExistence(timeout: 10))
        shot(app, "text")
        app.buttons["キャンセル"].tapWhenReady()

        // ④ テキストに戻せること
        app.buttons["openSettings"].tapWhenReady()
        // **下まで送らない。** 送ると投げ銭の行まで写り、
        // 掲載画像と提出するビルドの中身が食い違う。書き出しの節は上のほうにある。
        let heading = app.staticTexts["盤面をテキストに戻す"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10), "書き出しの節が見つからない")
        shot(app, "export")

        // ⑤ 貼るだけで盤面になること
        app.navigationBars.buttons.element(boundBy: 0).tapWhenReady()
        app.navigationBars.buttons.element(boundBy: 0).tapWhenReady()
        app.buttons["addList"].tapWhenReady()
        _ = app.staticTexts["テキストから作る"].waitForExistence(timeout: 10)
        shot(app, "paste")
    }
}
