import XCTest

/// 端到端驗收「美妝知識問答」：用真的 CI 測試帳號登入，在模擬器裡實際打字送出，
/// 打到線上的 Supabase Edge Function `notion-qa`（真的查 Notion、真的呼叫 LLM），
/// 並確認回來的圖片是 Supabase Storage 鏡像後的網址、在畫面上真的載入成功。
///
/// 這支測試需要 Supabase 設定與 CI 測試帳號；沒有時自行 skip（本機沒設 secrets 也能跑整包）。
final class NotionQAUITests: XCTestCase {
    /// 一次問答要跑 Notion 查詢 + LLM 生成 + 圖片鏡像，實測 5 秒上下；
    /// CI runner 較慢又可能遇到 Edge Function 冷啟動，所以放寬到 90 秒。
    private let answerTimeout: TimeInterval = 90

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 跟 CloudSyncUITests 同樣的限制：app-under-test 不會繼承 scheme 的環境變數，
    /// 要明確轉發，否則 AppRuntimeConfiguration 讀不到 Supabase 設定、登入永遠失敗。
    private func launchConfiguredApp() throws -> (XCUIApplication, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard
            let url = env["SUPABASE_URL"], !url.isEmpty,
            let anonKey = env["SUPABASE_ANON_KEY"], !anonKey.isEmpty,
            let email = env["CI_TEST_USER_EMAIL"], !email.isEmpty,
            let password = env["CI_TEST_USER_PASSWORD"], !password.isEmpty
        else {
            throw XCTSkip("Supabase config / CI test credentials not provided; skipping Notion QA tests.")
        }

        let app = XCUIApplication()
        app.launchEnvironment = ["SUPABASE_URL": url, "SUPABASE_ANON_KEY": anonKey]
        app.launch()
        return (app, email, password)
    }

    /// 先清空欄位再輸入。
    ///
    /// 整個 xctest bundle 共用同一份模擬器 App 資料，前面的測試登入過之後
    /// `authEmail` 會被 `store.authSession?.email` 預先填好；直接 typeText
    /// 會變成把 email 接在既有內容後面，登入必定失敗（CI 上就是這樣掛的）。
    private func replaceText(_ field: XCUIElement, with text: String) {
        field.tap()
        // 欄位為空時 value 會是 placeholder 文字，多送幾個 delete 也無害
        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    /// notion-qa 會驗 JWT，沒登入一律回 401，所以問答前一定要先登入。
    private func signIn(_ app: XCUIApplication, email: String, password: String) {
        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15))
        profileTab.tap()

        let settingsLink = app.buttons["profileLink_個人設定"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 15))
        settingsLink.tap()

        let statusValue = app.otherElements["supabaseSync.statusValue"]
        XCTAssertTrue(statusValue.waitForExistence(timeout: 15), "個人設定頁應該看得到雲端同步卡片。")

        // 前一支測試可能已經留下有效的 session，這時不用再登入一次
        if (statusValue.value as? String) == "已登入" { return }

        let emailField = app.textFields["supabaseSync.emailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 15))
        replaceText(emailField, with: email)
        XCTAssertEqual((emailField.value as? String) ?? "", email, "Email 欄位沒有被正確填入。")

        let passwordField = app.secureTextFields["supabaseSync.passwordField"]
        XCTAssertTrue(passwordField.exists)
        replaceText(passwordField, with: password)

        app.buttons["supabaseSync.signInButton"].tap()

        let authenticated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "已登入"),
            object: statusValue
        )
        let result = XCTWaiter().wait(for: [authenticated], timeout: 45)
        if result != .completed {
            attachScreenshot(app, name: "notion-qa-sign-in-failed")
        }
        let authMessage = app.staticTexts["supabaseSync.authMessage"]
        XCTAssertEqual(
            result,
            .completed,
            "登入應該進到「已登入」。目前狀態：\(statusValue.value ?? "nil")；"
                + "畫面訊息：\(authMessage.exists ? authMessage.label : "（無）")"
        )
    }

    private func openNotionQA(_ app: XCUIApplication) {
        // 重啟後 App 可能直接還原在這一頁，這時沒有入口卡片可以點
        if app.textFields["notionQA.inputField"].exists { return }

        let beautyTab = app.tabBars.buttons["變美"]
        XCTAssertTrue(beautyTab.waitForExistence(timeout: 15))
        beautyTab.tap()

        let entry = app.buttons["beautyLink_美妝知識問答"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "變美頁應該有「美妝知識問答」入口。")
        var swipes = 0
        while !entry.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        entry.tap()
    }

    /// 同一份模擬器 App 資料會跨測試留存，先清掉舊對話，
    /// 後面才能用 firstMatch 穩定指到「這次」問的那一則。
    private func clearConversation(_ app: XCUIApplication) {
        let clearButton = app.buttons["清空"]
        if clearButton.waitForExistence(timeout: 3) {
            clearButton.tap()
        }
    }

    private func ask(_ app: XCUIApplication, question: String) {
        let input = app.textFields["notionQA.inputField"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "問答頁應該有輸入框。")
        input.tap()
        input.typeText(question)

        // 中文經 typeText 進模擬器偶爾會整段掉字，先確認真的打進去了，
        // 否則後面會變成「答案不對」這種很難查的失敗。
        XCTAssertEqual(
            (input.value as? String) ?? "",
            question,
            "中文問題沒有正確輸入到輸入框。"
        )

        app.buttons["notionQA.sendButton"].tap()
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 主驗收：問一題 → 拿到真實答案 → 圖片（Storage 鏡像）在畫面上載入成功。
    func testAskQuestionReturnsAnswerAndLoadsMirroredImages() throws {
        let (app, email, password) = try launchConfiguredApp()
        signIn(app, email: email, password: password)
        openNotionQA(app)
        clearConversation(app)
        ask(app, question: "有瘦腿的方法嗎")

        let answer = app.staticTexts["notionQA.assistantText"].firstMatch
        XCTAssertTrue(
            answer.waitForExistence(timeout: answerTimeout),
            "送出後應該要收到助理回覆。畫面錯誤訊息：\(app.staticTexts.element(boundBy: 0).label)"
        )

        let text = answer.label
        XCTAssertGreaterThan(text.count, 20, "回覆太短，不像是真的查到內容：\(text)")
        XCTAssertFalse(text.contains("抱歉，這次查詢沒有成功"), "收到 fallback 文案，代表後端沒真的跑起來。")
        XCTAssertFalse(text.contains("請先登入"), "收到 401 文案，代表 JWT 沒帶上去。")

        attachScreenshot(app, name: "notion-qa-answer")

        // 圖片鏡像的實際驗收：.loaded 只有在 AsyncImage 真的把 Supabase Storage
        // 簽章網址下載回來時才會出現，佔位色塊是另一個 identifier。
        let loadedImage = app.descendants(matching: .any)
            .matching(identifier: "notionQA.image.loaded").firstMatch
        XCTAssertTrue(
            loadedImage.waitForExistence(timeout: 45),
            "答案裡的筆記圖片應該要成功載入（Supabase Storage 鏡像網址）。"
        )

        attachScreenshot(app, name: "notion-qa-images-loaded")
    }

    /// 對話持久化：問完關掉 App 再開，先前的訊息要還在（存在本機 state，不是只留在記憶體）。
    func testConversationSurvivesRelaunch() throws {
        let (app, email, password) = try launchConfiguredApp()
        signIn(app, email: email, password: password)
        openNotionQA(app)
        clearConversation(app)

        let question = "痘痘怎麼處理"
        ask(app, question: question)

        let answer = app.staticTexts["notionQA.assistantText"].firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: answerTimeout), "重啟前應該先拿到一則回覆。")
        let answerBeforeRelaunch = answer.label

        app.terminate()
        app.launch()

        openNotionQA(app)

        let restoredQuestion = app.staticTexts["notionQA.userText"].firstMatch
        XCTAssertTrue(restoredQuestion.waitForExistence(timeout: 20), "重啟後應該還看得到先前問的問題。")
        XCTAssertEqual(restoredQuestion.label, question)

        let restoredAnswer = app.staticTexts["notionQA.assistantText"].firstMatch
        XCTAssertTrue(restoredAnswer.waitForExistence(timeout: 20), "重啟後應該還看得到先前的回覆。")
        XCTAssertEqual(restoredAnswer.label, answerBeforeRelaunch)

        attachScreenshot(app, name: "notion-qa-restored-after-relaunch")
    }
}
