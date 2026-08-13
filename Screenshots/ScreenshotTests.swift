import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        setupSnapshot(app)
        app.launch()
    }

    func testScreenshots() {
        snapshot("01_Main")
        app.buttons["info.circle"].activate()
        snapshot("02_About")
        goBack()
        app.buttons["questionmark.circle"].activate()
        snapshot("03_Help")
        goBack()
        app.buttons["download_voice_model"].activate()
        scrollDown()
        snapshot("04_DownloadLanguages")
        goBack()
        
    }
    
    private func goBack() {
#if os(iOS)
        let backButtonId = "BackButton"
#elseif os(macOS)
        let backButtonId = "chevron.backward"
#endif
        app.buttons[backButtonId].activate()
    }
    
    private func scrollDown() {
#if os(iOS)
        app.swipeUp(velocity: .fast)
#elseif os(macOS)
        app.scrollViews.firstMatch.scroll(byDeltaX: 0.0, deltaY: -200.0)
#endif
    }
}

extension XCUIElement {
    fileprivate func activate() {
#if os(iOS)
    tap()
#elseif os(macOS)
    click()
#endif
    }
}
