import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .onboarding:
                OnboardingView()
            case .authentication:
                AuthenticationView()
            case .emailRegistration:
                EmailRegistrationView()
            case .emailLogin:
                EmailLoginView()
            case .inviteCodeEntry:
                InviteCodeEntryView()
            case .inviteAcceptance:
                InviteAcceptanceView()
            case .profile:
                ProfileView()
            case .template:
                TemplateView()
            case .invite:
                InviteView()
            case .inviteWaiting:
                InviteWaitingView()
            case .charinCelebration:
                CharinCelebrationView()
            case .main:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.phase)
    }
}
