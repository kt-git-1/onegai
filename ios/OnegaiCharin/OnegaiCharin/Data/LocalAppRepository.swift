import Foundation

@MainActor
final class LocalAppRepository: AppRepository {
    private(set) var authenticatedUser: AuthUser?
    private(set) var profile: UserProfile?
    private(set) var template: InitialTemplateResult?
    private(set) var revokedInviteIds: Set<String> = []
    private var inviteSequence = 1

    func signIn(with provider: AuthenticationProvider) async throws -> AuthUser {
        await pause()
        let email = provider == .apple ? "apple-preview@example.com" : "google-preview@example.com"
        return authenticate(email: email)
    }

    func register(email: String, password: String) async throws -> AuthUser {
        await pause()
        guard email.contains("@") else { throw AppRepositoryError.invalidEmail }
        guard password.count >= 8 else { throw AppRepositoryError.weakPassword }
        return authenticate(email: email)
    }

    func saveProfile(displayName: String, iconEmoji: String?) async throws -> UserProfile {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw AppRepositoryError.profileMissing }
        let now = Date()
        let value = UserProfile(
            id: user.id,
            displayName: trimmedName,
            iconEmoji: iconEmoji,
            photoURL: nil,
            email: user.email,
            activeGroupId: profile?.activeGroupId,
            createdAt: profile?.createdAt ?? now,
            updatedAt: now,
            deletedAt: nil
        )
        profile = value
        return value
    }

    func createInitialTemplate() async throws -> InitialTemplateResult {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard var currentProfile = profile else { throw AppRepositoryError.profileMissing }
        guard template == nil else { throw AppRepositoryError.templateAlreadyCreated }

        let now = Date()
        let groupId = "group-preview"
        let group = CoupleGroup(
            id: groupId,
            name: "\(currentProfile.displayName)とパートナー",
            type: "couple",
            status: .active,
            memberIds: [user.id],
            createdBy: user.id,
            createdAt: now,
            updatedAt: now,
            archivedAt: nil
        )
        let banks = [
            PiggyBank(id: "bank-personal", groupId: groupId, ownerType: .personal, ownerUserId: user.id, name: "\(currentProfile.displayName)の貯金箱", balance: 0, targetRewardId: "reward-coffee", status: .active, createdAt: now, updatedAt: now),
            PiggyBank(id: "bank-shared", groupId: groupId, ownerType: .shared, ownerUserId: nil, name: "ふたりの貯金箱", balance: 0, targetRewardId: "reward-yakiniku", status: .active, createdAt: now, updatedAt: now)
        ]
        let requests = [
            makeRequest(id: "request-massage", title: "マッサージ10分", emoji: "💆", coins: 100, bank: .personal, userId: user.id, groupId: groupId, now: now),
            makeRequest(id: "request-dishes", title: "皿洗い", emoji: "🧽", coins: 50, bank: .personal, userId: user.id, groupId: groupId, now: now),
            makeRequest(id: "request-clean", title: "ふたりで部屋を片付ける", emoji: "🧹", coins: 200, bank: .shared, userId: user.id, groupId: groupId, now: now)
        ]
        let rewards = [
            makeReward(id: "reward-coffee", title: "スタバごほうび券", emoji: "☕️", coins: 700, bank: .personal, userId: user.id, groupId: groupId, now: now),
            makeReward(id: "reward-yakiniku", title: "焼肉デートごほうび券", emoji: "🍖", coins: 5_000, bank: .shared, userId: user.id, groupId: groupId, now: now)
        ]
        let invite = makeInvite(groupId: groupId, userId: user.id, now: now)
        let result = InitialTemplateResult(group: group, piggyBanks: banks, requests: requests, rewards: rewards, invite: invite)
        template = result
        currentProfile.activeGroupId = groupId
        currentProfile.updatedAt = now
        profile = currentProfile
        return result
    }

    func reissueInvite() async throws -> Invite {
        await pause()
        guard let user = authenticatedUser, var current = template else { throw AppRepositoryError.inviteUnavailable }
        revokedInviteIds.insert(current.invite.id)
        inviteSequence += 1
        let replacement = makeInvite(groupId: current.group.id, userId: user.id, now: Date())
        current = InitialTemplateResult(group: current.group, piggyBanks: current.piggyBanks, requests: current.requests, rewards: current.rewards, invite: replacement)
        template = current
        return replacement
    }

    func completeInviteForPreview() async throws {
        await pause()
        guard var current = template else { throw AppRepositoryError.inviteUnavailable }
        var group = current.group
        group.memberIds.append("partner-preview")
        group.updatedAt = Date()
        var invite = current.invite
        invite.status = .used
        invite.usedAt = Date()
        invite.usedBy = "partner-preview"
        current = InitialTemplateResult(group: group, piggyBanks: current.piggyBanks, requests: current.requests, rewards: current.rewards, invite: invite)
        template = current
    }

    func signOut() async throws {
        await pause()
        authenticatedUser = nil
        profile = nil
        template = nil
        revokedInviteIds = []
    }

    private func authenticate(email: String) -> AuthUser {
        let user = AuthUser(id: "user-preview", email: email)
        authenticatedUser = user
        return user
    }

    private func makeInvite(groupId: String, userId: String, now: Date) -> Invite {
        Invite(id: "invite-\(inviteSequence)", groupId: groupId, code: String(format: "ABCD-%04d", 1233 + inviteSequence), createdBy: userId, status: .active, expiresAt: now.addingTimeInterval(60 * 60 * 24), createdAt: now, usedAt: nil, usedBy: nil)
    }

    private func makeRequest(id: String, title: String, emoji: String, coins: Int, bank: PiggyBank.OwnerType, userId: String, groupId: String, now: Date) -> RequestItem {
        RequestItem(id: id, groupId: groupId, createdBy: userId, title: title, iconEmoji: emoji, coinAmount: coins, piggyBankType: bank, repeatType: .repeatable, status: .active, completionCount: 0, lastCompletedAt: nil, createdAt: now, updatedAt: now)
    }

    private func makeReward(id: String, title: String, emoji: String, coins: Int, bank: PiggyBank.OwnerType, userId: String, groupId: String, now: Date) -> Reward {
        Reward(id: id, groupId: groupId, createdBy: userId, title: title, iconEmoji: emoji, requiredCoins: coins, piggyBankType: bank, isTarget: true, expiresInType: .none, expiresInDays: nil, expiresAt: nil, status: .active, createdAt: now, updatedAt: now)
    }

    private func pause() async {
        try? await Task.sleep(for: .milliseconds(120))
    }
}
