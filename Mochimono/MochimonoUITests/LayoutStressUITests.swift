import XCTest

/// 狭い画面・大きな文字・長い言語・ダークモードで、盤面の下の段が崩れないか。
///
/// 下の段は3段（読み上げ・色・操作）に増えた。**文字を大きくしたときと小さい機種（SE）で
/// はみ出す・重なる・盤面が隠れる**のを見る。写真も残して目で確かめる。
final class LayoutStressUITests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    private let bottomIDs = ["readAloud", "readVoiceBack", "readVoiceForward", "readGapShorter", "readGapLonger",
                             "paletteBack", "paletteForward", "colorMode", "clearAll", "quickAdd", "openEdit"]

    private func check(lang: String, size: String?, dark: Bool) {
        let app = XCUIApplication()
        var args = ["-ui-testing", "-AppleLanguages", "(\(lang))", "-AppleLocale", lang]
        if let size { args += ["-UIPreferredContentSizeCategoryName", size] }
        app.launchArguments = args
        app.launch()
        let label = "\(lang) \(size?.replacingOccurrences(of: "UICTContentSizeCategory", with: "") ?? "標準")\(dark ? " dark" : "")"

        if dark {                                   // 明るさはアプリの設定から
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "list-")).firstMatch.tapWhenReady()
            app.buttons["openSettings"].tapWhenReady()
            let seg = app.segmentedControls["appearance"]
            XCTAssertTrue(seg.waitForExistence(timeout: 10))
            seg.buttons.element(boundBy: 2).tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
        } else {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "list-")).firstMatch.tapWhenReady()
        }
        let read = app.buttons["readAloud"]
        XCTAssertTrue(read.waitForExistence(timeout: 10), "\(label): 盤面が開かない")

        let window = app.windows.firstMatch.frame
        var frames: [(String, CGRect)] = []
        for id in bottomIDs {
            let e = app.buttons[id]
            guard e.exists else { XCTFail("\(label): \(id) が無い"); continue }
            let f = e.frame
            XCTAssertGreaterThanOrEqual(f.minX, -0.5, "\(label): \(id) が左にはみ出す")
            XCTAssertLessThanOrEqual(f.maxX, window.maxX + 0.5, "\(label): \(id) が右にはみ出す")
            XCTAssertLessThanOrEqual(f.maxY, window.maxY + 0.5, "\(label): \(id) が下にはみ出す")
            XCTAssertGreaterThanOrEqual(f.height, 24, "\(label): \(id) が押しにくいほど小さい")
            frames.append((id, f))
        }
        // 同じ段の中で重ならない
        for (i, a) in frames.enumerated() {
            for b in frames[(i + 1)...] where a.1.intersects(b.1) && a.1.intersection(b.1).width > 1
                && a.1.intersection(b.1).height > 1 {
                XCTFail("\(label): \(a.0) と \(b.0) が重なる")
            }
        }
        // 盤面の1マス目が下の段に隠れない
        let firstTile = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "item-")).firstMatch
        if firstTile.exists, let top = frames.map(\.1.minY).min() {
            XCTAssertLessThan(firstTile.frame.minY, top, "\(label): 盤面が下の段に隠れて1マスも見えない")
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "stress \(label)"; shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    func test下の段は大きな文字と長い言語でも崩れない() {
        for size in [nil, "UICTContentSizeCategoryXXXL", "UICTContentSizeCategoryAccessibilityM",
                     "UICTContentSizeCategoryAccessibilityXXXL"] {
            for lang in ["ja", "de", "ar"] {
                check(lang: lang, size: size, dark: false)
            }
        }
    }

    func testダークモードでも崩れない() {
        for lang in ["ja", "ru"] { check(lang: lang, size: nil, dark: true) }
    }
}
