import XCTest

final class InviteFirstFirebaseFlowTests: XCTestCase {
    func testEmailRegistrationReachesInviteScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-useFirebaseEmulator", "-previewPhase", "authentication"]
        app.launch()

        app.buttons["メールで登録"].tap()

        let email = app.textFields["メールアドレス"]
        XCTAssertTrue(email.waitForExistence(timeout: 3))
        email.tap()
        email.typeText("ui-\(UUID().uuidString.lowercased())@example.com")

        let password = app.secureTextFields["パスワード（8文字以上）"]
        password.tap()
        password.typeText("password123")

        let confirmation = app.secureTextFields["パスワード確認"]
        confirmation.tap()
        confirmation.typeText("password123")

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
    }
}
