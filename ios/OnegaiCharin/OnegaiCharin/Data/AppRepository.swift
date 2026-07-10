import Foundation

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
        case .providerNotConfigured: "このログイン方法は現在設定中です。"
        case .invalidBackendResponse: "サーバーから正しい応答を取得できませんでした。"
        }
    }
}

@MainActor
protocol AppRepository {
    func signIn(with provider: AuthenticationProvider) async throws -> AuthUser
    func register(email: String, password: String) async throws -> AuthUser
    func saveProfile(displayName: String, iconEmoji: String?) async throws -> UserProfile
    func createInitialTemplate() async throws -> InitialTemplateResult
    func reissueInvite() async throws -> Invite
    func completeInviteForPreview() async throws
    func signOut() async throws
}
