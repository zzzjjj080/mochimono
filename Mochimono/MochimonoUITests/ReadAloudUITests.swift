import XCTest

/// 手ぶらで準備する読み上げ。音そのものは実機で確かめる。
///
/// いま読んでいる物は、読み上げボタンの値（`accessibilityValue`）で見る。
/// 画面では盤面の枠で分かるので、文字では出していない。
final class ReadAloudUITests: XCTestCase {

    private func launch(keep: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [keep ? "-ui-testing-keep" : "-ui-testing",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        return app
    }

    private func reading(_ app: XCUIApplication, is text: String, timeout: TimeInterval = 10,
                         file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons["readAloud"]
        let found = NSPredicate(format: "value == %@", text)
        let exp = XCTNSPredicateExpectation(predicate: found, object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [exp], timeout: timeout), .completed,
                       "読んでいるのが「\(text)」にならない（いまは「\(button.value as? String ?? "なし")」）",
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

    /// 間隔を `longerTaps` 段伸ばしてから読み始める。
    /// **既定の0.3秒では、確かめる前に次へ進んでしまう**ので、読む順を見る確認はこれを通す。
    private func start(_ app: XCUIApplication, longerTaps: Int) {
        let longer = app.buttons["readGapLonger"]
        XCTAssertTrue(longer.waitForExistence(timeout: 5))
        for _ in 0..<longerTaps { longer.tap() }
        app.buttons["readAloud"].tap()
    }

    /// 読み上げの段は盤面の下のいちばん上。色の段・操作の段より上にある。
    func test読み上げの段は色の段より上() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        let read = app.buttons["readAloud"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        XCTAssertLessThan(read.frame.maxY, app.buttons["paletteForward"].frame.minY)
        XCTAssertLessThan(app.buttons["paletteForward"].frame.maxY, app.buttons["openEdit"].frame.minY)
        XCTAssertGreaterThanOrEqual(read.frame.height, 40)          // 押しやすい大きさ
        XCTAssertFalse(app.navigationBars.buttons["readAloud"].exists)   // 右上からは外した
    }

    /// 読んでいる物のマスを押したら、残りの間を待たずに次へ進む。もう一度押せば止まる。
    func testマスを押すと次へ進む() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        start(app, longerTaps: 7)                       // 5秒。待ちを打ち切ったことが分かるように
        reading(app, is: "財布")
        XCTAssertTrue(app.buttons["paletteForward"].exists)           // 読んでいる間も色の段は残る
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "reading"; shot.lifetime = .keepAlways
        add(shot)

        app.buttons["item-財布"].tap()
        reading(app, is: "スマホ", timeout: 3.5)        // 5秒待たずに次へ
        XCTAssertTrue(app.staticTexts["1 / 10"].exists)

        app.buttons["readAloud"].tap()                  // もう一度押すと止まる
        let stopped = NSPredicate(format: "label == %@", "読み上げ")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: stopped,
                                                                    object: app.buttons["readAloud"])],
                                      timeout: 5), .completed)
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
        let stopped = NSPredicate(format: "label == %@", "読み上げ")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: stopped,
                                                                    object: app.buttons["readAloud"])],
                                      timeout: 10), .completed)
    }

    /// 間隔の既定は最短の0.3秒。読む前から変えられ、次に開いても残っている。
    func test間隔を変えられて残る() {
        var app = launch()
        app.buttons["list-街中"].tapWhenReady()
        let gap = app.staticTexts["readGap"]
        XCTAssertTrue(gap.waitForExistence(timeout: 5))
        XCTAssertEqual(gap.label, "0.3秒")
        XCTAssertFalse(app.buttons["readGapShorter"].isEnabled)    // これより短くはできない
        app.buttons["readGapLonger"].tap()
        XCTAssertEqual(gap.label, "0.5秒")

        app.terminate()
        app = launch(keep: true)                                     // 保存を消さずに開き直す
        app.buttons["list-街中"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["readGap"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["readGap"].label, "0.5秒")
    }

    /// 声は5つを番号で送る。端で一周し、次に開いても残っている。
    func test声を送れて残る() {
        var app = launch()
        app.buttons["list-街中"].tapWhenReady()
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
        app = launch(keep: true)
        app.buttons["list-街中"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["readVoice"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["readVoice"].label, "2 / 5")
    }
}
