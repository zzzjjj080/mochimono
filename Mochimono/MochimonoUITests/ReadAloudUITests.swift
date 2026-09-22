import XCTest

/// 手ぶらで準備する読み上げ。音そのものは実機で確かめる。
final class ReadAloudUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        return app
    }

    private func reading(_ app: XCUIApplication, is text: String,
                         file: StaticString = #filePath, line: UInt = #line) {
        let label = app.staticTexts["readingItem"]
        let found = NSPredicate(format: "label == %@", text)
        let exp = XCTNSPredicateExpectation(predicate: found, object: label)
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: 10), .completed,
                       "読んでいるのが「\(text)」にならない（いまは「\(label.exists ? label.label : "なし")」）",
                       file: file, line: line)
    }

    /// 間隔をいちばん長く（5秒）してから読み始める。
    /// **既定の間隔では、押す前に次へ進んでしまう**ので、ボタンで答える確認はこれを通す。
    private func startSlow(_ app: XCUIApplication) {
        app.buttons["readAloud"].tapWhenReady()
        let longer = app.buttons["readGapLonger"]
        XCTAssertTrue(longer.waitForExistence(timeout: 5))
        while longer.isEnabled { longer.tap() }
        app.buttons["readAloud"].tap()                 // いったん止めて、頭から読み直す
        XCTAssertTrue(app.staticTexts["paletteNumber"].waitForExistence(timeout: 5))
        app.buttons["readAloud"].tap()
    }

    func test持ったで印が付いて次へ進む() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        startSlow(app)
        reading(app, is: "財布")
        // 読んでいる間は、配色の段が読み上げの段に入れ替わる
        XCTAssertFalse(app.staticTexts["paletteNumber"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "reading"; shot.lifetime = .keepAlways
        add(shot)

        app.buttons["readPacked"].tapWhenReady()
        reading(app, is: "スマホ")
        XCTAssertTrue(app.buttons["item-財布"].isSelected)
        XCTAssertTrue(app.staticTexts["1 / 10"].exists)

        app.buttons["readNext"].tapWhenReady()      // 飛ばした物に印は付かない
        reading(app, is: "鍵")
        XCTAssertFalse(app.buttons["item-スマホ"].isSelected)

        app.buttons["readAloud"].tapWhenReady()     // もう一度押すと止まる
        XCTAssertTrue(app.staticTexts["paletteNumber"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["readingItem"].exists)
    }

    /// 持った物は読まない。最初から、まだの先頭を読む。
    func test持った物は飛ばして読む() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["item-財布"].tapWhenReady()
        app.buttons["item-スマホ"].tapWhenReady()
        app.buttons["readAloud"].tapWhenReady()
        reading(app, is: "鍵")
    }

    /// 最後の1つまで行ったら頭へ戻る。飛ばした物をもう一度読む。
    func test一周したら頭へ戻る() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        for name in MochimonoUITests.街中のすべて.dropFirst(2) { app.buttons["item-\(name)"].tapWhenReady() }
        startSlow(app)
        reading(app, is: "財布")
        app.buttons["readNext"].tapWhenReady()
        reading(app, is: "スマホ")
        app.buttons["readNext"].tapWhenReady()
        reading(app, is: "財布")
    }

    /// 全部そろったら、読み上げは自分で止まる。
    func testそろったら止まる() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        for name in MochimonoUITests.街中のすべて.dropFirst() { app.buttons["item-\(name)"].tapWhenReady() }
        startSlow(app)
        reading(app, is: "財布")
        app.buttons["readPacked"].tapWhenReady()
        XCTAssertTrue(app.buttons["completeBanner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["paletteNumber"].waitForExistence(timeout: 10))
    }

    /// 読んでいる物のマスを押したら、残りの間を待たずに次へ進む。
    func testマスを押すと次へ進む() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        // 間隔をいちばん長く（5秒）して、待ちを打ち切ったことが分かるようにする
        startSlow(app)
        reading(app, is: "財布")
        app.buttons["item-財布"].tap()
        let found = NSPredicate(format: "label == %@", "スマホ")
        let exp = XCTNSPredicateExpectation(predicate: found, object: app.staticTexts["readingItem"])
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: 3.5), .completed, "5秒待たずに次へ進むこと")
    }

    /// 間隔は読みながら変えられ、次に開いても残っている。
    func test間隔を変えられて残る() {
        var app = launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["readAloud"].tapWhenReady()
        let gap = app.staticTexts["readGap"]
        XCTAssertTrue(gap.waitForExistence(timeout: 5))
        XCTAssertEqual(gap.label, "0.8秒")
        app.buttons["readGapLonger"].tap()
        XCTAssertEqual(gap.label, "1.0秒")
        app.buttons["readGapShorter"].tap()
        app.buttons["readGapShorter"].tap()
        XCTAssertEqual(gap.label, "0.5秒")

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-keep", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]   // 保存を消さずに開き直す
        app.launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["readAloud"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["readGap"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["readGap"].label, "0.5秒")
    }
}
