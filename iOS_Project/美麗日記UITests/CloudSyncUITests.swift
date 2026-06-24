import XCTest

/// Signs in with a dedicated CI-only Supabase test account
/// (ci-test@beautifuldiary.app) and confirms the app reaches the
/// "authenticated + synced" state through the real Supabase backend,
/// not a mock. Credentials are read from the environment
/// (CI_TEST_USER_EMAIL / CI_TEST_USER_PASSWORD) rather than hardcoded, and
/// the test skips itself if they aren't present (e.g. local runs without
/// the CI secrets configured).
final class CloudSyncUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignInReachesAuthenticatedAndSyncsResources() throws {
        // The XCUITest runner process only sees environment variables that
        // were baked into the scheme's Test action (project.yml's
        // `scheme.test.environmentVariables`) at `xcodegen generate` time -
        // a plain `env:` block on the CI xcodebuild step is invisible here,
        // confirmed by two earlier CI runs where this test always
        // self-skipped despite the secrets being set on that step.
        let env = ProcessInfo.processInfo.environment
        guard
            let email = env["CI_TEST_USER_EMAIL"], !email.isEmpty,
            let password = env["CI_TEST_USER_PASSWORD"], !password.isEmpty
        else {
            throw XCTSkip("CI_TEST_USER_EMAIL/CI_TEST_USER_PASSWORD not provided; skipping cloud sync test.")
        }

        // XCUIApplication().launch() does NOT automatically inherit the
        // scheme's environment variables for the app-under-test process -
        // those only apply when Xcode itself launches the app via Run.
        // Forward what this test process already has (via TestAction's
        // EnvironmentVariables) explicitly, otherwise AppRuntimeConfiguration
        // .hasSupabaseConfig is false and auth never leaves .unavailable.
        let app = XCUIApplication()
        app.launchEnvironment = [
            "SUPABASE_URL": env["SUPABASE_URL"] ?? "",
            "SUPABASE_ANON_KEY": env["SUPABASE_ANON_KEY"] ?? "",
        ]
        app.launch()

        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()

        let settingsLink = app.buttons["profileLink_個人設定"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 10))
        settingsLink.tap()

        let emailField = app.textFields["Supabase email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "Supabase sync card should be visible on the Personal Settings screen.")
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Supabase password"]
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText(password)

        let signInButton = app.buttons["Sign in and sync"]
        XCTAssertTrue(signInButton.exists)
        signInButton.tap()

        // Real network round trip to Supabase Auth + profile upsert +
        // resource fetch, so allow a generous window.
        let statusValue = app.otherElements["supabaseSync.statusValue"]
        XCTAssertTrue(statusValue.waitForExistence(timeout: 5))

        let reachedAuthenticated = NSPredicate(format: "value == %@", "Authenticated")
        let expectation = XCTNSPredicateExpectation(predicate: reachedAuthenticated, object: statusValue)
        let result = XCTWaiter().wait(for: [expectation], timeout: 30)
        XCTAssertEqual(result, .completed, "Status should reach 'Authenticated' after a successful Supabase sign-in. Last seen value: \(statusValue.value ?? "nil")")

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "cloud-sync-authenticated"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Trigger an explicit sync so there's a concrete round trip (profile
        // upsert + resource fetch) beyond just the sign-in call itself.
        let syncButton = app.buttons["Sync pending resources now"]
        XCTAssertTrue(syncButton.exists)
        syncButton.tap()

        let authMessage = app.staticTexts["supabaseSync.authMessage"]
        let syncFinished = NSPredicate(format: "label CONTAINS %@", "Cloud sync finished")
        let syncExpectation = XCTNSPredicateExpectation(predicate: syncFinished, object: authMessage)
        let syncResult = XCTWaiter().wait(for: [syncExpectation], timeout: 30)
        XCTAssertEqual(syncResult, .completed, "Expected 'Cloud sync finished.' message after tapping Sync pending resources now. Last seen: \(authMessage.label)")
    }
}
