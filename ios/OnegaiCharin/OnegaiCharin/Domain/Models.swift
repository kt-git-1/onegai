import Foundation

struct AuthUser: Equatable, Sendable {
    let id: String
    let email: String?
}

struct AppSession: Equatable, Sendable {
    let profile: UserProfile?
    let initialTemplate: InitialTemplateResult?
    let partnerProfile: UserProfile?
    let records: [ActivityRecord]
    let tickets: [Ticket]

    init(
        profile: UserProfile?,
        initialTemplate: InitialTemplateResult?,
        partnerProfile: UserProfile? = nil,
        records: [ActivityRecord] = [],
        tickets: [Ticket] = []
    ) {
        self.profile = profile
        self.initialTemplate = initialTemplate
        self.partnerProfile = partnerProfile
        self.records = records
        self.tickets = tickets
    }
}

struct UserProfile: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var displayName: String
    var iconEmoji: String?
    var photoURL: URL?
    var email: String?
    var activeGroupId: String?
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

struct CoupleGroup: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case active, archived, deleted }

    let id: String
    var name: String
    let type: String
    var status: Status
    var memberIds: [String]
    let createdBy: String
    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
}

struct PiggyBank: Identifiable, Codable, Equatable, Sendable {
    enum OwnerType: String, Codable, Sendable { case personal, shared }
    enum Status: String, Codable, Sendable { case active, archived }

    let id: String
    let groupId: String
    let ownerType: OwnerType
    let ownerUserId: String?
    var name: String
    var balance: Int
    var targetRewardId: String?
    var status: Status
    let createdAt: Date
    var updatedAt: Date
}

struct RequestItem: Identifiable, Codable, Equatable, Sendable {
    enum RepeatType: String, Codable, Sendable { case repeatable = "repeat", oneTime }
    enum Status: String, Codable, Sendable { case active, hidden, deleted }

    let id: String
    let groupId: String
    let createdBy: String
    var title: String
    var iconEmoji: String
    var coinAmount: Int
    var piggyBankType: PiggyBank.OwnerType
    var repeatType: RepeatType
    var status: Status
    var completionCount: Int
    var lastCompletedAt: Date?
    let createdAt: Date
    var updatedAt: Date
}

struct RequestDraft: Equatable, Sendable {
    var title: String
    var iconEmoji: String
    var coinAmount: Int
    var piggyBankType: PiggyBank.OwnerType
    var repeatType: RequestItem.RepeatType
}

struct Reward: Identifiable, Codable, Equatable, Sendable {
    enum ExpiryType: String, Codable, Sendable { case none, days, date }
    enum Status: String, Codable, Sendable { case active, hidden, deleted }

    let id: String
    let groupId: String
    let createdBy: String
    var title: String
    var iconEmoji: String
    var requiredCoins: Int
    var piggyBankType: PiggyBank.OwnerType
    var isTarget: Bool
    var expiresInType: ExpiryType
    var expiresInDays: Int?
    var expiresAt: Date?
    var status: Status
    let createdAt: Date
    var updatedAt: Date
}

struct RewardDraft: Equatable, Sendable {
    var title: String
    var iconEmoji: String
    var requiredCoins: Int
    var piggyBankType: PiggyBank.OwnerType
    var expiresInType: Reward.ExpiryType
    var expiresInDays: Int?
    var expiresAt: Date?
}

struct Ticket: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case unused, used, expired, canceled }

    let id: String
    let groupId: String
    let rewardId: String
    let issuedBy: String
    let ownerUserId: String?
    let piggyBankId: String
    let ticketType: PiggyBank.OwnerType
    let title: String
    let iconEmoji: String
    let spentCoins: Int
    var status: Status
    let issuedAt: Date
    var usedAt: Date?
    var usedBy: String?
    let expiresAt: Date?
    let createdAt: Date
    var updatedAt: Date
}

struct RewardExchangeResult: Equatable, Sendable {
    let ticket: Ticket
    let record: ActivityRecord
}

struct TicketUseResult: Equatable, Sendable {
    let ticket: Ticket
    let record: ActivityRecord
}

struct ActivityRecord: Identifiable, Codable, Equatable, Sendable {
    enum RecordType: String, Codable, Sendable { case charin, rewardExchange, ticketUsed }
    enum Status: String, Codable, Sendable { case active, canceled }

    let id: String
    let groupId: String
    let userId: String
    let type: RecordType
    let targetType: String
    let targetId: String
    let title: String
    let iconEmoji: String
    let coinDelta: Int
    let piggyBankId: String
    let piggyBankName: String
    let balanceBefore: Int
    let balanceAfter: Int
    let status: Status
    let createdAt: Date
    let canceledAt: Date?
}

struct TargetRewardProgress: Equatable, Sendable {
    let id: String
    let title: String
    let iconEmoji: String
    let remainingCoins: Int
    let isExchangeable: Bool
    let becameExchangeable: Bool
}

struct CharinResult: Equatable, Sendable {
    let record: ActivityRecord
    let requestId: String
    let requestStatus: RequestItem.Status
    let completionCount: Int
    let targetReward: TargetRewardProgress?
}

struct CharinCancellationResult: Equatable, Sendable {
    let recordId: String
    let requestId: String
    let piggyBankId: String
    let balanceAfter: Int
    let requestStatus: RequestItem.Status
    let completionCount: Int
}

struct PendingCharinUndo: Equatable, Sendable {
    let recordId: String
    let expiresAt: Date
}

struct Invite: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case active, used, expired, revoked }

    let id: String
    let groupId: String
    let code: String
    let createdBy: String
    var status: Status
    let expiresAt: Date
    let createdAt: Date
    var usedAt: Date?
    var usedBy: String?

    var isExpired: Bool { status == .expired || expiresAt <= Date() }
}

struct InvitePreview: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let code: String
    let inviterName: String
    let inviterEmoji: String?
    let expiresAt: Date
}

struct InitialTemplateResult: Equatable, Sendable {
    let group: CoupleGroup
    let piggyBanks: [PiggyBank]
    let requests: [RequestItem]
    let rewards: [Reward]
    let invite: Invite
}
