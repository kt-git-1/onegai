import SwiftUI

enum AppPhase: Equatable {
    case onboarding
    case authentication
    case emailRegistration
    case emailLogin
    case inviteCodeEntry
    case inviteAcceptance
    case profile
    case template
    case invite
    case inviteWaiting
    case charinCelebration
    case main
}

@MainActor
final class AppState: ObservableObject {
    private static let charinUndoDuration: TimeInterval = 10
    @Published var phase: AppPhase = .onboarding
    @Published var onboardingPage = 0
    @Published var displayName = ""
    @Published var selectedEmoji: String?
    @Published var selectedTab = 0
    @Published var rewardCreationRequested = false
    @Published var usableTicketsRequested = false
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var authenticatedUser: AuthUser?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var initialTemplate: InitialTemplateResult?
    @Published private(set) var passwordResetEmailSent = false
    @Published private(set) var pendingInvite: InvitePreview?
    @Published private(set) var partnerProfile: UserProfile?
    @Published private(set) var records: [ActivityRecord] = []
    @Published private(set) var tickets: [Ticket] = []
    @Published var issuedTicket: Ticket?
    @Published private(set) var activeCharin: CharinResult?
    @Published private(set) var pendingCharinUndo: PendingCharinUndo?

    private let repository: any AppRepository
    private let persistsPendingInvite: Bool
    private let pendingInviteStorageKey = "pendingInvite"
    private var partnerObservation: AppObservation?

    init(repository: (any AppRepository)? = nil) {
        if let repository {
            self.repository = repository
            persistsPendingInvite = false
        } else if ProcessInfo.processInfo.arguments.contains("-useFirebase")
                    || ProcessInfo.processInfo.arguments.contains("-useFirebaseEmulator") {
            self.repository = FirebaseAppRepository()
            persistsPendingInvite = true
        } else {
            self.repository = LocalAppRepository()
            persistsPendingInvite = true
        }
        if persistsPendingInvite,
           let data = UserDefaults.standard.data(forKey: pendingInviteStorageKey),
           let storedInvite = try? JSONDecoder().decode(InvitePreview.self, from: data) {
            pendingInvite = storedInvite
            phase = .inviteAcceptance
        }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-previewPhase"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "authentication": phase = .authentication
            case "emailLogin": phase = .emailLogin
            case "inviteCodeEntry": phase = .inviteCodeEntry
            case "inviteAcceptance":
                pendingInvite = InvitePreview(
                    id: "invite-preview",
                    code: "ABCD-1234",
                    inviterName: "花男",
                    inviterEmoji: "🌷",
                    expiresAt: Date().addingTimeInterval(60 * 60 * 24)
                )
                phase = .inviteAcceptance
            case "profile": phase = .profile
            case "inviteWaiting":
                initialTemplate = Self.makePreviewTemplate()
                phase = .inviteWaiting
            case "charinCelebration":
                let template = Self.makePreviewTemplate(joined: true)
                let previewUser = AuthUser(id: "user-preview", email: "preview@example.com")
                let previewProfile = Self.makePreviewProfile(id: "user-preview", name: "花男", emoji: "😊", groupId: template.group.id)
                let previewRecords = Self.makePreviewRecords(groupId: template.group.id)
                authenticatedUser = previewUser
                profile = previewProfile
                partnerProfile = Self.makePreviewProfile(id: "partner-preview", name: "花子", emoji: "🌷", groupId: template.group.id)
                initialTemplate = template
                records = previewRecords
                let previewRecord = arguments.contains("-previewSharedBank") ?
                    previewRecords.first(where: { $0.piggyBankId == "bank-shared" }) : previewRecords.first
                if let record = previewRecord {
                    let shared = record.piggyBankId == "bank-shared"
                    activeCharin = CharinResult(
                        record: record,
                        requestId: record.targetId,
                        requestStatus: .active,
                        completionCount: shared ? 4 : 8,
                        targetReward: TargetRewardProgress(
                            id: shared ? "reward-yakiniku" : "reward-sweets",
                            title: shared ? "焼肉デートごほうび券" : "コンビニスイーツ券",
                            iconEmoji: shared ? "🍖" : "🍰",
                            remainingCoins: shared ? 2_200 : 0,
                            isExchangeable: !shared,
                            becameExchangeable: !shared
                        )
                    )
                    pendingCharinUndo = PendingCharinUndo(recordId: record.id, expiresAt: Date().addingTimeInterval(Self.charinUndoDuration))
                }
                if let localRepository = self.repository as? LocalAppRepository {
                    localRepository.seedPreview(user: previewUser, profile: previewProfile, template: template, records: previewRecords)
                }
                phase = .charinCelebration
            case "main":
                let template = Self.makePreviewTemplate(joined: true)
                authenticatedUser = AuthUser(id: "user-preview", email: "preview@example.com")
                profile = Self.makePreviewProfile(id: "user-preview", name: "花男", emoji: "😊", groupId: template.group.id)
                partnerProfile = Self.makePreviewProfile(id: "partner-preview", name: "花子", emoji: "🌷", groupId: template.group.id)
                initialTemplate = template
                records = Self.makePreviewRecords(groupId: template.group.id)
                if arguments.contains("-previewIssuedTicket") {
                    let now = Date()
                    issuedTicket = Ticket(
                        id: "ticket-issued-preview", groupId: template.group.id, rewardId: "reward-sweets",
                        issuedBy: "user-preview", ownerUserId: "user-preview",
                        piggyBankId: "bank-personal", ticketType: .personal,
                        title: "コンビニスイーツ券", iconEmoji: "🍰", spentCoins: 500,
                        status: .unused, issuedAt: now, usedAt: nil, usedBy: nil,
                        expiresAt: nil, createdAt: now, updatedAt: now
                    )
                }
                if let localRepository = self.repository as? LocalAppRepository,
                   let profile {
                    localRepository.seedPreview(
                        user: authenticatedUser!,
                        profile: profile,
                        template: template,
                        records: records
                    )
                }
                phase = .main
            default: break
            }
        }
        if let index = arguments.firstIndex(of: "-previewTab"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "requests": selectedTab = 1
            case "rewards": selectedTab = 2
            case "records": selectedTab = 3
            default: selectedTab = 0
            }
        }
        if arguments.contains("-previewUndoToast"), let record = records.first {
            pendingCharinUndo = PendingCharinUndo(recordId: record.id, expiresAt: Date().addingTimeInterval(Self.charinUndoDuration))
        }
        #endif
    }

    var inviteCode: String { initialTemplate?.invite.code ?? "準備中" }

    var inviteURL: URL? {
        guard let inviteId = initialTemplate?.invite.id else { return nil }
        return URL(string: "https://onegai-charin-dev.web.app/invite/\(inviteId)")
    }

    private static func makePreviewTemplate(joined: Bool = false) -> InitialTemplateResult {
        let now = Date()
        let group = CoupleGroup(
            id: "group-preview",
            name: "花男とパートナー",
            type: "couple",
            status: .active,
            memberIds: joined ? ["user-preview", "partner-preview"] : ["user-preview"],
            createdBy: "user-preview",
            createdAt: now,
            updatedAt: now,
            archivedAt: nil
        )
        let invite = Invite(
            id: "invite-preview",
            groupId: group.id,
            code: "ABCD-1234",
            createdBy: "user-preview",
            status: joined ? .used : .active,
            expiresAt: now.addingTimeInterval(60 * 60 * 24),
            createdAt: now,
            usedAt: joined ? now : nil,
            usedBy: joined ? "partner-preview" : nil
        )
        let rewards = [
            Reward(id: "reward-coffee", groupId: group.id, createdBy: "user-preview", title: "スタバごほうび券", iconEmoji: "☕️", requiredCoins: 700, piggyBankType: .personal, isTarget: false, expiresInType: .none, expiresInDays: nil, expiresAt: nil, status: .active, createdAt: now, updatedAt: now),
            Reward(id: "reward-sweets", groupId: group.id, createdBy: "user-preview", title: "コンビニスイーツ券", iconEmoji: "🍰", requiredCoins: 500, piggyBankType: .personal, isTarget: false, expiresInType: .none, expiresInDays: nil, expiresAt: nil, status: .active, createdAt: now, updatedAt: now),
            Reward(id: "reward-yakiniku", groupId: group.id, createdBy: "user-preview", title: "焼肉デートごほうび券", iconEmoji: "🍖", requiredCoins: 5_000, piggyBankType: .shared, isTarget: false, expiresInType: .none, expiresInDays: nil, expiresAt: nil, status: .active, createdAt: now, updatedAt: now),
        ]
        let banks = [
            PiggyBank(id: "bank-personal", groupId: group.id, ownerType: .personal, ownerUserId: "user-preview", name: "花男の貯金箱", balance: 520, targetRewardId: nil, status: .active, createdAt: now, updatedAt: now),
            PiggyBank(id: "bank-shared", groupId: group.id, ownerType: .shared, ownerUserId: nil, name: "ふたりの貯金箱", balance: 2_800, targetRewardId: nil, status: .active, createdAt: now, updatedAt: now),
        ]
        let requests = [
            RequestItem(id: "request-massage", groupId: group.id, createdBy: "user-preview", title: "マッサージ10分", iconEmoji: "💆", coinAmount: 100, piggyBankType: .personal, repeatType: .repeatable, status: .active, completionCount: 8, lastCompletedAt: now, createdAt: now, updatedAt: now),
            RequestItem(id: "request-dishes", groupId: group.id, createdBy: "user-preview", title: "皿洗い", iconEmoji: "🧽", coinAmount: 50, piggyBankType: .personal, repeatType: .repeatable, status: .active, completionCount: 5, lastCompletedAt: now, createdAt: now, updatedAt: now),
            RequestItem(id: "request-clean", groupId: group.id, createdBy: "user-preview", title: "ふたりで部屋を片付ける", iconEmoji: "🧹", coinAmount: 200, piggyBankType: .shared, repeatType: .repeatable, status: .active, completionCount: 4, lastCompletedAt: now, createdAt: now, updatedAt: now),
            RequestItem(id: "request-date", groupId: group.id, createdBy: "partner-preview", title: "デートの予定を決める", iconEmoji: "🥢", coinAmount: 300, piggyBankType: .shared, repeatType: .repeatable, status: .active, completionCount: 2, lastCompletedAt: now, createdAt: now, updatedAt: now),
        ]
        return InitialTemplateResult(group: group, piggyBanks: banks, requests: requests, rewards: rewards, invite: invite)
    }

    private static func makePreviewProfile(id: String, name: String, emoji: String, groupId: String) -> UserProfile {
        let now = Date()
        return UserProfile(id: id, displayName: name, iconEmoji: emoji, photoURL: nil, email: nil, activeGroupId: groupId, createdAt: now, updatedAt: now, deletedAt: nil)
    }

    private static func makePreviewRecords(groupId: String) -> [ActivityRecord] {
        let now = Date()
        return [
            ActivityRecord(id: "record-massage", groupId: groupId, userId: "partner-preview", type: .charin, targetType: "request", targetId: "request-massage", title: "マッサージ10分", iconEmoji: "💆", coinDelta: 100, piggyBankId: "bank-personal", piggyBankName: "花男の貯金箱", balanceBefore: 420, balanceAfter: 520, status: .active, createdAt: now.addingTimeInterval(-3_600), canceledAt: nil),
            ActivityRecord(id: "record-clean", groupId: groupId, userId: "user-preview", type: .charin, targetType: "request", targetId: "request-clean", title: "ふたりで部屋を片付ける", iconEmoji: "🧹", coinDelta: 200, piggyBankId: "bank-shared", piggyBankName: "ふたりの貯金箱", balanceBefore: 2_600, balanceAfter: 2_800, status: .active, createdAt: now.addingTimeInterval(-7_200), canceledAt: nil),
        ]
    }

    func signIn(with provider: AuthenticationProvider) async {
        await perform {
            let user = try await repository.signIn(with: provider)
            try await restoreSession(for: user)
        }
    }

    func register(email: String, password: String) async {
        await perform {
            let user = try await repository.register(email: email, password: password)
            try await restoreSession(for: user)
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            let user = try await repository.signIn(email: email, password: password)
            try await restoreSession(for: user)
        }
    }

    func sendPasswordReset(email: String) async {
        passwordResetEmailSent = false
        await perform {
            try await repository.sendPasswordReset(email: email)
            passwordResetEmailSent = true
        }
    }

    func saveProfile() async {
        await perform {
            profile = try await repository.saveProfile(displayName: displayName, iconEmoji: selectedEmoji)
            if pendingInvite != nil {
                try await acceptPendingInvite()
            } else {
                phase = .template
            }
        }
    }

    func resolveInvite(code: String) async {
        await resolveInvite(identifier: code)
    }

    func handleIncomingURL(_ url: URL) async {
        guard let identifier = inviteIdentifier(from: url) else { return }
        await resolveInvite(identifier: identifier)
    }

    func beginInviteAcceptance() async {
        guard pendingInvite != nil else { return }
        guard authenticatedUser != nil else {
            phase = .authentication
            return
        }
        guard profile != nil else {
            phase = .profile
            return
        }
        await perform {
            try await acceptPendingInvite()
        }
    }

    func cancelPendingInvite() {
        pendingInvite = nil
        persistPendingInvite()
        clearError()
        guard authenticatedUser != nil else {
            phase = .authentication
            return
        }
        guard profile != nil else {
            phase = .profile
            return
        }
        if let template = initialTemplate {
            phase = template.group.memberIds.count >= 2 ? .main : .inviteWaiting
        } else {
            phase = .template
        }
    }

    func applyInitialTemplate() async {
        await perform {
            initialTemplate = try await repository.createInitialTemplate()
            phase = .invite
        }
    }

    func completeInviteForPreview() async {
        await perform {
            try await repository.completeInviteForPreview()
        }
    }

    func reissueInvite() async {
        await perform {
            let invite = try await repository.reissueInvite()
            guard let current = initialTemplate else { return }
            initialTemplate = InitialTemplateResult(
                group: current.group,
                piggyBanks: current.piggyBanks,
                requests: current.requests,
                rewards: current.rewards,
                invite: invite
            )
        }
    }

    func createRequest(_ draft: RequestDraft) async -> Bool {
        await perform {
            let request = try await repository.createRequest(draft)
            replaceRequest(request)
        }
    }

    func updateRequest(_ request: RequestItem, draft: RequestDraft) async -> Bool {
        await perform {
            let updated = try await repository.updateRequest(request, draft: draft)
            replaceRequest(updated)
        }
    }

    func hideRequest(_ request: RequestItem) async -> Bool {
        await perform {
            let hidden = try await repository.hideRequest(request)
            replaceRequest(hidden)
        }
    }

    func createReward(_ draft: RewardDraft) async -> Bool {
        await perform {
            let reward = try await repository.createReward(draft)
            replaceReward(reward)
        }
    }

    func presentRewardCreation() {
        rewardCreationRequested = true
        selectedTab = 2
    }

    func presentUsableTickets() {
        usableTicketsRequested = true
        selectedTab = 2
    }

    func updateReward(_ reward: Reward, draft: RewardDraft) async -> Bool {
        await perform {
            let updated = try await repository.updateReward(reward, draft: draft)
            replaceReward(updated)
        }
    }

    func hideReward(_ reward: Reward) async -> Bool {
        await perform {
            let hidden = try await repository.hideReward(reward)
            replaceReward(hidden)
        }
    }

    func exchangeReward(_ reward: Reward, from bank: PiggyBank) async -> Bool {
        await perform {
            let result = try await repository.exchangeReward(
                groupId: reward.groupId,
                rewardId: reward.id,
                piggyBankId: bank.id
            )
            applyRewardExchange(result)
            issuedTicket = result.ticket
        }
    }

    func useTicket(_ ticket: Ticket) async -> Bool {
        await perform {
            let result = try await repository.useTicket(ticketId: ticket.id)
            tickets.removeAll { $0.id == result.ticket.id }
            tickets.insert(result.ticket, at: 0)
            records.removeAll { $0.id == result.record.id }
            records.insert(result.record, at: 0)
        }
    }

    func charin(_ request: RequestItem) async -> Bool {
        await perform {
            let result = try await repository.charinRequest(groupId: request.groupId, requestId: request.id)
            applyCharin(result)
            activeCharin = result
            pendingCharinUndo = PendingCharinUndo(
                recordId: result.record.id,
                expiresAt: result.record.createdAt.addingTimeInterval(Self.charinUndoDuration)
            )
            phase = .charinCelebration
        }
    }

    func finishCharinCelebration() {
        guard phase == .charinCelebration else { return }
        activeCharin = nil
        selectedTab = 0
        rewardCreationRequested = false
        usableTicketsRequested = false
        phase = .main
    }

    func cancelLatestCharin() async -> Bool {
        guard let pendingCharinUndo, pendingCharinUndo.expiresAt > Date() else {
            self.pendingCharinUndo = nil
            return false
        }
        return await perform {
            let result = try await repository.cancelCharin(recordId: pendingCharinUndo.recordId)
            applyCharinCancellation(result)
            self.pendingCharinUndo = nil
            activeCharin = nil
            if phase == .charinCelebration {
                selectedTab = 0
                phase = .main
            }
        }
    }

    func expireCharinUndoIfNeeded(at date: Date = Date()) {
        if let pendingCharinUndo, pendingCharinUndo.expiresAt <= date {
            self.pendingCharinUndo = nil
        }
    }

    func piggyBank(for request: RequestItem) -> PiggyBank? {
        initialTemplate?.piggyBanks.first { bank in
            guard bank.status == .active, bank.ownerType == request.piggyBankType else { return false }
            return bank.ownerType == .shared || bank.ownerUserId == request.createdBy
        }
    }

    func nearestReward(for bank: PiggyBank) -> Reward? {
        guard let rewards = initialTemplate?.rewards else { return nil }
        return rewards
            .filter { reward in
                guard reward.status == .active, reward.piggyBankType == bank.ownerType else { return false }
                if bank.ownerType == .personal, reward.createdBy != bank.ownerUserId { return false }
                return !hasExchangedReward(reward)
            }
            .min { lhs, rhs in
                let lhsRemaining = max(lhs.requiredCoins - bank.balance, 0)
                let rhsRemaining = max(rhs.requiredCoins - bank.balance, 0)
                if lhsRemaining != rhsRemaining { return lhsRemaining < rhsRemaining }
                return lhs.requiredCoins < rhs.requiredCoins
            }
    }

    func hasExchangedReward(_ reward: Reward) -> Bool {
        tickets.contains { $0.rewardId == reward.id && $0.status != .canceled }
    }

    func startObservingInviteCompletion() {
        guard partnerObservation == nil, let groupId = initialTemplate?.group.id else { return }
        partnerObservation = repository.observeGroupMemberCount(groupId: groupId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let memberCount) where memberCount >= 2:
                stopObservingInviteCompletion()
                Task { await self.refreshAfterPartnerJoined() }
            case .success:
                break
            case .failure(let error):
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func stopObservingInviteCompletion() {
        partnerObservation?.cancel()
        partnerObservation = nil
    }

    func signOut() async {
        await perform {
            stopObservingInviteCompletion()
            try await repository.signOut()
            reset()
        }
    }

    func clearError() {
        errorMessage = nil
        passwordResetEmailSent = false
    }

    private func restoreSession(for user: AuthUser) async throws {
        authenticatedUser = user
        let session = try await repository.loadSession()
        profile = session.profile
        initialTemplate = session.initialTemplate
        partnerProfile = session.partnerProfile
        records = session.records
        tickets = session.tickets
        displayName = session.profile?.displayName ?? ""
        selectedEmoji = session.profile?.iconEmoji

        if pendingInvite != nil {
            guard session.profile != nil else {
                phase = .profile
                return
            }
            try await acceptPendingInvite()
            return
        }

        guard session.profile != nil else {
            phase = .profile
            return
        }
        guard let template = session.initialTemplate else {
            phase = .template
            return
        }
        phase = template.group.memberIds.count >= 2 ? .main : .inviteWaiting
    }

    private func resolveInvite(identifier: String) async {
        await perform {
            pendingInvite = try await repository.resolveInvite(identifier: identifier)
            persistPendingInvite()
            phase = .inviteAcceptance
        }
    }

    private func acceptPendingInvite() async throws {
        guard let pendingInvite else { throw AppRepositoryError.inviteUnavailable }
        try await repository.acceptInvite(id: pendingInvite.id)
        let session = try await repository.loadSession()
        profile = session.profile
        initialTemplate = session.initialTemplate
        partnerProfile = session.partnerProfile
        records = session.records
        tickets = session.tickets
        self.pendingInvite = nil
        persistPendingInvite()
        phase = .main
    }

    private func refreshAfterPartnerJoined() async {
        await perform {
            let session = try await repository.loadSession()
            profile = session.profile
            initialTemplate = session.initialTemplate
            partnerProfile = session.partnerProfile
            records = session.records
            tickets = session.tickets
            phase = .main
        }
    }

    private func persistPendingInvite() {
        guard persistsPendingInvite else { return }
        if let pendingInvite, let data = try? JSONEncoder().encode(pendingInvite) {
            UserDefaults.standard.set(data, forKey: pendingInviteStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pendingInviteStorageKey)
        }
    }

    private func inviteIdentifier(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let value = components?.queryItems?.first(where: { $0.name == "code" || $0.name == "invite" })?.value,
           !value.isEmpty {
            return value
        }
        let pathParts = url.pathComponents.filter { $0 != "/" }
        if url.host == "invite", let first = pathParts.first {
            return first
        }
        if let inviteIndex = pathParts.firstIndex(of: "invite"), pathParts.indices.contains(inviteIndex + 1) {
            return pathParts[inviteIndex + 1]
        }
        return nil
    }

    @discardableResult
    private func perform(_ operation: () async throws -> Void) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil
        passwordResetEmailSent = false
        defer { isProcessing = false }
        do {
            try await operation()
            return true
        } catch is CancellationError {
            errorMessage = nil
            return false
        } catch {
            if let description = (error as? LocalizedError)?.errorDescription {
                errorMessage = description
            } else {
                #if DEBUG
                errorMessage = error.localizedDescription
                #else
                errorMessage = "通信に失敗しました。もう一度お試しください。"
                #endif
            }
            return false
        }
    }

    private func replaceRequest(_ request: RequestItem) {
        guard let current = initialTemplate else { return }
        var requests = current.requests.filter { $0.id != request.id }
        requests.append(request)
        initialTemplate = InitialTemplateResult(
            group: current.group,
            piggyBanks: current.piggyBanks,
            requests: requests,
            rewards: current.rewards,
            invite: current.invite
        )
    }

    private func replaceReward(_ reward: Reward) {
        guard let current = initialTemplate else { return }
        var rewards = current.rewards.filter { $0.id != reward.id }
        rewards.append(reward)
        initialTemplate = InitialTemplateResult(
            group: current.group,
            piggyBanks: current.piggyBanks,
            requests: current.requests,
            rewards: rewards,
            invite: current.invite
        )
    }

    private func applyCharin(_ result: CharinResult) {
        guard let current = initialTemplate else { return }
        let banks = current.piggyBanks.map { bank -> PiggyBank in
            guard bank.id == result.record.piggyBankId else { return bank }
            var updated = bank
            updated.balance = result.record.balanceAfter
            updated.updatedAt = result.record.createdAt
            return updated
        }
        let requests = current.requests.map { request -> RequestItem in
            guard request.id == result.requestId else { return request }
            var updated = request
            updated.status = result.requestStatus
            updated.completionCount = result.completionCount
            updated.lastCompletedAt = result.record.createdAt
            updated.updatedAt = result.record.createdAt
            return updated
        }
        initialTemplate = InitialTemplateResult(
            group: current.group,
            piggyBanks: banks,
            requests: requests,
            rewards: current.rewards,
            invite: current.invite
        )
        records.removeAll { $0.id == result.record.id }
        records.insert(result.record, at: 0)
    }

    private func applyRewardExchange(_ result: RewardExchangeResult) {
        guard let current = initialTemplate else { return }
        let banks = current.piggyBanks.map { bank -> PiggyBank in
            guard bank.id == result.record.piggyBankId else { return bank }
            var updated = bank
            updated.balance = result.record.balanceAfter
            updated.updatedAt = result.record.createdAt
            return updated
        }
        initialTemplate = InitialTemplateResult(
            group: current.group,
            piggyBanks: banks,
            requests: current.requests,
            rewards: current.rewards,
            invite: current.invite
        )
        tickets.removeAll { $0.id == result.ticket.id }
        tickets.insert(result.ticket, at: 0)
        records.removeAll { $0.id == result.record.id }
        records.insert(result.record, at: 0)
    }

    private func applyCharinCancellation(_ result: CharinCancellationResult) {
        guard let current = initialTemplate else { return }
        let now = Date()
        let banks = current.piggyBanks.map { bank -> PiggyBank in
            guard bank.id == result.piggyBankId else { return bank }
            var updated = bank
            updated.balance = result.balanceAfter
            updated.updatedAt = now
            return updated
        }
        let requests = current.requests.map { request -> RequestItem in
            guard request.id == result.requestId else { return request }
            var updated = request
            updated.status = result.requestStatus
            updated.completionCount = result.completionCount
            updated.updatedAt = now
            return updated
        }
        initialTemplate = InitialTemplateResult(
            group: current.group,
            piggyBanks: banks,
            requests: requests,
            rewards: current.rewards,
            invite: current.invite
        )
        records.removeAll { $0.id == result.recordId }
    }

    func advanceOnboarding() {
        if onboardingPage < 2 {
            onboardingPage += 1
        } else {
            phase = .authentication
        }
    }

    func reset() {
        stopObservingInviteCompletion()
        onboardingPage = 0
        displayName = ""
        selectedEmoji = nil
        selectedTab = 0
        errorMessage = nil
        authenticatedUser = nil
        profile = nil
        initialTemplate = nil
        partnerProfile = nil
        records = []
        tickets = []
        issuedTicket = nil
        activeCharin = nil
        pendingCharinUndo = nil
        pendingInvite = nil
        persistPendingInvite()
        passwordResetEmailSent = false
        phase = .authentication
    }
}
