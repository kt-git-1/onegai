import SwiftUI

enum AppPhase: Equatable {
    case onboarding
    case authentication
    case emailRegistration
    case profile
    case template
    case invite
    case inviteWaiting
    case main
}

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .onboarding
    @Published var onboardingPage = 0
    @Published var displayName = ""
    @Published var selectedEmoji: String?
    @Published var selectedTab = 0
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var authenticatedUser: AuthUser?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var initialTemplate: InitialTemplateResult?

    private let repository: any AppRepository

    init(repository: (any AppRepository)? = nil) {
        if let repository {
            self.repository = repository
        } else if ProcessInfo.processInfo.arguments.contains("-useFirebase")
                    || ProcessInfo.processInfo.arguments.contains("-useFirebaseEmulator") {
            self.repository = FirebaseAppRepository()
        } else {
            self.repository = LocalAppRepository()
        }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-previewPhase"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "authentication": phase = .authentication
            case "profile": phase = .profile
            case "inviteWaiting": phase = .inviteWaiting
            case "main": phase = .main
            default: break
            }
        }
        #endif
    }

    var inviteCode: String { initialTemplate?.invite.code ?? "準備中" }

    func signIn(with provider: AuthenticationProvider) async {
        await perform {
            authenticatedUser = try await repository.signIn(with: provider)
            phase = .profile
        }
    }

    func register(email: String, password: String) async {
        await perform {
            authenticatedUser = try await repository.register(email: email, password: password)
            phase = .profile
        }
    }

    func saveProfile() async {
        await perform {
            profile = try await repository.saveProfile(displayName: displayName, iconEmoji: selectedEmoji)
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
            phase = .main
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

    func clearError() {
        errorMessage = nil
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            try await operation()
        } catch is CancellationError {
            errorMessage = nil
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
        }
    }

    func advanceOnboarding() {
        if onboardingPage < 2 {
            onboardingPage += 1
        } else {
            phase = .authentication
        }
    }

    func reset() {
        onboardingPage = 0
        displayName = ""
        selectedEmoji = nil
        selectedTab = 0
        errorMessage = nil
        authenticatedUser = nil
        profile = nil
        initialTemplate = nil
        phase = .authentication
    }
}
