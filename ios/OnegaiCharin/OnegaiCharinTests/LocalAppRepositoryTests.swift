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
        XCTAssertFalse(result.requests.isEmpty)
        XCTAssertFalse(result.rewards.isEmpty)
        XCTAssertEqual(result.invite.status, .active)
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
