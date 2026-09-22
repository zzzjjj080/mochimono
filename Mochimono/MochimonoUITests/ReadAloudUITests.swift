import XCTest

/// 手ぶらで準備する読み上げ。
/// **声の聞き取りはシミュレータで試せない**ので、ここでは画面のボタンで同じ道を通す
/// （声の「持った」と画面の「持った」は `send(_:)` で合流する）。声そのものは実機で確かめる。
final class ReadAloudUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // マイクの許可の窓で止まらないよう、声の合図を切る
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
                               "-ReadAloudNoMic"]
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

    func test持ったで印が付いて次へ進む() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["readAloud"].tapWhenReady()
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
        app.buttons["readAloud"].tapWhenReady()
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
        app.buttons["readAloud"].tapWhenReady()
        reading(app, is: "財布")
        app.buttons["readPacked"].tapWhenReady()
        XCTAssertTrue(app.buttons["completeBanner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["paletteNumber"].waitForExistence(timeout: 10))
    }
}
