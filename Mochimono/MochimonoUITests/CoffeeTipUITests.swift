import XCTest

/// 「開発者にコーヒーを奢る」の見た目。
///
/// **`.storekit` はスキームで指定している**（Coffee.storekit）。
/// `xcrun simctl launch` では効かないので、価格が出た状態を撮れるのはここだけ（引き継ぎ書 11-9）。
/// App内課金の審査用スクリーンショット（1枚必須）は、このテストの添付から取り出す。
final class CoffeeTipUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // 背景が空だと何のアプリか分からないので、見本の状態で起動する
        app.launchArguments = ["-screenshot-demo"]
        app.launch()
        return app
    }

    /// 設定のいちばん下に出ていること。価格はStoreKitが返した文字列がそのまま出る。
    func test投げ銭の行が価格つきで出る() {
        let app = launchApp()
        // 出てくるのを待ってから押す。待たないと、遷移が終わる前に次を触って落ちる
        app.buttons["list-国内旅行"].tapWhenReady()
        app.buttons["openSettings"].tapWhenReady()

        // 設定が開いたことを、確実にあるもので確かめる
        XCTAssertTrue(app.segmentedControls["columns"].waitForExistence(timeout: 15),
                      "設定が開いていない")

        // 投げ銭はいちばん下。Listは見えていない行を作らないので、まず送る
        let coffee = app.buttons["buyCoffee"]
        for _ in 0..<8 {
            if coffee.exists && coffee.isHittable { break }
            app.swipeUp()
        }
        if !coffee.exists {
            // 商品が読めていないと別の文言が出る。どちらなのか分かるようにしておく
            let unavailable = app.staticTexts["いまは受け付けられません"].exists
            XCTFail(unavailable
                    ? "商品が読めていない（.storekit のパスを疑う）"
                    : "投げ銭の行が見つからない")
            return
        }

        // **商品の読み込みは非同期。** 出てきた直後は無効なので、有効になるまで待つ
        let enabled = NSPredicate(format: "isEnabled == true")
        let waited = XCTNSPredicateExpectation(predicate: enabled, object: coffee)
        XCTAssertEqual(XCTWaiter().wait(for: [waited], timeout: 20), .completed,
                       "ボタンが無効のまま。商品が読めていない（.storekit のパスを疑う）")
        // 価格は StoreKit が返した文字列をそのまま出す。決め打ちしない。
        // シミュレータのストアフロントは米国なので $ 表記になる。実機・本番は ¥200（11-9）
        XCTAssertTrue(coffee.label.contains("$") || coffee.label.contains("¥"),
                      "価格が出ていない。label=[\(coffee.label)]")
        XCTAssertTrue(app.staticTexts["このアプリが気に入ったら"].exists, "見出しが出ていない")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "coffee-tip"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
