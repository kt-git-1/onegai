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
    }
}
