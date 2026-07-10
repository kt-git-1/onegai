import Foundation

@MainActor
final class AppObservation {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

    deinit {
        cancellation?()
    }
}

enum AuthenticationProvider: Equatable, Sendable {
    case apple
    case google
}

enum AppRepositoryError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case unauthenticated
    case profileMissing
    case templateAlreadyCreated
    case inviteUnavailable
    case invalidInviteCode
    case inviteExpired
    case inviteAlreadyUsed
    case groupFull
    case alreadyInGroup
    case invalidRequest
    case requestNotOwned
    case providerNotConfigured
    case invalidBackendResponse

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "メールアドレスを確認してください。"
        case .weakPassword: "パスワードは8文字以上で入力してください。"
        case .unauthenticated: "ログインが必要です。"
        case .profileMissing: "プロフィールを先に設定してください。"
        case .templateAlreadyCreated: "初期設定はすでに作成されています。"
        case .inviteUnavailable: "有効な招待がありません。"
        case .invalidInviteCode: "招待コードを確認してください。"
        case .inviteExpired: "この招待は期限切れです。"
        case .inviteAlreadyUsed: "この招待はすでに使用されています。"
        case .groupFull: "この招待は使用できません。"
        case .alreadyInGroup: "すでに別の相手と連携しています。"
        case .invalidRequest: "お願いの内容を確認してください。"
        case .requestNotOwned: "このお願いを編集できるのは作成者だけです。"
        case .providerNotConfigured: "このログイン方法は現在設定中です。"
        case .invalidBackendResponse: "サーバーから正しい応答を取得できませんでした。"
        }
    }
}

@MainActor
protocol AppRepository {
    func signIn(with provider: AuthenticationProvider) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func register(email: String, password: String) async throws -> AuthUser
    func sendPasswordReset(email: String) async throws
    func loadSession() async throws -> AppSession
    func saveProfile(displayName: String, iconEmoji: String?) async throws -> UserProfile
    func createInitialTemplate() async throws -> InitialTemplateResult
    func reissueInvite() async throws -> Invite
    func resolveInvite(identifier: String) async throws -> InvitePreview
    func acceptInvite(id: String) async throws
    func createRequest(_ draft: RequestDraft) async throws -> RequestItem
    func updateRequest(_ request: RequestItem, draft: RequestDraft) async throws -> RequestItem
    func hideRequest(_ request: RequestItem) async throws -> RequestItem
    func charinRequest(groupId: String, requestId: String) async throws -> CharinResult
    func cancelCharin(recordId: String) async throws -> CharinCancellationResult
    func observeGroupMemberCount(
        groupId: String,
        onChange: @escaping (Result<Int, Error>) -> Void
    ) -> AppObservation
    func completeInviteForPreview() async throws
    func signOut() async throws
}
