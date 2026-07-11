import XCTest
@testable import OnegaiCharin

@MainActor
final class LocalAppRepositoryTests: XCTestCase {
    func testInviteFirstSetupCreatesRequiredData() async throws {
        let repository = LocalAppRepository()

        let user = try await repository.register(email: "test@example.com", password: "password")
        let profile = try await repository.saveProfile(displayName: "花男", iconEmoji: nil)
        let result = try await repository.createInitialTemplate()

        XCTAssertEqual(user.id, profile.id)
        XCTAssertNil(profile.iconEmoji)
        XCTAssertEqual(result.group.memberIds, [user.id])
        XCTAssertEqual(result.piggyBanks.map(\.ownerType), [.personal, .shared])
        XCTAssertEqual(result.requests.filter { $0.piggyBankType == .personal }.count, 3)
        XCTAssertEqual(result.requests.filter { $0.piggyBankType == .shared }.count, 3)
        XCTAssertTrue(result.requests.contains { $0.title == "買い出し" && $0.coinAmount == 100 })
        XCTAssertTrue(result.requests.contains { $0.title == "一緒に散歩する" && $0.coinAmount == 200 })
        XCTAssertFalse(result.rewards.isEmpty)
        XCTAssertEqual(result.invite.status, .active)
    }

    func testReactionCanBeAddedAndChangedForPartnersCharin() async throws {
        let repository = LocalAppRepository()
        let user = try await repository.register(email: "owner@example.com", password: "password")
        _ = try await repository.saveProfile(displayName: "花男", iconEmoji: nil)
        let template = try await repository.createInitialTemplate()
        let now = Date()
        let record = ActivityRecord(
            id: "partner-record", groupId: template.group.id, userId: "partner-preview",
            type: .charin, targetType: "request", targetId: "request-massage",
            title: "マッサージ10分", iconEmoji: "💆", coinDelta: 100,
            piggyBankId: template.piggyBanks[0].id, piggyBankName: template.piggyBanks[0].name,
            balanceBefore: 0, balanceAfter: 100, status: .active, createdAt: now, canceledAt: nil
        )

        let first = try await repository.upsertReaction(record: record, stampType: .arigatou)
        let changed = try await repository.upsertReaction(record: record, stampType: .suki)

        XCTAssertEqual(first.id, "partner-record_\(user.id)")
        XCTAssertEqual(changed.stampType, .suki)
        XCTAssertEqual(repository.reactions.count, 1)
    }

    func testProfileIsRequiredBeforeTemplateCreation() async throws {
        let repository = LocalAppRepository()
        _ = try await repository.signIn(with: .apple)

        do {
            _ = try await repository.createInitialTemplate()
            XCTFail("Expected profileMissing")
        } catch {
            XCTAssertEqual(error as? AppRepositoryError, .profileMissing)
        }
    }

    func testReissueReplacesInviteCode() async throws {
        let repository = LocalAppRepository()
        _ = try await repository.signIn(with: .google)
        _ = try await repository.saveProfile(displayName: "花子", iconEmoji: "🌷")
        let initial = try await repository.createInitialTemplate().invite

        let replacement = try await repository.reissueInvite()

        XCTAssertNotEqual(initial.id, replacement.id)
        XCTAssertNotEqual(initial.code, replacement.code)
        XCTAssertEqual(replacement.status, .active)
        XCTAssertTrue(repository.revokedInviteIds.contains(initial.id))
    }

    func testAppStateAdvancesFromRegistrationToInvite() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)

        await state.register(email: "test@example.com", password: "password")
        XCTAssertEqual(state.phase, .profile)

        state.displayName = "花男"
        await state.saveProfile()
        XCTAssertEqual(state.phase, .template)

        await state.applyInitialTemplate()
        XCTAssertEqual(state.phase, .invite)
        XCTAssertEqual(state.inviteCode, "ABCD-1234")
        XCTAssertEqual(
            state.inviteURL?.absoluteString,
            "https://onegai-charin-dev.web.app/invite/invite-1"
        )
    }

    func testCoupleNameCanBeUpdatedFromSettings() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)

        await state.register(email: "test@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()

        let saved = await state.updateCoupleName("花男と花子")

        XCTAssertTrue(saved)
        XCTAssertEqual(state.initialTemplate?.group.name, "花男と花子")
        XCTAssertEqual(state.toast?.message, "カップル名を保存しました")
    }

    func testAnalyticsEventsAreLoggedForCoreActions() async throws {
        let repository = LocalAppRepository()
        var loggedEvents: [(name: String, parameters: [String: Any])] = []
        let analytics = AnalyticsService(isEnabled: true) { name, parameters in
            loggedEvents.append((name, parameters))
        }
        let state = AppState(repository: repository, analytics: analytics)

        await state.register(email: "analytics@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()
	        state.trackInviteSent(channel: "copy")

	        let request = try XCTUnwrap(state.initialTemplate?.requests.first { $0.id == "request-massage" })
	        let charinSucceeded = await state.charin(request)
	        XCTAssertTrue(charinSucceeded)
	        let cancelSucceeded = await state.cancelLatestCharin()
	        XCTAssertTrue(cancelSucceeded)
	        let secondCharinSucceeded = await state.charin(request)
	        XCTAssertTrue(secondCharinSucceeded)

	        let bank = try XCTUnwrap(state.initialTemplate?.piggyBanks.first { $0.id == "bank-personal" })
	        let rewardDraft = RewardDraft(
	            title: "テストごほうび券",
	            iconEmoji: "🎁",
	            requiredCoins: 100,
	            piggyBankType: .personal,
	            expiresInType: .none,
	            expiresInDays: nil,
	            expiresAt: nil
	        )
	        let rewardCreateSucceeded = await state.createReward(rewardDraft)
	        XCTAssertTrue(rewardCreateSucceeded)
	        let reward = try XCTUnwrap(state.initialTemplate?.rewards.first { $0.title == "テストごほうび券" })
	        let exchangeSucceeded = await state.exchangeReward(reward, from: bank)
	        XCTAssertTrue(exchangeSucceeded)
	        let ticket = try XCTUnwrap(state.issuedTicket)
	        let useTicketSucceeded = await state.useTicket(ticket)
	        XCTAssertTrue(useTicketSucceeded)

        let partnerRecord = ActivityRecord(
            id: "partner-record",
            groupId: reward.groupId,
            userId: "partner-preview",
            type: .charin,
            targetType: "request",
            targetId: "request-massage",
            title: "マッサージ10分",
            iconEmoji: "💆",
            coinDelta: 100,
            piggyBankId: bank.id,
            piggyBankName: bank.name,
            balanceBefore: 0,
            balanceAfter: 100,
            status: .active,
	            createdAt: Date(),
	            canceledAt: nil
	        )
	        let reactionSucceeded = await state.setReaction(.arigatou, for: partnerRecord)
	        XCTAssertTrue(reactionSucceeded)

        let eventNames = loggedEvents.map(\.name)
        XCTAssertEqual(eventNames, [
            "sign_up_completed",
            "template_applied",
            "invite_sent",
	            "charin_completed",
	            "charin_canceled",
	            "charin_completed",
	            "reward_exchanged",
            "ticket_used",
            "reaction_added",
        ])
        XCTAssertEqual(loggedEvents.first { $0.name == "invite_sent" }?.parameters["channel"] as? String, "copy")
        XCTAssertEqual(loggedEvents.first { $0.name == "charin_completed" }?.parameters["coin_amount"] as? Int, 100)
        XCTAssertEqual(loggedEvents.first { $0.name == "reaction_added" }?.parameters["stamp_type"] as? String, "arigatou")
    }

    func testAnalyticsCanBeDisabledForPreviewAndTests() {
        var loggedEvents: [String] = []
        let analytics = AnalyticsService(isEnabled: false) { name, _ in
            loggedEvents.append(name)
        }

        analytics.log(.charinCompleted, parameters: ["coin_amount": 100])

        XCTAssertTrue(loggedEvents.isEmpty)
    }

    func testEmailLoginAndPasswordReset() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)

        await state.signIn(email: "existing@example.com", password: "password")
        XCTAssertEqual(state.phase, .profile)
        XCTAssertEqual(state.authenticatedUser?.email, "existing@example.com")

        await state.sendPasswordReset(email: "existing@example.com")
        XCTAssertTrue(state.passwordResetEmailSent)
        XCTAssertNil(state.errorMessage)
    }

    func testExistingUserRestoresToInviteWaiting() async throws {
        let repository = LocalAppRepository()
        _ = try await repository.register(email: "existing@example.com", password: "password")
        _ = try await repository.saveProfile(displayName: "花男", iconEmoji: nil)
        _ = try await repository.createInitialTemplate()
        try await repository.signOut()

        let state = AppState(repository: repository)
        await state.signIn(email: "existing@example.com", password: "password")

        XCTAssertEqual(state.phase, .inviteWaiting)
        XCTAssertEqual(state.profile?.displayName, "花男")
        XCTAssertEqual(state.inviteCode, "ABCD-1234")
    }

    func testJoinedUserRestoresToHome() async throws {
        let repository = LocalAppRepository()
        _ = try await repository.register(email: "joined@example.com", password: "password")
        _ = try await repository.saveProfile(displayName: "花子", iconEmoji: "🌷")
        _ = try await repository.createInitialTemplate()
        try await repository.completeInviteForPreview()
        try await repository.signOut()

        let state = AppState(repository: repository)
        await state.signIn(email: "joined@example.com", password: "password")

        XCTAssertEqual(state.phase, .main)
        XCTAssertEqual(state.partnerProfile?.displayName, "花子")
        XCTAssertEqual(state.initialTemplate?.piggyBanks.count, 2)
    }

    func testInviteeKeepsInviteThroughRegistrationAndJoinsAfterProfile() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)

        await state.resolveInvite(code: "abcd 1234")
        XCTAssertEqual(state.phase, .inviteAcceptance)
        XCTAssertEqual(state.pendingInvite?.inviterName, "花男")

        await state.beginInviteAcceptance()
        XCTAssertEqual(state.phase, .authentication)

        await state.register(email: "invitee@example.com", password: "password")
        XCTAssertEqual(state.phase, .profile)
        XCTAssertNotNil(state.pendingInvite)

        state.displayName = "花子"
        await state.saveProfile()

        XCTAssertEqual(state.phase, .main)
        XCTAssertNil(state.pendingInvite)
        XCTAssertEqual(state.profile?.activeGroupId, "group-invite-preview")
        XCTAssertEqual(state.initialTemplate?.group.memberIds, ["inviter-preview", "user-preview"])
    }

    func testInvalidInviteCodeStaysOnCodeEntry() async throws {
        let state = AppState(repository: LocalAppRepository())
        state.phase = .inviteCodeEntry

        await state.resolveInvite(code: "NOPE-0000")

        XCTAssertEqual(state.phase, .inviteCodeEntry)
        XCTAssertEqual(state.errorMessage, AppRepositoryError.invalidInviteCode.errorDescription)
    }

    func testInviteWaitingObservationMovesInviterToHome() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)
        await state.register(email: "owner@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()
        state.phase = .inviteWaiting
        state.startObservingInviteCompletion()

        await state.completeInviteForPreview()
        for _ in 0..<20 where state.phase != .main {
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertEqual(state.phase, .main)
        XCTAssertEqual(state.initialTemplate?.group.memberIds.count, 2)
    }

    func testRequestCreateUpdateAndHideRefreshAppState() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)
        await state.register(email: "owner@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()

        let created = RequestDraft(
            title: "  コーヒーをいれる  ",
            iconEmoji: "☕️",
            coinAmount: 150,
            piggyBankType: .shared,
            repeatType: .oneTime
        )
        let didCreate = await state.createRequest(created)
        XCTAssertTrue(didCreate)
        let request = try XCTUnwrap(state.initialTemplate?.requests.first { $0.title == "コーヒーをいれる" })
        XCTAssertEqual(request.createdBy, state.authenticatedUser?.id)
        XCTAssertEqual(request.coinAmount, 150)
        XCTAssertEqual(request.piggyBankType, .shared)
        XCTAssertEqual(request.repeatType, .oneTime)

        let updated = RequestDraft(
            title: "紅茶をいれる",
            iconEmoji: "✨",
            coinAmount: 200,
            piggyBankType: .personal,
            repeatType: .repeatable
        )
        let didUpdate = await state.updateRequest(request, draft: updated)
        XCTAssertTrue(didUpdate)
        let edited = try XCTUnwrap(state.initialTemplate?.requests.first { $0.id == request.id })
        XCTAssertEqual(edited.title, "紅茶をいれる")
        XCTAssertEqual(edited.coinAmount, 200)

        let didHide = await state.hideRequest(edited)
        XCTAssertTrue(didHide)
        XCTAssertEqual(state.initialTemplate?.requests.first { $0.id == request.id }?.status, .hidden)
    }

    func testRequestCanOnlyBeChangedByCreator() async throws {
        let repository = LocalAppRepository()
        _ = try await repository.register(email: "owner@example.com", password: "password")
        _ = try await repository.saveProfile(displayName: "花男", iconEmoji: nil)
        let template = try await repository.createInitialTemplate()
        var foreignRequest = try XCTUnwrap(template.requests.first)
        foreignRequest = RequestItem(
            id: foreignRequest.id,
            groupId: foreignRequest.groupId,
            createdBy: "partner-preview",
            title: foreignRequest.title,
            iconEmoji: foreignRequest.iconEmoji,
            coinAmount: foreignRequest.coinAmount,
            piggyBankType: foreignRequest.piggyBankType,
            repeatType: foreignRequest.repeatType,
            status: foreignRequest.status,
            completionCount: foreignRequest.completionCount,
            lastCompletedAt: foreignRequest.lastCompletedAt,
            createdAt: foreignRequest.createdAt,
            updatedAt: foreignRequest.updatedAt
        )

        do {
            _ = try await repository.hideRequest(foreignRequest)
            XCTFail("Expected requestNotOwned")
        } catch {
            XCTAssertEqual(error as? AppRepositoryError, .requestNotOwned)
        }
    }

    func testRewardCreateUpdateAndHideRefreshAppState() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)
        await state.register(email: "reward-owner@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()

        let draft = RewardDraft(
            title: "  映画ごほうび券  ",
            iconEmoji: "🎬",
            requiredCoins: 1_200,
            piggyBankType: .shared,
            expiresInType: .days,
            expiresInDays: 30,
            expiresAt: nil
        )
        let didCreate = await state.createReward(draft)
        XCTAssertTrue(didCreate)
        let reward = try XCTUnwrap(state.initialTemplate?.rewards.first { $0.title == "映画ごほうび券" })
        XCTAssertEqual(reward.createdBy, state.authenticatedUser?.id)
        XCTAssertEqual(reward.requiredCoins, 1_200)
        XCTAssertEqual(reward.piggyBankType, .shared)
        XCTAssertEqual(reward.expiresInDays, 30)
        XCTAssertFalse(reward.isTarget)

        let expiryDate = Calendar.current.date(byAdding: .day, value: 45, to: Date())!
        let updated = RewardDraft(
            title: "映画デート券",
            iconEmoji: "🍿",
            requiredCoins: 1_500,
            piggyBankType: .personal,
            expiresInType: .date,
            expiresInDays: nil,
            expiresAt: expiryDate
        )
        let didUpdate = await state.updateReward(reward, draft: updated)
        XCTAssertTrue(didUpdate)
        let edited = try XCTUnwrap(state.initialTemplate?.rewards.first { $0.id == reward.id })
        XCTAssertEqual(edited.title, "映画デート券")
        XCTAssertEqual(edited.requiredCoins, 1_500)
        XCTAssertEqual(edited.expiresInType, .date)
        XCTAssertEqual(try XCTUnwrap(edited.expiresAt).timeIntervalSince1970, expiryDate.timeIntervalSince1970, accuracy: 0.001)

        let didHide = await state.hideReward(edited)
        XCTAssertTrue(didHide)
        XCTAssertEqual(state.initialTemplate?.rewards.first { $0.id == reward.id }?.status, .hidden)
    }

    func testRewardCanOnlyBeChangedByCreator() async throws {
        let repository = LocalAppRepository()
        _ = try await repository.register(email: "reward-owner@example.com", password: "password")
        _ = try await repository.saveProfile(displayName: "花男", iconEmoji: nil)
        let template = try await repository.createInitialTemplate()
        let original = try XCTUnwrap(template.rewards.first)
        let foreignReward = Reward(
            id: original.id,
            groupId: original.groupId,
            createdBy: "partner-preview",
            title: original.title,
            iconEmoji: original.iconEmoji,
            requiredCoins: original.requiredCoins,
            piggyBankType: original.piggyBankType,
            isTarget: original.isTarget,
            expiresInType: original.expiresInType,
            expiresInDays: original.expiresInDays,
            expiresAt: original.expiresAt,
            status: original.status,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt
        )

        do {
            _ = try await repository.hideReward(foreignReward)
            XCTFail("Expected rewardNotOwned")
        } catch {
            XCTAssertEqual(error as? AppRepositoryError, .rewardNotOwned)
        }
    }

    func testRewardExchangeUpdatesBalanceAndIssuesTicket() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)
        await state.register(email: "exchange@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()

        let request = try XCTUnwrap(state.initialTemplate?.requests.first { $0.coinAmount == 100 })
        let didCharin = await state.charin(request)
        XCTAssertTrue(didCharin)
        state.finishCharinCelebration()
        let bank = try XCTUnwrap(state.piggyBank(for: request))
        let draft = RewardDraft(title: "テスト券", iconEmoji: "🎁", requiredCoins: 100,
                                piggyBankType: .personal, expiresInType: .days,
                                expiresInDays: 7, expiresAt: nil)
        let didCreate = await state.createReward(draft)
        XCTAssertTrue(didCreate)
        let reward = try XCTUnwrap(state.initialTemplate?.rewards.first { $0.title == "テスト券" })

        let didExchange = await state.exchangeReward(reward, from: bank)
        XCTAssertTrue(didExchange)
        XCTAssertEqual(state.initialTemplate?.piggyBanks.first { $0.id == bank.id }?.balance, 0)
        XCTAssertEqual(state.tickets.first?.title, "テスト券")
        XCTAssertEqual(state.tickets.first?.status, .unused)
        XCTAssertEqual(state.records.first?.type, .rewardExchange)
        XCTAssertEqual(state.records.first?.coinDelta, -100)
        XCTAssertNotNil(state.issuedTicket)
        let updatedBank = try XCTUnwrap(state.initialTemplate?.piggyBanks.first { $0.id == bank.id })
        XCTAssertEqual(state.nearestReward(for: updatedBank)?.title, "スタバごほうび券")
        let duplicateExchange = await state.exchangeReward(reward, from: updatedBank)
        XCTAssertFalse(duplicateExchange)

        let ticket = try XCTUnwrap(state.tickets.first)
        let didUse = await state.useTicket(ticket)
        XCTAssertTrue(didUse)
        XCTAssertEqual(state.tickets.first?.status, .used)
        XCTAssertEqual(state.tickets.first?.usedBy, state.authenticatedUser?.id)
        XCTAssertNotNil(state.tickets.first?.usedAt)
        XCTAssertEqual(state.records.first?.type, .ticketUsed)
    }

    func testCharinAndCancelUpdateBalanceRequestAndRecords() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)
        await state.register(email: "charin@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()

        let request = try XCTUnwrap(state.initialTemplate?.requests.first)
        let bankBefore = try XCTUnwrap(state.piggyBank(for: request))
        let didCharin = await state.charin(request)
        XCTAssertTrue(didCharin)
        XCTAssertEqual(state.phase, .charinCelebration)
        XCTAssertEqual(state.piggyBank(for: request)?.balance, bankBefore.balance + request.coinAmount)
        XCTAssertEqual(state.initialTemplate?.requests.first { $0.id == request.id }?.completionCount, 1)
        XCTAssertEqual(state.records.first?.status, .active)
        XCTAssertNotNil(state.pendingCharinUndo)
        if let pending = state.pendingCharinUndo, let record = state.records.first {
            XCTAssertEqual(pending.expiresAt.timeIntervalSince(record.createdAt), 10, accuracy: 0.01)
        }

        let didCancel = await state.cancelLatestCharin()
        XCTAssertTrue(didCancel)
        XCTAssertEqual(state.phase, .main)
        XCTAssertEqual(state.piggyBank(for: request)?.balance, bankBefore.balance)
        XCTAssertEqual(state.initialTemplate?.requests.first { $0.id == request.id }?.completionCount, 0)
        XCTAssertTrue(state.records.isEmpty)
        XCTAssertNil(state.pendingCharinUndo)
    }

    func testRecordObservationTracksCharinAndCancel() async throws {
        let repository = LocalAppRepository()
        _ = try await repository.register(email: "records@example.com", password: "password")
        _ = try await repository.saveProfile(displayName: "花男", iconEmoji: nil)
        let template = try await repository.createInitialTemplate()
        let request = try XCTUnwrap(template.requests.first)
        var snapshots: [[ActivityRecord]] = []

        let observation = repository.observeRecords(groupId: template.group.id) { result in
            if case .success(let records) = result {
                snapshots.append(records)
            }
        }
        defer { observation.cancel() }

        let charin = try await repository.charinRequest(groupId: template.group.id, requestId: request.id)
        _ = try await repository.cancelCharin(recordId: charin.record.id)

        XCTAssertEqual(snapshots.map(\.count), [0, 1, 0])
    }

    func testOneTimeRequestIsHiddenAndRestoredByCancel() async throws {
        let repository = LocalAppRepository()
        let state = AppState(repository: repository)
        await state.register(email: "onetime@example.com", password: "password")
        state.displayName = "花男"
        await state.saveProfile()
        await state.applyInitialTemplate()

        let original = try XCTUnwrap(state.initialTemplate?.requests.first)
        let draft = RequestDraft(
            title: original.title,
            iconEmoji: original.iconEmoji,
            coinAmount: original.coinAmount,
            piggyBankType: original.piggyBankType,
            repeatType: .oneTime
        )
        let didUpdate = await state.updateRequest(original, draft: draft)
        XCTAssertTrue(didUpdate)
        let oneTime = try XCTUnwrap(state.initialTemplate?.requests.first { $0.id == original.id })

        let didCharin = await state.charin(oneTime)
        XCTAssertTrue(didCharin)
        XCTAssertEqual(state.initialTemplate?.requests.first { $0.id == oneTime.id }?.status, .hidden)
        let didCancel = await state.cancelLatestCharin()
        XCTAssertTrue(didCancel)
        XCTAssertEqual(state.initialTemplate?.requests.first { $0.id == oneTime.id }?.status, .active)
    }
}
