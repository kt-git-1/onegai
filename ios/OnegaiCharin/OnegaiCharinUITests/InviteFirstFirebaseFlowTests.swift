import XCTest

final class InviteFirstFirebaseFlowTests: XCTestCase {
    func testRequestListExpandsCreatorCardAndOpensEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "requests"]
        app.launch()

        XCTAssertTrue(app.staticTexts["マッサージ10分"].waitForExistence(timeout: 3))
        app.staticTexts["マッサージ10分"].tap()
        XCTAssertTrue(app.buttons["編集"].waitForExistence(timeout: 2))

        app.buttons["add-request-button"].tap()
        XCTAssertTrue(app.navigationBars["お願いを作る"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["request-title-field"].exists)
        XCTAssertTrue(app.buttons["save-request-button"].exists)
    }

    func testCharinConfirmationCelebrationAndUndoToast() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "requests", "-holdCharinCelebration"]
        app.launch()

        let charin = app.buttons["ちゃりん"].firstMatch
        XCTAssertTrue(charin.waitForExistence(timeout: 3))
        charin.tap()
        XCTAssertTrue(app.staticTexts["このお願いをちゃりんしますか？"].waitForExistence(timeout: 2))
        app.buttons["confirm-charin-button"].tap()

        XCTAssertTrue(app.staticTexts["ちゃりん！"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["cancel-charin-button"].waitForExistence(timeout: 4))
        app.buttons["cancel-charin-button"].tap()
        XCTAssertFalse(app.buttons["cancel-charin-button"].waitForExistence(timeout: 2))
    }

    func testCharinReturnsHomeWithRemainingUndoTime() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "requests"]
        app.launch()

        XCTAssertTrue(app.buttons["ちゃりん"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["ちゃりん"].firstMatch.tap()
        XCTAssertTrue(app.buttons["confirm-charin-button"].waitForExistence(timeout: 2))
        app.buttons["confirm-charin-button"].tap()

        XCTAssertTrue(app.staticTexts["おねがいチャリン"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cancel-charin-button"].exists)
    }

    func testHomeSwipesBetweenPersonalAndSharedBanks() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main"]
        app.launch()

        let personalBank = app.staticTexts["花男の貯金箱"]
        XCTAssertTrue(personalBank.waitForExistence(timeout: 3))
        personalBank.swipeLeft()

        XCTAssertTrue(app.staticTexts["ふたりの貯金箱"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["ふたりのお願い"].exists)
    }

    func testEmailRegistrationReachesInviteScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-useFirebaseEmulator", "-previewPhase", "authentication"]
        app.launch()

        app.buttons["メールで登録"].tap()

        let testEmail = "ui-\(UUID().uuidString.lowercased())@example.com"
        let testPassword = "password123"
        let email = app.textFields["メールアドレス"]
        XCTAssertTrue(email.waitForExistence(timeout: 3))
        email.tap()
        email.typeText(testEmail)

        let password = app.secureTextFields["パスワード（8文字以上）"]
        password.tap()
        password.typeText(testPassword)

        let confirmation = app.secureTextFields["パスワード確認"]
        confirmation.tap()
        confirmation.typeText(testPassword)

        app.buttons["登録する"].tap()

        let name = app.textFields["例：花男"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("テストユーザー")
        app.keyboards.buttons["Return"].tap()
        app.buttons["保存して次へ"].tap()

        let applyTemplate = app.buttons["この内容ではじめる"]
        let reachedTemplate = applyTemplate.waitForExistence(timeout: 8)
        XCTAssertTrue(reachedTemplate, app.staticTexts["profile-save-error"].label)
        guard reachedTemplate else { return }
        applyTemplate.tap()

        let reachedInvite = app.staticTexts["相手を招待しよう"].waitForExistence(timeout: 8)
        let templateError = app.staticTexts["template-create-error"]
        XCTAssertTrue(reachedInvite, templateError.exists ? templateError.label : "招待画面へ遷移しませんでした。")
        guard reachedInvite else { return }
        XCTAssertTrue(app.staticTexts["招待コード"].exists)

        app.terminate()
        app.launchArguments = ["-useFirebaseEmulator", "-previewPhase", "emailLogin"]
        app.launch()

        let loginEmail = app.textFields["メールアドレス"]
        XCTAssertTrue(loginEmail.waitForExistence(timeout: 3))
        loginEmail.tap()
        loginEmail.typeText(testEmail)
        let loginPassword = app.secureTextFields["パスワード"]
        loginPassword.tap()
        loginPassword.typeText(testPassword)
        app.keyboards.buttons["Return"].tap()
        app.buttons["ログイン"].tap()

        XCTAssertTrue(app.staticTexts["相手の参加を待っています"].waitForExistence(timeout: 8))
    }
}
