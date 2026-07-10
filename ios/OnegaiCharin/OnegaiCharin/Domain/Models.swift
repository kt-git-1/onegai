import Foundation

struct AuthUser: Equatable, Sendable {
    let id: String
    let email: String?
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

struct InitialTemplateResult: Equatable, Sendable {
    let group: CoupleGroup
    let piggyBanks: [PiggyBank]
    let requests: [RequestItem]
    let rewards: [Reward]
    let invite: Invite
}
