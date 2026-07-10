import SwiftUI
import UIKit

private struct InviteShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: ["おねがいチャリンに招待しました", url],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in completion(completed) }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CopyToast: View {
    var body: some View {
        Label("招待リンクをコピーしました", systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(Color.appText)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 20)
    }
}

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
            SetupHeader(title: "メールで登録", detail: nil) {
                appState.clearError()
                appState.phase = .authentication
            }

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

            Button("すでにアカウントをお持ちの方はログイン") {
                appState.clearError()
                appState.phase = .emailLogin
            }
            .font(.system(size: 14))
            .foregroundStyle(Color.appSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)

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

struct EmailLoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""

    private var valid: Bool {
        email.contains("@") && password.count >= 8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SetupHeader(title: "ログイン", detail: nil) {
                appState.clearError()
                appState.phase = .authentication
            }

            VStack(spacing: 14) {
                TextField("メールアドレス", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("パスワード", text: $password)
                    .textContentType(.password)
            }
            .textFieldStyle(AppTextFieldStyle())

            Button("パスワードをお忘れの方") {
                Task { await appState.sendPasswordReset(email: email) }
            }
            .font(.system(size: 14))
            .foregroundStyle(Color.appSecondary)
            .frame(minHeight: 44)
            .disabled(!email.contains("@") || appState.isProcessing)

            if appState.passwordResetEmailSent {
                Text("パスワード再設定メールを送信しました。")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appSuccess)
                    .accessibilityIdentifier("password-reset-success")
            }

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appError)
                    .accessibilityIdentifier("email-login-error")
            }

            Spacer()

            VStack(spacing: 10) {
                Button(appState.isProcessing ? "ログイン中…" : "ログイン") {
                    Task { await appState.signIn(email: email, password: password) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!valid || appState.isProcessing)

                Button("アカウントをお持ちでない方は登録") {
                    appState.clearError()
                    appState.phase = .emailRegistration
                }
                .font(.system(size: 14))
                .foregroundStyle(Color.appSecondary)
                .frame(minHeight: 44)
            }
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

struct InviteCodeEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var code = ""

    private var normalizedCode: String {
        let compact = code.uppercased().filter { $0.isLetter || $0.isNumber }
        guard compact.count > 4 else { return compact }
        return "\(compact.prefix(4))-\(compact.dropFirst(4).prefix(4))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SetupHeader(title: "招待コードを入力", detail: "相手から届いた8文字のコードを入力してください。") {
                appState.clearError()
                appState.phase = .authentication
            }

            TextField("ABCD-1234", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .textFieldStyle(AppTextFieldStyle())
                .onChange(of: code) { _, _ in
                    if code != normalizedCode { code = normalizedCode }
                }

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appError)
                    .accessibilityIdentifier("invite-code-error")
            }

            Spacer()

            Button(appState.isProcessing ? "確認中…" : "招待を確認") {
                Task { await appState.resolveInvite(code: normalizedCode) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(normalizedCode.count != 9 || appState.isProcessing)
        }
        .padding(16)
        .appScreen()
    }
}

struct InviteAcceptanceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            ZStack {
                Circle().fill(Color.appPrimarySoft)
                if let emoji = appState.pendingInvite?.inviterEmoji {
                    Text(emoji).font(.system(size: 48))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.appSecondary)
                }
            }
            .frame(width: 104, height: 104)

            Text("おねがいチャリンに\n招待されました")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Text("\(appState.pendingInvite?.inviterName ?? "相手")さんからの招待")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 12)

            Text("参加すると、ふたりの貯金箱と\nごほうび券を一緒に使えます。")
                .font(.system(size: 14))
                .foregroundStyle(Color.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appError)
                    .padding(.top, 16)
                    .accessibilityIdentifier("invite-acceptance-error")
            }

            Spacer()

            VStack(spacing: 10) {
                Button(appState.isProcessing ? "参加処理中…" : "参加する") {
                    Task { await appState.beginInviteAcceptance() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(appState.isProcessing)

                if appState.authenticatedUser == nil {
                    Text("参加には登録またはログインが必要です。")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appSecondary)
                }

                Button("この招待を閉じる") { appState.cancelPendingInvite() }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appSecondary)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .appScreen()
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
    @State private var shareItem: InviteShareItem?
    @State private var showsCopyToast = false

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
                Button {
                    if let inviteURL = appState.inviteURL {
                        shareItem = InviteShareItem(url: inviteURL)
                    }
                } label: {
                    Label("LINEで招待する", systemImage: "paperplane.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    if let inviteURL = appState.inviteURL {
                        UIPasteboard.general.string = inviteURL.absoluteString
                        showsCopyToast = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(900))
                            appState.phase = .inviteWaiting
                        }
                    }
                } label: {
                    Label("招待リンクをコピー", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(16)
        .appScreen()
        .overlay(alignment: .bottom) {
            if showsCopyToast { CopyToast().transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .sheet(item: $shareItem) { item in
            ActivityShareView(url: item.url) { completed in
                shareItem = nil
                if completed { appState.phase = .inviteWaiting }
            }
        }
    }
}

struct InviteWaitingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var shareItem: InviteShareItem?
    @State private var showsCopyToast = false

    var body: some View {
        VStack(spacing: 0) {
            MascotView(size: .authentication)
                .padding(.top, 20)

            Text("相手の参加を待っています")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 14)
            Text("相手が参加すると、\nふたりの貯金箱を始められます。")
                .font(.system(size: 14))
                .foregroundStyle(Color.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text("招待コード")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appSecondary)
                Text(appState.inviteCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 20)

            if appState.initialTemplate?.invite.isExpired == true {
                Text("この招待は期限切れです")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appError)
                    .padding(.top, 10)
            } else if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appError)
                    .padding(.top, 10)
            }

            Spacer()

            VStack(spacing: 8) {
                Button {
                    if let inviteURL = appState.inviteURL { shareItem = InviteShareItem(url: inviteURL) }
                } label: {
                    Label("LINEで再送する", systemImage: "paperplane.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    if let inviteURL = appState.inviteURL {
                        UIPasteboard.general.string = inviteURL.absoluteString
                        withAnimation { showsCopyToast = true }
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation { showsCopyToast = false }
                        }
                    }
                } label: {
                    Label("招待リンクをコピー", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())

                if appState.initialTemplate?.invite.isExpired == true {
                    Button(appState.isProcessing ? "再発行中…" : "新しい招待を発行する") {
                        Task { await appState.reissueInvite() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appHeart)
                    .frame(minHeight: 44)
                    .disabled(appState.isProcessing)
                }

                #if DEBUG
                Button("プレビューでは参加完了にする") {
                    Task { await appState.completeInviteForPreview() }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.appSecondary)
                .frame(minHeight: 36)
                #endif

                Button("ログアウト") { Task { await appState.signOut() } }
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appSecondary)
                    .frame(minHeight: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .appScreen()
        .overlay(alignment: .bottom) {
            if showsCopyToast { CopyToast().transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .sheet(item: $shareItem) { item in
            ActivityShareView(url: item.url) { _ in shareItem = nil }
        }
        .onAppear { appState.startObservingInviteCompletion() }
        .onDisappear { appState.stopObservingInviteCompletion() }
    }
}
