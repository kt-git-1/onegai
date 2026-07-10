import SwiftUI

private struct SetupHeader: View {
    let title: String
    let detail: String?
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                Text(title)
                    .font(.system(size: 24, weight: .bold))
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appSecondary)
                    .padding(.leading, 48)
            }
        }
    }
}

struct EmailRegistrationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""

    private var valid: Bool {
        email.contains("@") && password.count >= 8 && password == confirmation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SetupHeader(title: "メールで登録", detail: nil) { appState.phase = .authentication }

            VStack(spacing: 14) {
                TextField("メールアドレス", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("パスワード（8文字以上）", text: $password)
                    .textContentType(.newPassword)
                SecureField("パスワード確認", text: $confirmation)
                    .textContentType(.newPassword)
            }
            .textFieldStyle(AppTextFieldStyle())

            Text("登録すると、利用規約とプライバシーポリシーに同意したことになります。")
                .font(.system(size: 12))
                .foregroundStyle(Color.appSecondary)

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appError)
                    .accessibilityIdentifier("email-registration-error")
            }

            Spacer()

            Button(appState.isProcessing ? "登録中…" : "登録する") {
                Task { await appState.register(email: email, password: password) }
            }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!valid || appState.isProcessing)
        }
        .padding(16)
        .appScreen()
    }
}

private struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    private let emojis = ["😊", "🌷", "☕️", "🌙"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SetupHeader(title: "プロフィールを設定しよう", detail: "相手に表示される名前とアイコンです。") {
                appState.phase = .authentication
            }

            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.appSurface)
                    Circle().stroke(Color.appBorder)
                    if let emoji = appState.selectedEmoji {
                        Text(emoji).font(.system(size: 46))
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(Color.appDisabled)
                    }
                }
                .frame(width: 104, height: 104)
                Text("アイコンはあとからでも設定できます")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appSecondary)
                HStack(spacing: 8) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(emoji) { appState.selectedEmoji = emoji }
                            .font(.system(size: 22))
                            .frame(width: 44, height: 44)
                            .background(appState.selectedEmoji == emoji ? Color.appPrimarySoft : Color.appSurface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(appState.selectedEmoji == emoji ? Color.appPrimary : Color.appBorder, lineWidth: appState.selectedEmoji == emoji ? 2 : 1))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 7) {
                Text("名前").font(.system(size: 13, weight: .semibold))
                TextField("例：花男", text: $appState.displayName)
                    .textFieldStyle(AppTextFieldStyle())
            }

            Spacer()

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appError)
                    .accessibilityIdentifier("profile-save-error")
            }

            Button(appState.isProcessing ? "保存中…" : "保存して次へ") {
                Task { await appState.saveProfile() }
            }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(appState.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isProcessing)
        }
        .padding(16)
        .appScreen()
    }
}

struct TemplateView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SetupHeader(title: "最初のお願いを用意しよう", detail: "よく使うお願いを、あとから自由に変更できます。") {
                appState.phase = .profile
            }

            VStack(alignment: .leading, spacing: 18) {
                templateSection("自分の貯金箱", rows: ["💆 マッサージ10分  +100コイン", "🧺 皿洗い  +50コイン"])
                Divider()
                templateSection("ふたりの貯金箱", rows: ["🧹 部屋を片付ける  +200コイン", "🥢 デートの予定を決める  +300コイン"])
            }
            .padding(18)
            .background(Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)

            Spacer()

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appError)
                    .accessibilityIdentifier("template-create-error")
            }

            Button(appState.isProcessing ? "作成中…" : "この内容ではじめる") {
                Task { await appState.applyInitialTemplate() }
            }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(appState.isProcessing)
        }
        .padding(16)
        .appScreen()
    }

    private func templateSection(_ title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.appHeart)
            ForEach(rows, id: \.self) { Text($0).font(.system(size: 14)) }
        }
    }
}

struct InviteView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("相手を招待しよう")
                .font(.system(size: 24, weight: .bold))
            Text("おねがいチャリンは、ふたりで使うアプリです。招待リンクを相手に送ってください。")
                .font(.system(size: 14))
                .foregroundStyle(Color.appSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("招待コード").font(.system(size: 12)).foregroundStyle(Color.appSecondary)
                Text(appState.inviteCode).font(.system(size: 26, weight: .bold)).monospaced()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            VStack(spacing: 10) {
                Button { appState.phase = .inviteWaiting } label: {
                    Label("LINEで招待する", systemImage: "paperplane.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                Button { appState.phase = .inviteWaiting } label: {
                    Label("招待リンクをコピー", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(16)
        .appScreen()
    }
}

struct InviteWaitingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color.appPrimarySoft)
                MascotView(size: .onboarding)
            }
            .frame(height: 222)
            .padding(.horizontal, 36)
            .padding(.top, 28)

            Text("相手の参加を待っています")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 8)
            Text("相手が参加すると、\nふたりの貯金箱を始められます。")
                .font(.system(size: 14))
                .foregroundStyle(Color.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer()

            Button(appState.isProcessing ? "参加処理中…" : "プレビューでは参加完了にする") {
                Task { await appState.completeInviteForPreview() }
            }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(appState.isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .appScreen()
    }
}
