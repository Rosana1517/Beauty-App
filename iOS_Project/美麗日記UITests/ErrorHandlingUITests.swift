import XCTest

/// Confirms the app degrades gracefully instead of crashing or hanging when
/// things go wrong: an unreachable import URL, and a failed Supabase
/// sign-in. These are edge cases that the happy-path import/cloud-sync
/// tests don't exercise.
final class ErrorHandlingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testUnreachableLinkFallsBackGracefullyInsteadOfCrashing() throws {
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
        // A syntactically valid URL pointing at a domain that doesn't
        // resolve, to exercise the network-failure catch path in
        // SharedHTMLParser.parse rather than the empty/malformed-string path.
        urlField.typeText("https://this-domain-definitely-does-not-exist-zzz12345.example")

        let parseButton = app.buttons["開始解析"]
        XCTAssertTrue(parseButton.exists)
        parseButton.tap()

        // The app should still reach the preview screen (never gets stuck
        // on a spinner, never crashes) and tell the user it couldn't fetch
        // metadata rather than silently producing an empty/misleading draft.
        let saveButton = app.buttons["保存到資源庫"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 30), "App should reach the preview screen even when the fetch fails outright.")

        let errorDetail = app.staticTexts["infoCallout.detail"]
        XCTAssertTrue(errorDetail.waitForExistence(timeout: 5), "A '解析提醒' callout explaining the failure should be shown.")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "unreachable-link-fallback"
        attachment.lifetime = .keepAlways
        add(attachment)

        // The user should still be able to save (with manual completion)
        // rather than being blocked entirely by the failed fetch.
        saveButton.tap()
        let recentImportsHeading = app.staticTexts["最近匯入"]
        XCTAssertTrue(recentImportsHeading.waitForExistence(timeout: 10))
    }

    func testWrongPasswordShowsErrorInsteadOfHangingOrCrashing() throws {
        let env = ProcessInfo.processInfo.environment
        guard
            let email = env["CI_TEST_USER_EMAIL"], !email.isEmpty,
            let supabaseURL = env["SUPABASE_URL"], !supabaseURL.isEmpty,
            let supabaseAnonKey = env["SUPABASE_ANON_KEY"], !supabaseAnonKey.isEmpty
        else {
            throw XCTSkip("CI_TEST_USER_EMAIL/SUPABASE_URL/SUPABASE_ANON_KEY not provided; skipping sign-in failure test.")
        }

        let app = XCUIApplication()
        app.launchEnvironment = [
            "SUPABASE_URL": supabaseURL,
            "SUPABASE_ANON_KEY": supabaseAnonKey,
        ]
        app.launch()

        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()

        let settingsLink = app.buttons["profileLink_個人設定"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 10))
        settingsLink.tap()

        let emailField = app.textFields["Supabase email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Supabase password"]
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText("definitely-the-wrong-password-123!")

        let signInButton = app.buttons["Sign in and sync"]
        XCTAssertTrue(signInButton.exists)
        signInButton.tap()

        // Should land on an error message, not "Authenticated".
        let statusValue = app.otherElements["supabaseSync.statusValue"]
        XCTAssertTrue(statusValue.waitForExistence(timeout: 5))

        let leftSigningIn = NSPredicate(format: "value != %@", "Authenticating")
        let expectation = XCTNSPredicateExpectation(predicate: leftSigningIn, object: statusValue)
        let result = XCTWaiter().wait(for: [expectation], timeout: 30)
        XCTAssertEqual(result, .completed, "Sign-in attempt should resolve (success or failure) within 30s, not hang indefinitely.")

        XCTAssertNotEqual(
            statusValue.value as? String,
            "Authenticated",
            "A deliberately wrong password should never reach the Authenticated state."
        )

        let authMessage = app.staticTexts["supabaseSync.authMessage"]
        XCTAssertTrue(authMessage.waitForExistence(timeout: 5), "An error message should be shown explaining the failed sign-in.")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "wrong-password-error"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
