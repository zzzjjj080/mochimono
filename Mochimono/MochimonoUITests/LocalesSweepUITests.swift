import XCTest

/// 12言語すべてで、主な画面を一巡りして写真を残す。
///
/// **世界向けに出すと、自分の端末の言語では見えない崩れが出る**（長い訳で切れる・右から左で向きが逆になる）。
/// ここで一覧・盤面（読み上げ中）・編集・追加・設定（投げ銭）を開き、要素が画面からはみ出していないかを見て、
/// 写真を添付に残す。写真は人が目で確かめる（`test-results` から取り出す）。
final class LocalesSweepUITests: XCTestCase {

    static let languages = ["ja", "en", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de", "it", "pt-BR", "ru", "ar"]

    override func setUp() { continueAfterFailure = true }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let s = XCTAttachment(screenshot: app.screenshot())
        s.name = name; s.lifetime = .keepAlways
        add(s)
    }

    /// 画面の横幅からはみ出していないか
    private func inside(_ app: XCUIApplication, _ e: XCUIElement, _ label: String,
                        file: StaticString = #filePath, line: UInt = #line) {
        guard e.exists else { XCTFail("\(label) が無い", file: file, line: line); return }
        let w = app.windows.firstMatch.frame.width
        XCTAssertGreaterThanOrEqual(e.frame.minX, -0.5, "\(label) が左にはみ出す", file: file, line: line)
        XCTAssertLessThanOrEqual(e.frame.maxX, w + 0.5, "\(label) が右にはみ出す", file: file, line: line)
    }

    func test全言語で主な画面を一巡りする() {
        for lang in Self.languages {
            let app = XCUIApplication()
            let region = lang.contains("-") ? lang.replacingOccurrences(of: "-", with: "_") : lang
            app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(lang))", "-AppleLocale", region]
            app.launch()

            // 一覧
            let firstList = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "list-")).firstMatch
            XCTAssertTrue(firstList.waitForExistence(timeout: 10), "\(lang): 一覧が出ない")
            shot(app, "\(lang)-1-home")

            // 追加（雛形の一覧）
            app.buttons["addList"].tapWhenReady()
            XCTAssertTrue(app.buttons["startBlank"].waitForExistence(timeout: 5), "\(lang): 追加が開かない")
            shot(app, "\(lang)-2-add")
            app.navigationBars.buttons.element(boundBy: 0).tap()   // 戻る（押して開く画面）
            _ = firstList.waitForExistence(timeout: 5)

            // 盤面（読み上げ中）
            firstList.tapWhenReady()
            let read = app.buttons["readAloud"]
            XCTAssertTrue(read.waitForExistence(timeout: 5), "\(lang): 盤面が開かない")
            for id in ["readAloud", "readVoiceBack", "readVoiceForward", "readGapShorter", "readGapLonger",
                       "paletteBack", "paletteForward", "colorMode", "clearAll", "quickAdd", "openEdit"] {
                inside(app, app.buttons[id], "\(lang) \(id)")
            }
            read.tap()
            let started = NSPredicate(format: "value != nil AND value != ''")
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: started, object: read)], timeout: 5)
            shot(app, "\(lang)-3-board")
            read.tap()                                            // 止める

            // 1つ足す（入力の窓）
            app.buttons["quickAdd"].tapWhenReady()
            XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "\(lang): 1つ足すが開かない")
            shot(app, "\(lang)-4-quickadd")
            app.alerts.firstMatch.buttons.element(boundBy: app.alerts.firstMatch.buttons.count - 1).tap()
            if app.alerts.firstMatch.exists { app.alerts.firstMatch.buttons.firstMatch.tap() }

            // 編集
            app.buttons["openEdit"].tapWhenReady()
            XCTAssertTrue(app.textViews["listText"].waitForExistence(timeout: 5)
                          || app.textFields["listName"].waitForExistence(timeout: 2), "\(lang): 編集が開かない")
            shot(app, "\(lang)-5-edit")
            app.buttons["cancelEdit"].tapWhenReady()

            // 設定（いちばん下の投げ銭まで）
            app.buttons["openSettings"].tapWhenReady()
            XCTAssertTrue(app.segmentedControls["columns"].waitForExistence(timeout: 10), "\(lang): 設定が開かない")
            shot(app, "\(lang)-6-settings")
            let coffee = app.buttons["buyCoffee"]
            for _ in 0..<8 where !(coffee.exists && coffee.isHittable) { app.swipeUp() }
            let enabled = NSPredicate(format: "isEnabled == true")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: coffee)],
                                          timeout: 20), .completed, "\(lang): 投げ銭のボタンが使えない")
            inside(app, coffee, "\(lang) buyCoffee")
            shot(app, "\(lang)-7-tip")
            app.terminate()
        }
    }
}
