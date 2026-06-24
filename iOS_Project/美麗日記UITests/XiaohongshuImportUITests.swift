import XCTest

/// Exercises the import flow against a real public 小紅書 (Xiaohongshu)
/// share link, the same one verified manually earlier in development.
/// Unlike `ImportFlowUITests`'s apple.com case, this depends on a
/// third-party site that can change layout, rate-limit, or block
/// automated traffic at any time - so a failure here is a real signal
/// about parsing health, not just app stability.
final class XiaohongshuImportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testXiaohongshuLinkParsesToRealMetadata() throws {
        let app = XCUIApplication()
        app.launch()

        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()

        let resourcesLink = app.buttons["profileLink_資源庫"]
        XCTAssertTrue(resourcesLink.waitForExistence(timeout: 10))
        resourcesLink.tap()

        let importWizardButton = app.buttons["匯入精靈"]
        XCTAssertTrue(importWizardButton.waitForExistence(timeout: 10))
        importWizardButton.tap()

        let urlField = app.textFields["來源連結"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 10))
        urlField.tap()
        urlField.typeText("http://xhslink.com/m/44H2lpWj2c")

        let parseButton = app.buttons["開始解析"]
        XCTAssertTrue(parseButton.exists)
        parseButton.tap()

        // Short-link redirect + page fetch + HTML parsing over a real
        // network call to a third-party site, so give it a generous window.
        let saveButton = app.buttons["保存到資源庫"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 45), "Preview should appear once xiaohongshu parsing completes (or falls back).")

        let titleElement = app.staticTexts["metadataHero.title"]
        XCTAssertTrue(titleElement.waitForExistence(timeout: 5))
        let parsedTitle = titleElement.label

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "xiaohongshu-import-preview"
        attachment.lifetime = .keepAlways
        add(attachment)

        // "小紅書收藏" is the client-side fallback title used only when
        // metadata extraction found nothing at all - asserting against it
        // distinguishes "really parsed the page" from "silently failed but
        // still let the user save a near-empty placeholder".
        XCTAssertNotEqual(
            parsedTitle,
            "小紅書收藏",
            "Title still equals the generic fallback - xiaohongshu parsing likely failed silently (blocked, redirected, or page structure changed). Parsed title was: \(parsedTitle)"
        )

        saveButton.tap()

        let recentImportsHeading = app.staticTexts["最近匯入"]
        XCTAssertTrue(recentImportsHeading.waitForExistence(timeout: 10))
    }
}
