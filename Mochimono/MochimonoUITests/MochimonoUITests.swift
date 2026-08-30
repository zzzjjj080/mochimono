import XCTest

/// シートやセグメントは、合成タップ（simctl経由の座標タップ）では動かない。
/// **正規の経路はこちら。** ここで通れば、実装ではなく確認方法の問題だと切り分けられる。
/// （引き継ぎ書 4-24）
final class MochimonoUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    /// 持ち物をタップすると持った印が付き、数が増える。
    func testタップで持った印が付く() {
        let app = launch()
        app.buttons["list-国内旅行"].tap()
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 5))

        app.buttons["item-財布"].tap()
        XCTAssertTrue(app.staticTexts["1/20"].waitForExistence(timeout: 3))

        app.buttons["item-財布"].tap()      // もう一度で外れる
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 3))
    }

    /// 列数のセグメント。合成タップでは動かなかったので、ここで確かめる。
    func test列数を変えられる() {
        let app = launch()
        app.buttons["list-国内旅行"].tap()
        app.buttons["openSettings"].tap()

        let columns = app.segmentedControls["columns"]
        XCTAssertTrue(columns.waitForExistence(timeout: 5))
        XCTAssertTrue(columns.buttons["4列"].isSelected)
        columns.buttons["2列"].tap()
        XCTAssertTrue(columns.buttons["2列"].isSelected)
    }

    /// 明るさのセグメント。アプリ全体に効く。
    func test明るさを変えられる() {
        let app = launch()
        app.buttons["list-国内旅行"].tap()
        app.buttons["openSettings"].tap()

        let appearance = app.segmentedControls["appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        XCTAssertTrue(appearance.buttons["自動"].isSelected)
        appearance.buttons["ダーク"].tap()
        XCTAssertTrue(appearance.buttons["ダーク"].isSelected)
    }

    /// 配色はリストごと。野球を変えても街中は変わらない。
    func test配色はリストごとに保たれる() {
        let app = launch()
        app.buttons["list-国内旅行"].tap()
        app.buttons["openSettings"].tap()
        app.buttons["palette-mono"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()   // 戻る
        app.navigationBars.buttons.element(boundBy: 0).tap()   // 一覧へ

        app.buttons["list-街中"].tap()
        app.buttons["openSettings"].tap()
        // 街中はカラフルのまま
        XCTAssertTrue(app.buttons["palette-colorful"].waitForExistence(timeout: 5))
    }

    /// 破壊的な操作は確認を通る。**やめれば何も起きない。**
    func test全部外すは確認を通る() {
        let app = launch()
        app.buttons["list-国内旅行"].tap()
        app.buttons["item-財布"].tap()
        app.buttons["item-常備薬"].tap()
        XCTAssertTrue(app.staticTexts["2/20"].waitForExistence(timeout: 3))

        // 確認ダイアログの中を指す。
        // ・画面本体にも「全部外す」ボタンがあるので、app.buttons[...] だとそちらに当たる
        // ・添字は identifier しか見ない。ダイアログのボタンには identifier が無いので label で引く
        app.buttons["clearAll"].tap()
        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "やめる").tap()
        XCTAssertTrue(app.staticTexts["2/20"].waitForExistence(timeout: 3))   // 消えていない

        app.buttons["clearAll"].tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "全部外す").tap()
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 3))
    }

    /// 編集してもチェックが飛ばない。Coreのテストと同じことを、画面越しにも見ておく。
    func test編集してもチェックが残る() {
        let app = launch()
        app.buttons["list-国内旅行"].tap()
        app.buttons["item-財布"].tap()
        XCTAssertTrue(app.staticTexts["1/20"].waitForExistence(timeout: 3))

        app.buttons["openEdit"].tap()
        let editor = app.textViews["listText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        // ただ tap すると触れた位置にカーソルが入り、既にある行の途中に割り込む。
        // 末尾より下を押して、文末に置く。
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.97)).tap()
        editor.typeText("\nスパイク2")
        app.buttons["save"].tap()

        XCTAssertTrue(app.staticTexts["1/21"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["item-スパイク2"].exists)
    }
    /// 雛形を選ぶと、中身の入ったリストがそのまま開く。
    func test雛形からリストを追加できる() {
        let app = launch()
        app.buttons["addList"].tap()
        let camp = app.buttons["preset-camp"]
        XCTAssertTrue(camp.waitForExistence(timeout: 5))
        camp.tap()

        // 追加の画面には戻らず、作ったリストが開いている
        XCTAssertTrue(app.buttons["item-テント"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["openEdit"].exists)

        // 一覧にも増えている
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["list-キャンプ・BBQ"].waitForExistence(timeout: 3))
    }

    /// 白紙から作ると、すぐ書ける状態になる。
    func test白紙から作ると編集画面が開く() {
        let app = launch()
        app.buttons["addList"].tap()
        // 雛形が先に並ぶので、下まで送らないと存在しない（Listは見えていない行を作らない）
        let blank = app.buttons["startBlank"]
        for _ in 0..<8 where !blank.exists { app.swipeUp() }
        XCTAssertTrue(blank.waitForExistence(timeout: 3))
        blank.tap()
        XCTAssertTrue(app.textViews["listText"].waitForExistence(timeout: 5))
    }

    /// スワイプで消せる。ただし**確認は必ず通る**（手書きのリストが一度で消えると困る）。
    func testスワイプ削除は確認を通る() {
        let app = launch()
        let row = app.buttons["list-街中"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["swipeDelete"].tap()

        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "やめる").tap()
        XCTAssertTrue(app.buttons["list-街中"].waitForExistence(timeout: 3))   // 消えていない

        app.buttons["list-街中"].swipeLeft()
        app.buttons["swipeDelete"].tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "削除する").tap()
        XCTAssertFalse(app.buttons["list-街中"].waitForExistence(timeout: 3))
    }

}

extension XCUIElement {
    /// 表示文字で引く。確認ダイアログのボタンには identifier が付かない。
    func button(labeled label: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
