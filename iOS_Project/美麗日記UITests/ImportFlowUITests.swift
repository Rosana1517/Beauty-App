import XCTest

/// Smoke-tests the actual user-facing import flow end to end inside the
/// simulator (tap-by-tap), rather than just asserting the app launches.
/// This only exercises the local-only save path (Profile > 資源庫 > 匯入精靈
/// > parse > save), which doesn't require Supabase auth or an AI provider
/// key, so it stays deterministic in CI.
final class ImportFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testImportResourceFromURLAppearsInLibrary() throws {
        let app = XCUIApplication()
        app.launch()

        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "Profile tab should exist on launch.")
        profileTab.tap()

        let resourcesLink = app.buttons["profileLink_資源庫"]
        XCTAssertTrue(resourcesLink.waitForExistence(timeout: 10), "資源庫 entry should exist under Profile.")
        resourcesLink.tap()

        let importWizardButton = app.buttons["匯入精靈"]
        XCTAssertTrue(importWizardButton.waitForExistence(timeout: 10), "匯入精靈 button should exist on Resource Library screen.")
        importWizardButton.tap()

        let urlField = app.textFields["來源連結"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 10), "URL input field should appear in the import sheet.")
        urlField.tap()
        urlField.typeText("https://www.apple.com")

        let parseButton = app.buttons["開始解析"]
        XCTAssertTrue(parseButton.exists, "Parse button should exist.")
        parseButton.tap()

        // Parsing performs a real network request, so allow generous time.
        let saveButton = app.buttons["保存到資源庫"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 30), "Import preview's save button should appear after parsing.")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "import-preview"
        attachment.lifetime = .keepAlways
        add(attachment)

        saveButton.tap()

        let recentImportsHeading = app.staticTexts["最近匯入"]
        XCTAssertTrue(recentImportsHeading.waitForExistence(timeout: 10), "Resource Library should show '最近匯入' once an item has been saved.")

        let finalScreenshot = app.screenshot()
        let finalAttachment = XCTAttachment(screenshot: finalScreenshot)
        finalAttachment.name = "resource-library-after-import"
        finalAttachment.lifetime = .keepAlways
        add(finalAttachment)
    }
}
