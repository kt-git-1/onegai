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
        XCTAssertTrue(app.staticTexts["おねがいを作る"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["request-title-field"].exists)
        XCTAssertTrue(app.buttons["save-request-button"].exists)
    }

    func testCharinConfirmationShowsCelebrationWithoutUndoToast() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "requests", "-holdCharinCelebration"]
        app.launch()

        let charin = app.buttons["ちゃりん"].firstMatch
        XCTAssertTrue(charin.waitForExistence(timeout: 3))
        charin.tap()
        XCTAssertTrue(app.staticTexts["このおねがいをちゃりんしますか？"].waitForExistence(timeout: 2))
        app.buttons["confirm-charin-button"].tap()

        XCTAssertTrue(app.staticTexts["ちゃりん！"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["cancel-charin-button"].exists)
    }

    func testHomeRequestCanCharin() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-holdCharinCelebration"]
        app.launch()

        let charin = app.buttons["home-charin-request-massage"]
        XCTAssertTrue(charin.waitForExistence(timeout: 3))
        charin.tap()
        XCTAssertTrue(app.buttons["confirm-charin-button"].waitForExistence(timeout: 2))
        app.buttons["confirm-charin-button"].tap()
        XCTAssertTrue(app.staticTexts["ちゃりん！"].waitForExistence(timeout: 3))
    }

    func testHomeRequestRowTapCanCharin() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-holdCharinCelebration"]
        app.launch()

        let row = app.buttons["home-charin-request-massage"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(app.buttons["confirm-charin-button"].waitForExistence(timeout: 2))
    }

    func testRecordsCanReactToPartnersCharin() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "records"]
        app.launch()

        let reactionButton = app.buttons["スタンプを選ぶ"]
        XCTAssertTrue(reactionButton.waitForExistence(timeout: 3))
        reactionButton.tap()
        let stamp = app.buttons["ありがとう"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 2))
        stamp.tap()
        XCTAssertTrue(app.buttons["スタンプを変更"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["ありがとうを送りました"].waitForExistence(timeout: 2))
    }

    func testSettingsCanOpenFromHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main"]
        app.launch()

        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 3))
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["名前とアイコンを編集"].exists)
        XCTAssertTrue(app.staticTexts["カップル名"].exists)
        XCTAssertTrue(app.staticTexts["相手"].exists)
        XCTAssertTrue(app.staticTexts["招待コード"].exists)
        XCTAssertTrue(app.staticTexts["通知設定"].exists)
        XCTAssertTrue(app.staticTexts["音とテーマ"].exists)
    }

    func testCharinReturnsHomeWithRemainingUndoTime() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "requests"]
        app.launch()

        XCTAssertTrue(app.buttons["ちゃりん"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["ちゃりん"].firstMatch.tap()
        XCTAssertTrue(app.buttons["confirm-charin-button"].waitForExistence(timeout: 2))
        app.buttons["confirm-charin-button"].tap()

        XCTAssertTrue(app.staticTexts["花男の貯金箱"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["ふたりのおねがい"].exists)
    }

    func testRewardListFiltersByStatusAndBank() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "rewards"]
        app.launch()

        XCTAssertTrue(app.staticTexts["コンビニスイーツ券"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["焼肉デートごほうび券"].exists)

        app.buttons["reward-status-交換できる"].tap()
        XCTAssertTrue(app.staticTexts["コンビニスイーツ券"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["スタバごほうび券"].exists)

        app.buttons["reward-status-すべて"].tap()
        app.buttons["reward-bank-filter-ふたり"].tap()
        XCTAssertTrue(app.staticTexts["焼肉デートごほうび券"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["コンビニスイーツ券"].exists)
    }

    func testRewardCreatorCanOpenEditorAndCreateReward() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "rewards"]
        app.launch()

        app.buttons["reward-status-すべて"].tap()
        XCTAssertTrue(app.staticTexts["スタバごほうび券"].waitForExistence(timeout: 3))
        app.staticTexts["スタバごほうび券"].tap()
        XCTAssertTrue(app.buttons["edit-reward-reward-coffee"].waitForExistence(timeout: 2))
        app.buttons["edit-reward-reward-coffee"].tap()
        XCTAssertTrue(app.staticTexts["ごほうび券を編集"].waitForExistence(timeout: 2))
        app.buttons["キャンセル"].tap()

        app.buttons["add-reward-button"].tap()
        XCTAssertTrue(app.staticTexts["ごほうび券を作る"].waitForExistence(timeout: 2))
        let title = app.textFields["reward-title-field"]
        title.tap()
        title.typeText("映画ごほうび券")
        app.keyboards.buttons["Return"].tap()
        app.buttons["save-reward-button"].tap()
        XCTAssertTrue(app.staticTexts["映画ごほうび券"].waitForExistence(timeout: 3))
    }

    func testExchangeRewardIssuesTicketAndShowsOwnedList() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewPhase", "main", "-previewTab", "rewards"]
        app.launch()

        XCTAssertTrue(app.buttons["reward-status-交換できる"].waitForExistence(timeout: 3))
        app.buttons["reward-status-交換できる"].tap()
        XCTAssertTrue(app.buttons["exchange-reward-reward-sweets"].waitForExistence(timeout: 2))
        app.buttons["exchange-reward-reward-sweets"].tap()
        XCTAssertTrue(app.staticTexts["コンビニスイーツ券を\n交換しますか？"].waitForExistence(timeout: 2))
        app.buttons["confirm-exchange-reward-button"].tap()
        let viewTickets = app.buttons["持っている券を見る"]
        XCTAssertTrue(viewTickets.waitForExistence(timeout: 3))
        viewTickets.tap()
        XCTAssertTrue(app.buttons["ticket-filter-unused"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["ticket-filter-unused"].isSelected)
        XCTAssertTrue(app.staticTexts["コンビニスイーツ券"].waitForExistence(timeout: 3))
        app.buttons["reward-section-rewards"].tap()
        app.buttons["reward-status-あと少し"].tap()
        XCTAssertTrue(app.staticTexts["スタバごほうび券"].waitForExistence(timeout: 3))
        app.buttons["reward-section-tickets"].tap()
        app.buttons["券を表示"].firstMatch.tap()
        XCTAssertTrue(app.buttons["use-ticket-button"].waitForExistence(timeout: 2))
        app.buttons["use-ticket-button"].tap()
        let confirmUse = app.sheets.buttons["使用済みにする"]
        XCTAssertTrue(confirmUse.waitForExistence(timeout: 2))
        confirmUse.tap()
        XCTAssertTrue(app.buttons["ticket-filter-unused"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["use-ticket-button"].exists)
        app.buttons["ticket-filter-used"].tap()
        XCTAssertTrue(app.staticTexts["コンビニスイーツ券"].waitForExistence(timeout: 3))
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
