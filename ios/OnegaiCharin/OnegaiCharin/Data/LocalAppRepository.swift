import Foundation

@MainActor
final class LocalAppRepository: AppRepository {
    private let charinUndoDuration: TimeInterval = 10
    private(set) var authenticatedUser: AuthUser?
    private(set) var profile: UserProfile?
    private(set) var template: InitialTemplateResult?
    private(set) var records: [ActivityRecord] = []
    private(set) var tickets: [Ticket] = []
    private(set) var revokedInviteIds: Set<String> = []
    private var inviteSequence = 1
    private var memberObservers: [UUID: (Result<Int, Error>) -> Void] = [:]

    func signIn(with provider: AuthenticationProvider) async throws -> AuthUser {
        await pause()
        let email = provider == .apple ? "apple-preview@example.com" : "google-preview@example.com"
        return authenticate(email: email)
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        await pause()
        guard email.contains("@") else { throw AppRepositoryError.invalidEmail }
        guard password.count >= 8 else { throw AppRepositoryError.weakPassword }
        return authenticate(email: email)
    }

    func register(email: String, password: String) async throws -> AuthUser {
        await pause()
        guard email.contains("@") else { throw AppRepositoryError.invalidEmail }
        guard password.count >= 8 else { throw AppRepositoryError.weakPassword }
        return authenticate(email: email)
    }

    func sendPasswordReset(email: String) async throws {
        await pause()
        guard email.contains("@") else { throw AppRepositoryError.invalidEmail }
    }

    func loadSession() async throws -> AppSession {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        let partnerProfile: UserProfile?
        if let partnerId = template?.group.memberIds.first(where: { $0 != user.id }) {
            partnerProfile = makePartnerProfile(id: partnerId)
        } else {
            partnerProfile = nil
        }
        return AppSession(profile: profile, initialTemplate: template, partnerProfile: partnerProfile, records: records, tickets: tickets)
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

    func resolveInvite(identifier: String) async throws -> InvitePreview {
        await pause()
        let normalized = identifier.uppercased().filter { $0.isLetter || $0.isNumber }
        guard normalized == "ABCD1234" || identifier == "invite-preview" else {
            throw AppRepositoryError.invalidInviteCode
        }
        return InvitePreview(
            id: "invite-preview",
            code: "ABCD-1234",
            inviterName: "花男",
            inviterEmoji: "🌷",
            expiresAt: Date().addingTimeInterval(60 * 60 * 24)
        )
    }

    func acceptInvite(id: String) async throws {
        await pause()
        guard id == "invite-preview" else { throw AppRepositoryError.inviteUnavailable }
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard var currentProfile = profile else { throw AppRepositoryError.profileMissing }
        guard currentProfile.activeGroupId == nil, template == nil else { throw AppRepositoryError.alreadyInGroup }

        let now = Date()
        let groupId = "group-invite-preview"
        let group = CoupleGroup(
            id: groupId,
            name: "花男と\(currentProfile.displayName)",
            type: "couple",
            status: .active,
            memberIds: ["inviter-preview", user.id],
            createdBy: "inviter-preview",
            createdAt: now,
            updatedAt: now,
            archivedAt: nil
        )
        let banks = [
            PiggyBank(id: "bank-inviter", groupId: groupId, ownerType: .personal, ownerUserId: "inviter-preview", name: "花男の貯金箱", balance: 0, targetRewardId: nil, status: .active, createdAt: now, updatedAt: now),
            PiggyBank(id: "bank-invitee", groupId: groupId, ownerType: .personal, ownerUserId: user.id, name: "\(currentProfile.displayName)の貯金箱", balance: 0, targetRewardId: nil, status: .active, createdAt: now, updatedAt: now),
            PiggyBank(id: "bank-shared-invite", groupId: groupId, ownerType: .shared, ownerUserId: nil, name: "ふたりの貯金箱", balance: 0, targetRewardId: nil, status: .active, createdAt: now, updatedAt: now),
        ]
        var invite = makeInvite(groupId: groupId, userId: "inviter-preview", now: now)
        invite.status = .used
        invite.usedAt = now
        invite.usedBy = user.id
        template = InitialTemplateResult(group: group, piggyBanks: banks, requests: [], rewards: [], invite: invite)
        currentProfile.activeGroupId = groupId
        currentProfile.updatedAt = now
        profile = currentProfile
    }

    func createRequest(_ draft: RequestDraft) async throws -> RequestItem {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard var current = template else { throw AppRepositoryError.invalidBackendResponse }
        let normalized = try normalizedDraft(draft)
        let now = Date()
        let request = RequestItem(
            id: "request-\(UUID().uuidString.lowercased())",
            groupId: current.group.id,
            createdBy: user.id,
            title: normalized.title,
            iconEmoji: normalized.iconEmoji,
            coinAmount: normalized.coinAmount,
            piggyBankType: normalized.piggyBankType,
            repeatType: normalized.repeatType,
            status: .active,
            completionCount: 0,
            lastCompletedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        current = replacingRequests(in: current, with: current.requests + [request])
        template = current
        return request
    }

    func updateRequest(_ request: RequestItem, draft: RequestDraft) async throws -> RequestItem {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard request.createdBy == user.id else { throw AppRepositoryError.requestNotOwned }
        guard var current = template else { throw AppRepositoryError.invalidBackendResponse }
        let normalized = try normalizedDraft(draft)
        var updated = request
        updated.title = normalized.title
        updated.iconEmoji = normalized.iconEmoji
        updated.coinAmount = normalized.coinAmount
        updated.piggyBankType = normalized.piggyBankType
        updated.repeatType = normalized.repeatType
        updated.updatedAt = Date()
        current = replacingRequests(in: current, with: current.requests.map { $0.id == request.id ? updated : $0 })
        template = current
        return updated
    }

    func hideRequest(_ request: RequestItem) async throws -> RequestItem {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard request.createdBy == user.id else { throw AppRepositoryError.requestNotOwned }
        guard var current = template else { throw AppRepositoryError.invalidBackendResponse }
        var hidden = request
        hidden.status = .hidden
        hidden.updatedAt = Date()
        current = replacingRequests(in: current, with: current.requests.map { $0.id == request.id ? hidden : $0 })
        template = current
        return hidden
    }

    func createReward(_ draft: RewardDraft) async throws -> Reward {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard var current = template else { throw AppRepositoryError.invalidBackendResponse }
        let normalized = try normalizedRewardDraft(draft)
        let now = Date()
        let reward = Reward(
            id: "reward-\(UUID().uuidString.lowercased())",
            groupId: current.group.id,
            createdBy: user.id,
            title: normalized.title,
            iconEmoji: normalized.iconEmoji,
            requiredCoins: normalized.requiredCoins,
            piggyBankType: normalized.piggyBankType,
            isTarget: false,
            expiresInType: normalized.expiresInType,
            expiresInDays: normalized.expiresInDays,
            expiresAt: normalized.expiresAt,
            status: .active,
            createdAt: now,
            updatedAt: now
        )
        current = replacingRewards(in: current, with: current.rewards + [reward])
        template = current
        return reward
    }

    func updateReward(_ reward: Reward, draft: RewardDraft) async throws -> Reward {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard reward.createdBy == user.id else { throw AppRepositoryError.rewardNotOwned }
        guard var current = template else { throw AppRepositoryError.invalidBackendResponse }
        let normalized = try normalizedRewardDraft(draft)
        var updated = reward
        updated.title = normalized.title
        updated.iconEmoji = normalized.iconEmoji
        updated.requiredCoins = normalized.requiredCoins
        updated.piggyBankType = normalized.piggyBankType
        updated.expiresInType = normalized.expiresInType
        updated.expiresInDays = normalized.expiresInDays
        updated.expiresAt = normalized.expiresAt
        updated.updatedAt = Date()
        current = replacingRewards(in: current, with: current.rewards.map { $0.id == reward.id ? updated : $0 })
        template = current
        return updated
    }

    func hideReward(_ reward: Reward) async throws -> Reward {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard reward.createdBy == user.id else { throw AppRepositoryError.rewardNotOwned }
        guard var current = template else { throw AppRepositoryError.invalidBackendResponse }
        var hidden = reward
        hidden.status = .hidden
        hidden.updatedAt = Date()
        current = replacingRewards(in: current, with: current.rewards.map { $0.id == reward.id ? hidden : $0 })
        template = current
        return hidden
    }

    func exchangeReward(groupId: String, rewardId: String, piggyBankId: String) async throws -> RewardExchangeResult {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard var current = template,
              current.group.id == groupId,
              let reward = current.rewards.first(where: { $0.id == rewardId && $0.status == .active }),
              let bankIndex = current.piggyBanks.firstIndex(where: { $0.id == piggyBankId && $0.status == .active })
        else { throw AppRepositoryError.invalidBackendResponse }
        guard !tickets.contains(where: { $0.rewardId == rewardId && $0.status != .canceled }) else {
            throw AppRepositoryError.invalidBackendResponse
        }
        var bank = current.piggyBanks[bankIndex]
        guard bank.ownerType == reward.piggyBankType else { throw AppRepositoryError.invalidBackendResponse }
        guard bank.balance >= reward.requiredCoins else { throw AppRepositoryError.insufficientCoins }

        let now = Date()
        let balanceBefore = bank.balance
        bank.balance -= reward.requiredCoins
        bank.updatedAt = now
        current = replacingTemplate(current, banks: current.piggyBanks.map { $0.id == bank.id ? bank : $0 }, requests: current.requests)
        template = current

        let expiresAt: Date? = switch reward.expiresInType {
        case .none: nil
        case .days: Calendar.current.date(byAdding: .day, value: reward.expiresInDays ?? 0, to: now)
        case .date: reward.expiresAt
        }
        let ticket = Ticket(
            id: "ticket-\(UUID().uuidString.lowercased())",
            groupId: groupId,
            rewardId: reward.id,
            issuedBy: user.id,
            ownerUserId: bank.ownerType == .personal ? bank.ownerUserId : nil,
            piggyBankId: bank.id,
            ticketType: bank.ownerType,
            title: reward.title,
            iconEmoji: reward.iconEmoji,
            spentCoins: reward.requiredCoins,
            status: .unused,
            issuedAt: now,
            usedAt: nil,
            usedBy: nil,
            expiresAt: expiresAt,
            createdAt: now,
            updatedAt: now
        )
        let record = ActivityRecord(
            id: "record-\(UUID().uuidString.lowercased())",
            groupId: groupId,
            userId: user.id,
            type: .rewardExchange,
            targetType: "reward",
            targetId: reward.id,
            title: reward.title,
            iconEmoji: reward.iconEmoji,
            coinDelta: -reward.requiredCoins,
            piggyBankId: bank.id,
            piggyBankName: bank.name,
            balanceBefore: balanceBefore,
            balanceAfter: bank.balance,
            status: .active,
            createdAt: now,
            canceledAt: nil
        )
        tickets.insert(ticket, at: 0)
        records.insert(record, at: 0)
        return RewardExchangeResult(ticket: ticket, record: record)
    }

    func useTicket(ticketId: String) async throws -> TicketUseResult {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard let ticketIndex = tickets.firstIndex(where: { $0.id == ticketId }),
              tickets[ticketIndex].status == .unused,
              let current = template,
              let bank = current.piggyBanks.first(where: { $0.id == tickets[ticketIndex].piggyBankId })
        else { throw AppRepositoryError.invalidBackendResponse }
        let now = Date()
        var ticket = tickets[ticketIndex]
        ticket.status = .used
        ticket.usedAt = now
        ticket.usedBy = user.id
        ticket.updatedAt = now
        tickets[ticketIndex] = ticket
        let record = ActivityRecord(
            id: "record-\(UUID().uuidString.lowercased())", groupId: ticket.groupId,
            userId: user.id, type: .ticketUsed, targetType: "ticket", targetId: ticket.id,
            title: ticket.title, iconEmoji: ticket.iconEmoji, coinDelta: 0,
            piggyBankId: bank.id, piggyBankName: bank.name,
            balanceBefore: bank.balance, balanceAfter: bank.balance,
            status: .active, createdAt: now, canceledAt: nil
        )
        records.insert(record, at: 0)
        return TicketUseResult(ticket: ticket, record: record)
    }

    func charinRequest(groupId: String, requestId: String) async throws -> CharinResult {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard var current = template,
              current.group.id == groupId,
              let requestIndex = current.requests.firstIndex(where: { $0.id == requestId && $0.status == .active })
        else { throw AppRepositoryError.invalidBackendResponse }

        var request = current.requests[requestIndex]
        guard let bankIndex = current.piggyBanks.firstIndex(where: { bank in
            guard bank.status == .active, bank.ownerType == request.piggyBankType else { return false }
            return bank.ownerType == .shared || bank.ownerUserId == request.createdBy
        }) else { throw AppRepositoryError.invalidBackendResponse }

        var bank = current.piggyBanks[bankIndex]
        let now = Date()
        let balanceBefore = bank.balance
        bank.balance += request.coinAmount
        bank.updatedAt = now
        request.completionCount += 1
        request.lastCompletedAt = now
        request.updatedAt = now
        if request.repeatType == .oneTime { request.status = .hidden }

        let record = ActivityRecord(
            id: "record-\(UUID().uuidString.lowercased())",
            groupId: groupId,
            userId: user.id,
            type: .charin,
            targetType: "request",
            targetId: request.id,
            title: request.title,
            iconEmoji: request.iconEmoji,
            coinDelta: request.coinAmount,
            piggyBankId: bank.id,
            piggyBankName: bank.name,
            balanceBefore: balanceBefore,
            balanceAfter: bank.balance,
            status: .active,
            createdAt: now,
            canceledAt: nil
        )
        let exchangedRewardIds = Set(tickets.filter { $0.status != .canceled }.map(\.rewardId))
        let nearestReward = current.rewards
            .filter { reward in
                guard reward.status == .active,
                      reward.piggyBankType == bank.ownerType,
                      !exchangedRewardIds.contains(reward.id) else { return false }
                return bank.ownerType == .shared || reward.createdBy == bank.ownerUserId
            }
            .min { lhs, rhs in
                let lhsRemaining = max(lhs.requiredCoins - bank.balance, 0)
                let rhsRemaining = max(rhs.requiredCoins - bank.balance, 0)
                if lhsRemaining != rhsRemaining { return lhsRemaining < rhsRemaining }
                return lhs.requiredCoins < rhs.requiredCoins
            }
        let targetReward = nearestReward.map {
            TargetRewardProgress(
                id: $0.id,
                title: $0.title,
                iconEmoji: $0.iconEmoji,
                remainingCoins: max($0.requiredCoins - bank.balance, 0),
                isExchangeable: bank.balance >= $0.requiredCoins,
                becameExchangeable: balanceBefore < $0.requiredCoins && bank.balance >= $0.requiredCoins
            )
        }

        var banks = current.piggyBanks
        banks[bankIndex] = bank
        var requests = current.requests
        requests[requestIndex] = request
        current = replacingTemplate(current, banks: banks, requests: requests)
        template = current
        records.insert(record, at: 0)
        return CharinResult(
            record: record,
            requestId: request.id,
            requestStatus: request.status,
            completionCount: request.completionCount,
            targetReward: targetReward
        )
    }

    func cancelCharin(recordId: String) async throws -> CharinCancellationResult {
        await pause()
        guard let user = authenticatedUser else { throw AppRepositoryError.unauthenticated }
        guard let recordIndex = records.firstIndex(where: { $0.id == recordId }),
              records[recordIndex].userId == user.id,
              records[recordIndex].status == .active,
              Date().timeIntervalSince(records[recordIndex].createdAt) <= charinUndoDuration,
              var current = template
        else { throw AppRepositoryError.invalidBackendResponse }

        let record = records[recordIndex]
        guard let bankIndex = current.piggyBanks.firstIndex(where: { $0.id == record.piggyBankId }),
              let requestIndex = current.requests.firstIndex(where: { $0.id == record.targetId })
        else { throw AppRepositoryError.invalidBackendResponse }

        let now = Date()
        var bank = current.piggyBanks[bankIndex]
        bank.balance -= record.coinDelta
        bank.updatedAt = now
        var request = current.requests[requestIndex]
        request.completionCount = max(request.completionCount - 1, 0)
        if request.repeatType == .oneTime && request.status == .hidden { request.status = .active }
        request.updatedAt = now
        let canceledRecord = ActivityRecord(
            id: record.id,
            groupId: record.groupId,
            userId: record.userId,
            type: record.type,
            targetType: record.targetType,
            targetId: record.targetId,
            title: record.title,
            iconEmoji: record.iconEmoji,
            coinDelta: record.coinDelta,
            piggyBankId: record.piggyBankId,
            piggyBankName: record.piggyBankName,
            balanceBefore: record.balanceBefore,
            balanceAfter: record.balanceAfter,
            status: .canceled,
            createdAt: record.createdAt,
            canceledAt: now
        )

        var banks = current.piggyBanks
        banks[bankIndex] = bank
        var requests = current.requests
        requests[requestIndex] = request
        current = replacingTemplate(current, banks: banks, requests: requests)
        template = current
        records[recordIndex] = canceledRecord
        return CharinCancellationResult(
            recordId: record.id,
            requestId: request.id,
            piggyBankId: bank.id,
            balanceAfter: bank.balance,
            requestStatus: request.status,
            completionCount: request.completionCount
        )
    }

    func observeGroupMemberCount(
        groupId: String,
        onChange: @escaping (Result<Int, Error>) -> Void
    ) -> AppObservation {
        let id = UUID()
        memberObservers[id] = onChange
        if let template, template.group.id == groupId {
            onChange(.success(template.group.memberIds.count))
        }
        return AppObservation { [weak self] in
            self?.memberObservers[id] = nil
        }
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
        memberObservers.values.forEach { $0(.success(group.memberIds.count)) }
    }

    func signOut() async throws {
        await pause()
        authenticatedUser = nil
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

    private func makePartnerProfile(id: String) -> UserProfile {
        let now = Date()
        return UserProfile(
            id: id,
            displayName: id == "inviter-preview" ? "花男" : "花子",
            iconEmoji: id == "inviter-preview" ? "😊" : "🌷",
            photoURL: nil,
            email: nil,
            activeGroupId: template?.group.id,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
    }

    private func normalizedDraft(_ draft: RequestDraft) throws -> RequestDraft {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = draft.iconEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !emoji.isEmpty, draft.coinAmount > 0 else {
            throw AppRepositoryError.invalidRequest
        }
        return RequestDraft(
            title: title,
            iconEmoji: emoji,
            coinAmount: draft.coinAmount,
            piggyBankType: draft.piggyBankType,
            repeatType: draft.repeatType
        )
    }

    private func normalizedRewardDraft(_ draft: RewardDraft) throws -> RewardDraft {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = draft.iconEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let expiryIsValid = switch draft.expiresInType {
        case .none: true
        case .days: draft.expiresInDays.map { $0 > 0 } ?? false
        case .date: draft.expiresAt.map { $0 > Date() } ?? false
        }
        guard !title.isEmpty, !emoji.isEmpty, draft.requiredCoins > 0, expiryIsValid else {
            throw AppRepositoryError.invalidReward
        }
        return RewardDraft(
            title: title,
            iconEmoji: emoji,
            requiredCoins: draft.requiredCoins,
            piggyBankType: draft.piggyBankType,
            expiresInType: draft.expiresInType,
            expiresInDays: draft.expiresInType == .days ? draft.expiresInDays : nil,
            expiresAt: draft.expiresInType == .date ? draft.expiresAt : nil
        )
    }

    private func replacingRequests(in current: InitialTemplateResult, with requests: [RequestItem]) -> InitialTemplateResult {
        InitialTemplateResult(
            group: current.group,
            piggyBanks: current.piggyBanks,
            requests: requests,
            rewards: current.rewards,
            invite: current.invite
        )
    }

    private func replacingRewards(in current: InitialTemplateResult, with rewards: [Reward]) -> InitialTemplateResult {
        InitialTemplateResult(
            group: current.group,
            piggyBanks: current.piggyBanks,
            requests: current.requests,
            rewards: rewards,
            invite: current.invite
        )
    }

    private func replacingTemplate(
        _ current: InitialTemplateResult,
        banks: [PiggyBank],
        requests: [RequestItem]
    ) -> InitialTemplateResult {
        InitialTemplateResult(
            group: current.group,
            piggyBanks: banks,
            requests: requests,
            rewards: current.rewards,
            invite: current.invite
        )
    }

    #if DEBUG
    func seedPreview(user: AuthUser, profile: UserProfile, template: InitialTemplateResult, records: [ActivityRecord]) {
        authenticatedUser = user
        self.profile = profile
        self.template = template
        self.records = records
    }
    #endif

    private func pause() async {
        try? await Task.sleep(for: .milliseconds(120))
    }
}
