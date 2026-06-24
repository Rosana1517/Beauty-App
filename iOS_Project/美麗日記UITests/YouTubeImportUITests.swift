import XCTest

/// Exercises the import flow against a real, stable, public YouTube video.
/// No YOUTUBE_API_KEY is configured for CI, so this exercises the fallback
/// HTML/OpenGraph parsing path (CompositeResourceImportService falls back
/// to that path whenever AppRuntimeConfiguration.youtubeAPIKey is empty),
/// not the YouTube Data API path.
final class YouTubeImportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testYouTubeLinkParsesToRealMetadata() throws {
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
        // youtu.be/dQw4w9WgXcQ - one of the most stable, unlikely-to-be-removed
        // public videos on the platform, useful as a long-lived test fixture.
        urlField.typeText("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

        let parseButton = app.buttons["開始解析"]
        XCTAssertTrue(parseButton.exists)
        parseButton.tap()

        let saveButton = app.buttons["保存到資源庫"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 30), "Preview should appear once YouTube parsing completes (or falls back).")

        let titleElement = app.staticTexts["metadataHero.title"]
        XCTAssertTrue(titleElement.waitForExistence(timeout: 5))
        let parsedTitle = titleElement.label

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "youtube-import-preview"
        attachment.lifetime = .keepAlways
        add(attachment)

        // "YouTube 收藏" is the client-side fallback title used only when
        // metadata extraction found nothing at all.
        XCTAssertNotEqual(
            parsedTitle,
            "YouTube 收藏",
            "Title still equals the generic fallback - YouTube OpenGraph parsing likely failed. Parsed title was: \(parsedTitle)"
        )

        saveButton.tap()

        let recentImportsHeading = app.staticTexts["最近匯入"]
        XCTAssertTrue(recentImportsHeading.waitForExistence(timeout: 10))
    }
}
