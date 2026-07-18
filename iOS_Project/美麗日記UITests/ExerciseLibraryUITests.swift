import XCTest

/// Covers the exercise library + AI match flows added on top of the
/// Supabase `exercise_library` table (1,324 strength moves + 48 yoga poses).
///
/// The library list reads that table with the anon key, so these tests need
/// the same Supabase config the cloud-sync test uses and skip themselves
/// when it isn't present (e.g. local runs without CI secrets).
final class ExerciseLibraryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Same constraint as CloudSyncUITests: the app-under-test process does
    /// not inherit the scheme's environment variables, so forward them
    /// explicitly or `AppRuntimeConfiguration` sees no Supabase config and
    /// the library can never load.
    private func launchConfiguredApp() throws -> XCUIApplication {
        let env = ProcessInfo.processInfo.environment
        guard
            let url = env["SUPABASE_URL"], !url.isEmpty,
            let anonKey = env["SUPABASE_ANON_KEY"], !anonKey.isEmpty
        else {
            throw XCTSkip("SUPABASE_URL/SUPABASE_ANON_KEY not provided; skipping exercise library tests.")
        }

        let app = XCUIApplication()
        app.launchEnvironment = ["SUPABASE_URL": url, "SUPABASE_ANON_KEY": anonKey]
        app.launch()
        return app
    }

    /// The exercise entries sit below the AI advice section, which can push
    /// them off screen on smaller simulators.
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    private func openExerciseSection(_ app: XCUIApplication, entryIdentifier: String) {
        let bodyTab = app.tabBars.buttons["體態"]
        XCTAssertTrue(bodyTab.waitForExistence(timeout: 10), "體態 tab should exist on launch.")
        bodyTab.tap()

        let exerciseLink = app.buttons["bodyLink_運動管理"]
        XCTAssertTrue(exerciseLink.waitForExistence(timeout: 10), "運動管理 entry should exist under 體態.")
        exerciseLink.tap()

        let entry = app.buttons[entryIdentifier]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "\(entryIdentifier) card should exist on the exercise screen.")
        scrollUntilHittable(entry, in: app)
        entry.tap()
    }

    func testExerciseLibraryLoadsAndOpensDetail() throws {
        let app = try launchConfiguredApp()
        openExerciseSection(app, entryIdentifier: "exerciseEntry.library")

        // Real Supabase round trip for the first page, so allow generous time.
        let firstCard = app.buttons["exerciseLibrary.itemCard"].firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 30), "Exercise library should load at least one item from Supabase.")

        let listScreenshot = XCTAttachment(screenshot: app.screenshot())
        listScreenshot.name = "exercise-library-list"
        listScreenshot.lifetime = .keepAlways
        add(listScreenshot)

        firstCard.tap()

        // Strength rows carry step-by-step Chinese instructions; yoga rows
        // fall back to a description block. Accept either so the assertion
        // doesn't depend on which row happens to sort first.
        let steps = app.staticTexts["動作步驟"]
        let description = app.staticTexts["動作說明"]
        let detailAppeared = steps.waitForExistence(timeout: 15) || description.waitForExistence(timeout: 5)
        XCTAssertTrue(detailAppeared, "Detail screen should show either 動作步驟 or 動作說明.")

        let detailScreenshot = XCTAttachment(screenshot: app.screenshot())
        detailScreenshot.name = "exercise-library-detail"
        detailScreenshot.lifetime = .keepAlways
        add(detailScreenshot)
    }

    func testExerciseLibraryYogaFilterSwitchesControls() throws {
        let app = try launchConfiguredApp()
        openExerciseSection(app, entryIdentifier: "exerciseEntry.library")

        XCTAssertTrue(
            app.buttons["exerciseLibrary.itemCard"].firstMatch.waitForExistence(timeout: 30),
            "Exercise library should load before switching filters."
        )

        let yogaChip = app.buttons["exerciseLibrary.chip_瑜伽"]
        XCTAssertTrue(yogaChip.waitForExistence(timeout: 10), "瑜伽 type filter chip should exist.")
        yogaChip.tap()

        // Yoga rows are graded by difficulty rather than body part, so the
        // filter row swaps to difficulty chips - a structural signal that the
        // filter actually applied, without asserting on specific pose names.
        let beginnerChip = app.buttons["exerciseLibrary.chip_初級"]
        XCTAssertTrue(beginnerChip.waitForExistence(timeout: 15), "Switching to 瑜伽 should reveal difficulty chips.")

        XCTAssertTrue(
            app.buttons["exerciseLibrary.itemCard"].firstMatch.waitForExistence(timeout: 30),
            "Yoga filter should still return items."
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "exercise-library-yoga-filter"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// AI matching needs both a signed-in session and a user-configured AI
    /// provider key, neither of which CI can supply. What must hold
    /// regardless is that the screen degrades gracefully: it shows an
    /// actionable message instead of hanging or crashing.
    func testExerciseMatchShowsActionableMessageWithoutAIProvider() throws {
        let app = try launchConfiguredApp()
        openExerciseSection(app, entryIdentifier: "exerciseEntry.match")

        // Populate the need via the quick-select chip rather than typing:
        // the software keyboard would otherwise cover the submit button and
        // make this test flaky in CI.
        let quickNeed = app.buttons["exerciseMatch.quickNeed_瘦大腿"]
        XCTAssertTrue(quickNeed.waitForExistence(timeout: 10), "Quick-need chips should appear on the AI match screen.")
        scrollUntilHittable(quickNeed, in: app)
        quickNeed.tap()

        let startButton = app.buttons["exerciseMatch.startButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        scrollUntilHittable(startButton, in: app)
        startButton.tap()

        let message = app.staticTexts["exerciseMatch.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 40), "AI match should surface a message rather than hanging.")

        // Which message appears depends on whether a previous test in the same
        // simulator run left a persisted session: signed out yields the
        // sign-in prompt, signed in yields the "no AI provider" guidance.
        // Both are correct graceful-degradation paths.
        let text = message.label
        let isActionable = text.contains("登入") || text.contains("AI")
        XCTAssertTrue(isActionable, "Message should guide the user to sign in or configure AI. Got: \(text)")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "exercise-match-guidance"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
