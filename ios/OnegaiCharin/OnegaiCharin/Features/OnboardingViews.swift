import SwiftUI

private struct OnboardingPage {
    let title: String
    let detail: String
    let button: String
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    private let pages = [
        OnboardingPage(title: "お願いを叶えたら、\nちゃりんしよう。", detail: "マッサージ、皿洗い、買い出し。\nふたりの毎日の“してくれて嬉しい”を\nコインにできます。", button: "次へ"),
        OnboardingPage(title: "やさしさが、\nちゃりんと貯まる。", detail: "お願いをちゃりんすると、\n貯金箱にコインが入ります。", button: "次へ"),
        OnboardingPage(title: "貯まったコインで、\nごほうび券を交換。", detail: "スタバ、映画、焼肉デート。\nふたりで決めたごほうびを\n楽しく使えます。", button: "はじめる")
    ]

    var body: some View {
        let page = pages[appState.onboardingPage]
        VStack(spacing: 0) {
            Text("\(appState.onboardingPage + 1) / 3")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.appPrimarySoft)
                MascotView(size: .onboarding)
            }
            .frame(height: 222)
            .padding(.horizontal, 36)
            .padding(.top, 28)

            VStack(spacing: 24) {
                Text(page.title)
                    .font(.system(size: 27, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                Text(page.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)
            }
            .padding(.top, 46)

            Spacer()

            Button(page.button) { appState.advanceOnboarding() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .appScreen()
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 62)
            MascotView(size: .authentication)
                .padding(.bottom, 26)
            Text("おねがいチャリン")
                .font(.system(size: 24, weight: .bold))
            Text("やさしさが、ちゃりんと貯まる。")
                .font(.system(size: 14))
                .foregroundStyle(Color.appSecondary)
                .padding(.top, 8)

            if let invite = appState.pendingInvite {
                Text("\(invite.inviterName)さんの招待に参加します")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appHeart)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Color.appPrimarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 18)
            }

            Spacer()

            VStack(spacing: 10) {
                Button { Task { await appState.signIn(with: .apple) } } label: {
                    Label("Appleで続ける", systemImage: "apple.logo")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(appState.isProcessing)

                Button { Task { await appState.signIn(with: .google) } } label: {
                    Label("Googleで続ける", systemImage: "globe")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(appState.isProcessing)

                Button("メールで登録") { appState.phase = .emailRegistration }
                    .buttonStyle(PrimaryButtonStyle())

                Button("すでにアカウントをお持ちの方はログイン") {
                    appState.clearError()
                    appState.phase = .emailLogin
                }
                .font(.system(size: 14))
                .foregroundStyle(Color.appSecondary)
                .frame(minHeight: 44)

                Button("招待コードを入力") {
                    appState.clearError()
                    appState.phase = .inviteCodeEntry
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appHeart)
                .frame(minHeight: 44)

                Text("利用規約 ・ プライバシーポリシー")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appSecondary)
                    .padding(.top, 4)

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appError)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
        .appScreen()
    }
}
