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

    /// 下準備で印を付ける。**速く続けて押すと1つ取りこぼすことがある**ので、付いたか確かめて押し直す。
    private func pack(_ app: XCUIApplication, _ names: some Sequence<String>) {
        for name in names {
            let cell = app.buttons["item-\(name)"]
            cell.tapWhenReady()
            if !cell.isSelected { cell.tap() }
            XCTAssertTrue(cell.isSelected, "下準備で「\(name)」に印が付かない")
        }
    }

    /// 間隔を `longerTaps` 段伸ばしてから、頭から読み始める。
    /// **既定の0.3秒では、確かめる前に次へ進んでしまう**ので、読む順を見る確認はこれを通す。
    private func start(_ app: XCUIApplication, longerTaps: Int) {
        app.buttons["readAloud"].tapWhenReady()
        let longer = app.buttons["readGapLonger"]
        XCTAssertTrue(longer.waitForExistence(timeout: 5))
        for _ in 0..<longerTaps { longer.tap() }
        app.buttons["readAloud"].tap()                 // いったん止めて、頭から読み直す
        XCTAssertTrue(app.staticTexts["paletteNumber"].waitForExistence(timeout: 5))
        app.buttons["readAloud"].tap()
    }

    /// 読んでいる物のマスを押したら、残りの間を待たずに次へ進む。止めれば配色の段に戻る。
    func testマスを押すと次へ進む() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        start(app, longerTaps: 7)                       // 5秒。待ちを打ち切ったことが分かるように
        reading(app, is: "財布")
        // 読んでいる間は、配色の段が読み上げの段に入れ替わる
        XCTAssertFalse(app.staticTexts["paletteNumber"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "reading"; shot.lifetime = .keepAlways
        add(shot)

        app.buttons["item-財布"].tap()
        let found = NSPredicate(format: "label == %@", "スマホ")
        let exp = XCTNSPredicateExpectation(predicate: found, object: app.staticTexts["readingItem"])
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: 3.5), .completed, "5秒待たずに次へ進むこと")
        XCTAssertTrue(app.staticTexts["1 / 10"].exists)

        app.buttons["readAloud"].tapWhenReady()     // もう一度押すと止まる
        XCTAssertTrue(app.staticTexts["paletteNumber"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["readingItem"].exists)
    }

    /// 持った物は読まない。最初から、まだの先頭を読む。
    func test持った物は飛ばして読む() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        pack(app, ["財布", "スマホ"])
        start(app, longerTaps: 7)
        reading(app, is: "鍵")
    }

    /// 最後まで行ったら頭へ戻る。まだの物をもう一度読む。
    func test一周したら頭へ戻る() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        pack(app, MochimonoUITests.街中のすべて.dropFirst(2))
        start(app, longerTaps: 3)                       // 1秒。周の切れ目は3秒
        reading(app, is: "財布")
        reading(app, is: "スマホ")
        reading(app, is: "財布")
    }

    /// 全部そろったら、読み上げは自分で止まる。
    func testそろったら止まる() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        pack(app, MochimonoUITests.街中のすべて.dropFirst())
        app.buttons["readAloud"].tapWhenReady()
        reading(app, is: "財布")
        app.buttons["item-財布"].tap()
        XCTAssertTrue(app.buttons["completeBanner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["paletteNumber"].waitForExistence(timeout: 10))
    }

    /// 間隔の既定は最短の0.3秒。読みながら変えられ、次に開いても残っている。
    func test間隔を変えられて残る() {
        var app = launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["readAloud"].tapWhenReady()
        let gap = app.staticTexts["readGap"]
        XCTAssertTrue(gap.waitForExistence(timeout: 5))
        XCTAssertEqual(gap.label, "0.3秒")
        XCTAssertFalse(app.buttons["readGapShorter"].isEnabled)    // これより短くはできない
        app.buttons["readGapLonger"].tap()
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

    /// 声は5つを番号で送る。端で一周し、次に開いても残っている。
    func test声を送れて残る() {
        var app = launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["readAloud"].tapWhenReady()
        let voice = app.staticTexts["readVoice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        XCTAssertEqual(voice.label, "1 / 5")
        app.buttons["readVoiceBack"].tap()                 // 1 の前は 5
        XCTAssertEqual(voice.label, "5 / 5")
        app.buttons["readVoiceForward"].tap()
        app.buttons["readVoiceForward"].tap()
        XCTAssertEqual(voice.label, "2 / 5")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "voice"; shot.lifetime = .keepAlways
        add(shot)

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-keep", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["readAloud"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["readVoice"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["readVoice"].label, "2 / 5")
    }
}
