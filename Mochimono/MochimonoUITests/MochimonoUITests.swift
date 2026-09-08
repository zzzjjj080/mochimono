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
        app.buttons["list-国内旅行"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 5))

        app.buttons["item-財布"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["1/20"].waitForExistence(timeout: 3))

        app.buttons["item-財布"].tapWhenReady()      // もう一度で外れる
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 3))
    }

    /// 列数のセグメント。合成タップでは動かなかったので、ここで確かめる。
    func test列数を変えられる() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        app.buttons["openSettings"].tapWhenReady()

        let columns = app.segmentedControls["columns"]
        XCTAssertTrue(columns.waitForExistence(timeout: 5))
        XCTAssertTrue(columns.buttons["4列"].isSelected)
        columns.buttons["2列"].tap()
        XCTAssertTrue(columns.buttons["2列"].isSelected)
    }

    /// 明るさのセグメント。アプリ全体に効く。
    func test明るさを変えられる() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        app.buttons["openSettings"].tapWhenReady()

        let appearance = app.segmentedControls["appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        XCTAssertTrue(appearance.buttons["自動"].isSelected)
        appearance.buttons["ダーク"].tap()
        XCTAssertTrue(appearance.buttons["ダーク"].isSelected)
    }

    /// 配色は矢印で送る。**設定画面を開かずに、リストを見たまま変えられること。**
    func test矢印で配色を送れる() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        let number = app.staticTexts["paletteNumber"]
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        let before = number.label

        app.buttons["paletteForward"].tapWhenReady()
        XCTAssertNotEqual(number.label, before)

        app.buttons["paletteBack"].tapWhenReady()
        XCTAssertEqual(number.label, before)
    }

    /// 配色はリストごと。片方を送っても、もう片方は変わらない。
    func test配色はリストごとに保たれる() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        let number = app.staticTexts["paletteNumber"]
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        app.buttons["paletteForward"].tapWhenReady()
        let changed = number.label
        app.navigationBars.buttons.element(boundBy: 0).tapWhenReady()

        app.buttons["list-街中"].tapWhenReady()
        XCTAssertTrue(number.waitForExistence(timeout: 5))
        XCTAssertNotEqual(number.label, changed, "別のリストの配色まで動いている")
    }

    /// 設定画面からは配色を触らせない。
    func test設定画面に配色は無い() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        app.buttons["openSettings"].tapWhenReady()
        XCTAssertTrue(app.segmentedControls["columns"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["paletteNumber"].exists)
    }

    /// 破壊的な操作は確認を通る。**やめれば何も起きない。**
    func test全部外すは確認を通る() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        app.buttons["item-財布"].tapWhenReady()
        app.buttons["item-常備薬"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["2/20"].waitForExistence(timeout: 3))

        // 確認ダイアログの中を指す。
        // ・画面本体にも「全部外す」ボタンがあるので、app.buttons[...] だとそちらに当たる
        // ・添字は identifier しか見ない。ダイアログのボタンには identifier が無いので label で引く
        app.buttons["clearAll"].tapWhenReady()
        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "やめる").tap()
        XCTAssertTrue(app.staticTexts["2/20"].waitForExistence(timeout: 3))   // 消えていない

        app.buttons["clearAll"].tapWhenReady()
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "全部外す").tap()
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 3))
    }

    /// 編集してもチェックが飛ばない。Coreのテストと同じことを、画面越しにも見ておく。
    func test編集してもチェックが残る() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        app.buttons["item-財布"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["1/20"].waitForExistence(timeout: 3))

        app.buttons["openEdit"].tapWhenReady()
        let editor = app.textViews["listText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        // ただ tap すると触れた位置にカーソルが入り、既にある行の途中に割り込む。
        // 末尾より下を押して、文末に置く。
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.97)).tap()
        editor.typeText("\nスパイク2")
        app.buttons["save"].tapWhenReady()

        XCTAssertTrue(app.staticTexts["1/21"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["item-スパイク2"].exists)
    }
    /// 雛形を選ぶと、中身の入ったリストがそのまま開く。
    func test雛形からリストを追加できる() {
        let app = launch()
        app.buttons["addList"].tapWhenReady()
        let camp = app.buttons["preset-camp"]
        XCTAssertTrue(camp.waitForExistence(timeout: 5))
        camp.tap()

        // 追加の画面には戻らず、作ったリストが開いている
        XCTAssertTrue(app.buttons["item-テント"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["openEdit"].exists)

        // 一覧にも増えている
        app.navigationBars.buttons.element(boundBy: 0).tapWhenReady()
        XCTAssertTrue(app.buttons["list-キャンプ・BBQ"].waitForExistence(timeout: 3))
    }

    /// 白紙から作ると、すぐ書ける状態になる。
    func test白紙から作ると編集画面が開く() {
        let app = launch()
        app.buttons["addList"].tapWhenReady()
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
        app.buttons["swipeDelete"].tapWhenReady()

        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "やめる").tap()
        XCTAssertTrue(app.buttons["list-街中"].waitForExistence(timeout: 3))   // 消えていない

        app.buttons["list-街中"].swipeLeft()
        app.buttons["swipeDelete"].tapWhenReady()
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "削除する").tap()
        XCTAssertFalse(app.buttons["list-街中"].waitForExistence(timeout: 3))
    }

    /// 編集画面を開かずに1つ足せる。
    func testクイック追加で1つ足せる() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 5))

        app.buttons["quickAdd"].tapWhenReady()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("虫除け")
        app.alerts.firstMatch.button(labeled: "足す").tap()

        XCTAssertTrue(app.staticTexts["0/21"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["item-虫除け"].exists)
    }

    /// やめれば何も足さない。
    func testクイック追加をやめれば増えない() {
        let app = launch()
        app.buttons["list-国内旅行"].tapWhenReady()
        app.buttons["quickAdd"].tapWhenReady()
        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.button(labeled: "やめる").tap()
        XCTAssertTrue(app.staticTexts["0/20"].waitForExistence(timeout: 3))
    }

    /// 並べ替え。編集モードに入ってから掴んで動かす。
    func testリストを並べ替えられる() {
        let app = launch()
        let first = app.buttons["list-街中"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertLessThan(first.frame.minY, app.buttons["list-国内旅行"].frame.minY)

        app.buttons["reorder"].tapWhenReady()          // EditButton
        // **行の本体ではなく、右端の掴む部分を引く。** 本体を引いても並べ替えは始まらない。
        let window = app.windows.firstMatch
        let target = app.buttons["list-国内旅行"]
        let handleX = 0.93
        let from = window.coordinate(withNormalizedOffset:
            CGVector(dx: handleX, dy: first.frame.midY / window.frame.height))
        let to = window.coordinate(withNormalizedOffset:
            CGVector(dx: handleX, dy: (target.frame.maxY + 8) / window.frame.height))
        from.press(forDuration: 1.0, thenDragTo: to)
        app.buttons["reorder"].tapWhenReady()          // 完了

        // 街中が国内旅行より下に来ていること
        XCTAssertGreaterThan(app.buttons["list-街中"].frame.minY,
                             app.buttons["list-国内旅行"].frame.minY)
    }

    /// 文字を大きくする設定に追従すること。
    /// **列が減ることで確かめる。** 減らさないと自動縮小がかかって元の大きさに戻る。
    func test文字を大きくすると列が減る() {
        let normal = XCUIApplication()
        normal.launchArguments = ["-ui-testing"]
        normal.launch()
        normal.buttons["list-国内旅行"].tap()
        let narrow = normal.buttons["item-財布"]
        XCTAssertTrue(narrow.waitForExistence(timeout: 5))
        let narrowWidth = narrow.frame.width
        normal.terminate()

        let big = XCUIApplication()
        big.launchArguments = ["-ui-testing",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXL"]
        big.launch()
        big.buttons["list-国内旅行"].tap()
        let wide = big.buttons["item-財布"]
        XCTAssertTrue(wide.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(wide.frame.width, narrowWidth * 1.4,
                             "文字を大きくしても1マスの幅が変わっていない（列が減っていない）")
    }

    /// 複製は左からのスワイプ。**削除と同じ側に置かない。**
    func testスワイプで複製できる() {
        let app = launch()
        let row = app.buttons["list-街中"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["swipeDuplicate"].tapWhenReady()

        let copy = app.buttons["list-街中のコピー"]
        XCTAssertTrue(copy.waitForExistence(timeout: 3))

        // 中身がそのまま写っていること
        copy.tap()
        XCTAssertTrue(app.staticTexts["0/10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-モバイル充電"].exists)
    }

    /// 写すのは書いた内容だけ。前の回の進み具合は持ち越さない。
    func test複製にチェックは持ち越さない() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["item-財布"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["1/10"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let row = app.buttons["list-街中"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["swipeDuplicate"].tapWhenReady()

        app.buttons["list-街中のコピー"].tapWhenReady()
        XCTAssertTrue(app.staticTexts["0/10"].waitForExistence(timeout: 5))
    }

    /// 「残りだけ」で、持ったものが盤面から消える。出かける直前の見かた。
    func test残りだけにすると持ったものが消える() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        let 財布 = app.buttons["item-財布"]
        財布.tapWhenReady()
        XCTAssertTrue(app.staticTexts["1/10"].waitForExistence(timeout: 3))

        app.buttons["remainingOnly"].tapWhenReady()
        XCTAssertFalse(財布.waitForExistence(timeout: 2), "持ったものが残りだけの表示に出ている")
        XCTAssertTrue(app.buttons["item-スマホ"].exists, "まだのものまで消えている")

        app.buttons["remainingOnly"].tapWhenReady()      // 戻す
        XCTAssertTrue(財布.waitForExistence(timeout: 3))
    }

    /// 残りだけの表示は保存しない。開き直したら全部見えていること。
    func test残りだけは開き直すと戻る() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        app.buttons["item-財布"].tapWhenReady()
        app.buttons["remainingOnly"].tapWhenReady()
        XCTAssertFalse(app.buttons["item-財布"].waitForExistence(timeout: 2))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["list-街中"].tapWhenReady()
        XCTAssertTrue(app.buttons["item-財布"].waitForExistence(timeout: 5))
    }

    /// 全部そろうと、一覧に「前回」が出る。使い回すリストは、いつ使ったかが手がかりになる。
    func test全部そろうと前回の記録が残る() {
        let app = launch()
        XCTAssertFalse(app.staticTexts["lastCompleted-街中"].exists)

        app.buttons["list-街中"].tapWhenReady()
        for name in ["財布", "スマホ", "鍵", "ハンカチ", "イヤホン",
                     "充電器", "モバイル充電", "目薬", "リップ", "マスク"] {
            app.buttons["item-\(name)"].tapWhenReady()
        }
        XCTAssertTrue(app.staticTexts["10/10"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let last = app.staticTexts["lastCompleted-街中"]
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        XCTAssertEqual(last.label, "前回 今日そろった")
    }

    /// 外したのはチェックであって記録ではない。全部外しても「前回」は消えない。
    func test全部外しても前回の記録は消えない() {
        let app = launch()
        app.buttons["list-街中"].tapWhenReady()
        for name in ["財布", "スマホ", "鍵", "ハンカチ", "イヤホン",
                     "充電器", "モバイル充電", "目薬", "リップ", "マスク"] {
            app.buttons["item-\(name)"].tapWhenReady()
        }
        app.buttons["clearAll"].tapWhenReady()
        app.alerts.firstMatch.button(labeled: "全部外す").tap()
        XCTAssertTrue(app.staticTexts["0/10"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["lastCompleted-街中"].waitForExistence(timeout: 5))
    }

}

extension XCUIElement {
    /// **出てくるのを待ってから押す。**
    /// 押してすぐ次を触ると、画面の切り替わりが終わっておらず、
    /// 実装は正しいのにテストだけが落ちる（落ちる場所が毎回変わるのが目印）。
    func tapWhenReady(_ timeout: TimeInterval = 15,
                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForExistence(timeout: timeout),
                      "出てきませんでした: \(self)", file: file, line: line)
        tap()
    }

    /// 表示文字で引く。確認ダイアログのボタンには identifier が付かない。
    func button(labeled label: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
