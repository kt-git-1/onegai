import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(0)
            NavigationStack { RequestsView() }
                .tabItem { Label("おねがい", systemImage: "heart.text.square") }
                .tag(1)
            NavigationStack { RewardsView() }
                .tabItem { Label("ごほうび", systemImage: "ticket.fill") }
                .tag(2)
            NavigationStack { RecordsView() }
                .tabItem { Label("きろく", systemImage: "list.bullet.rectangle") }
                .tag(3)
        }
        .tint(Color.appHeart)
        .overlay(alignment: .bottom) {
            if let pending = appState.pendingCharinUndo {
                CharinUndoToast(pending: pending)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 82)
            } else if let toast = appState.toast {
                AppToastView(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 82)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: appState.toast)
        .task {
            appState.startObservingRecords()
            appState.startObservingReactions()
        }
    }
}

private struct HomeToolbar: View {
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.appSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appBorder))
            }
            .accessibilityLabel("設定")
        }
        .frame(height: 48)
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedBankIndex: Int
    @State private var charinRequest: RequestItem?
    @State private var exchangeSelection: RewardExchangeSelection?
    @State private var showsSettings = false

    init() {
        #if DEBUG
        _selectedBankIndex = State(initialValue: ProcessInfo.processInfo.arguments.contains("-previewSharedBank") ? 1 : 0)
        #else
        _selectedBankIndex = State(initialValue: 0)
        #endif
    }

    private var banks: [PiggyBank] {
        guard let template = appState.initialTemplate else { return [] }
        let personal = template.piggyBanks.first {
            $0.ownerType == .personal && $0.ownerUserId == appState.authenticatedUser?.id && $0.status == .active
        }
        let shared = template.piggyBanks.first { $0.ownerType == .shared && $0.status == .active }
        return [personal, shared].compactMap { $0 }
    }

    private var selectedBank: PiggyBank? {
        banks.indices.contains(selectedBankIndex) ? banks[selectedBankIndex] : banks.first
    }

    private var selectedRequests: [RequestItem] {
        guard let selectedBank else { return [] }
        return (appState.initialTemplate?.requests ?? [])
            .filter { $0.status == .active && $0.piggyBankType == selectedBank.ownerType }
            .sorted {
                if $0.completionCount == $1.completionCount { return $0.updatedAt > $1.updatedAt }
                return $0.completionCount > $1.completionCount
            }
            .prefix(3)
            .map { $0 }
    }

    private var selectedRecords: [ActivityRecord] {
        guard let selectedBank else { return [] }
        return appState.records
            .filter { $0.status == .active && $0.piggyBankId == selectedBank.id }
            .prefix(3)
            .map { $0 }
    }

    private var isShared: Bool { selectedBank?.ownerType == .shared }
    private var bankCardSize: CGFloat { min(UIScreen.main.bounds.width - 32, 420) }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                HomeToolbar { showsSettings = true }

                if banks.isEmpty {
                    ContentUnavailableView(
                        "貯金箱を読み込めませんでした",
                        systemImage: "tray",
                        description: Text("画面を開き直して、もう一度お試しください。")
                    )
                    .frame(minHeight: 360)
                } else {
                    GeometryReader { proxy in
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 12) {
                                ForEach(Array(banks.enumerated()), id: \.offset) { index, bank in
                                    BankCard(
                                        bank: bank,
                                        targetReward: appState.nearestReward(for: bank),
                                        onSelectTarget: { appState.presentRewardCreation() },
                                        onExchange: { reward in
                                            exchangeSelection = RewardExchangeSelection(reward: reward, bank: bank)
                                        }
                                    )
                                    .frame(width: proxy.size.width, height: bankCardSize)
                                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                        content
                                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                            .opacity(phase.isIdentity ? 1 : 0.72)
                                            .rotation3DEffect(
                                                .degrees(phase.value * -3),
                                                axis: (x: 0, y: 1, z: 0),
                                                perspective: 0.35
                                            )
                                    }
                                    .id(index)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .scrollPosition(id: Binding<Int?>(
                            get: { selectedBankIndex },
                            set: { newValue in
                                if let newValue { selectedBankIndex = newValue }
                            }
                        ))
                        .sensoryFeedback(.selection, trigger: selectedBankIndex)
                    }
                    .frame(height: bankCardSize)

                    if banks.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(banks.indices, id: \.self) { index in
                                Capsule()
                                    .fill(index == selectedBankIndex ? Color.appHeart : Color.appBorder)
                                    .frame(width: index == selectedBankIndex ? 18 : 6, height: 6)
                            }
                        }
                        .frame(height: 10)
                        .animation(.easeInOut(duration: 0.2), value: selectedBankIndex)
                        .accessibilityHidden(true)
                    }

                    HomeSection(title: isShared ? "ふたりのおねがい" : "よく使うおねがい") {
                        if selectedRequests.isEmpty {
                            HomeEmptyRow(text: "まだおねがいがありません")
                        } else {
                            ForEach(Array(selectedRequests.enumerated()), id: \.element.id) { index, request in
                                RequestRow(request: request) { charinRequest = request }
                                if index < selectedRequests.count - 1 { Divider() }
                            }
                        }
                    }

                    HomeSection(title: isShared ? "最近のふたりのきろく" : "最近のきろく") {
                        if selectedRecords.isEmpty {
                            HomeEmptyRow(text: "まだきろくがありません")
                        } else {
                            ForEach(Array(selectedRecords.enumerated()), id: \.element.id) { index, record in
                                RecordRow(record: record)
                                if index < selectedRecords.count - 1 { Divider() }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $charinRequest) { request in
            CharinConfirmationSheet(request: request)
                .presentationDetents([.height(430)])
        }
        .sheet(item: $exchangeSelection) { selection in
            RewardExchangeConfirmationView(reward: selection.reward, bank: selection.bank)
                .presentationDetents([.height(430)])
        }
        .fullScreenCover(item: $appState.issuedTicket) { ticket in
            TicketIssuedView(
                ticket: ticket,
                onViewTickets: {
                    appState.presentUsableTickets()
                    appState.issuedTicket = nil
                },
                onClose: { appState.issuedTicket = nil }
            )
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showsCopied = false
    @State private var showsSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(emoji: appState.profile?.iconEmoji, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(appState.profile?.displayName ?? "プロフィール")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("名前とアイコンを編集")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.appSecondary)
                            }
                        }
                    }
                }

                Section("ふたり") {
                    NavigationLink {
                        CoupleNameSettingsView()
                    } label: {
                        SettingsInfoRow(
                            title: "カップル名",
                            value: appState.initialTemplate?.group.name ?? "未設定",
                            systemImage: "heart.fill"
                        )
                    }
                    NavigationLink {
                        PartnerInfoSettingsView()
                    } label: {
                        SettingsInfoRow(
                            title: "相手",
                            value: appState.partnerProfile?.displayName ?? "未連携",
                            systemImage: "person.2.fill"
                        )
                    }
                    SettingsInfoRow(
                        title: "招待コード",
                        value: appState.inviteCode,
                        systemImage: "number"
                    )
	                    Button {
	                        if let inviteURL = appState.inviteURL {
	                            UIPasteboard.general.string = inviteURL.absoluteString
	                            appState.trackInviteSent(channel: "settings_copy")
	                            withAnimation { showsCopied = true }
	                            Task {
                                try? await Task.sleep(for: .seconds(1.6))
                                withAnimation { showsCopied = false }
                            }
                        }
                    } label: {
                        SettingsActionRow(title: "招待リンクをコピー", systemImage: "doc.on.doc")
                    }
                    .disabled(appState.inviteURL == nil)

	                    Button {
	                        Task {
	                            if await appState.reissueInvite() {
	                                appState.trackInviteSent(channel: "settings_reissue")
	                            }
	                        }
	                    } label: {
                        SettingsActionRow(title: appState.isProcessing ? "再発行中…" : "招待リンクを再発行", systemImage: "arrow.clockwise")
                    }
                    .disabled(appState.isProcessing)
                }

                Section("アプリ設定") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsActionRow(title: "通知設定", systemImage: "bell.fill")
                    }
                    NavigationLink {
                        AppPreferenceSettingsView()
                    } label: {
                        SettingsActionRow(title: "音とテーマ", systemImage: "slider.horizontal.3")
                    }
                }

                Section("サポート") {
                    Button {
                        if let url = URL(string: "https://onegai-charin-dev.web.app/terms") {
                            openURL(url)
                        }
                    } label: {
                        SettingsActionRow(title: "利用規約", systemImage: "doc.text")
                    }
                    Button {
                        if let url = URL(string: "https://onegai-charin-dev.web.app/privacy") {
                            openURL(url)
                        }
                    } label: {
                        SettingsActionRow(title: "プライバシーポリシー", systemImage: "hand.raised")
                    }
                    Button {
                        if let url = URL(string: "mailto:support@onegai-charin-dev.web.app?subject=%E3%81%8A%E3%81%AD%E3%81%8C%E3%81%84%E3%83%81%E3%83%A3%E3%83%AA%E3%83%B3%E3%81%AE%E5%95%8F%E3%81%84%E5%90%88%E3%82%8F%E3%81%9B") {
                            openURL(url)
                        }
                    } label: {
                        SettingsActionRow(title: "問い合わせ", systemImage: "envelope")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showsSignOutConfirmation = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(appState.isProcessing)
                }
            }
            .modernFormBackground()
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.appHeart)
                }
            }
            .overlay(alignment: .bottom) {
                if showsCopied {
                    Label("招待リンクをコピーしました", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(Color.appToastBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .confirmationDialog("ログアウトしますか？", isPresented: $showsSignOutConfirmation, titleVisibility: .visible) {
                Button("ログアウト", role: .destructive) {
                    Task {
                        await appState.signOut()
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
    }
}

private struct ProfileSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var selectedEmoji: String?
    private let emojis = ["😊", "🌷", "☕️", "🌙", "🍰", "🫶"]

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.isProcessing
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    AvatarView(emoji: selectedEmoji, size: 96)
                    Text("アイコン")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appSecondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        Button {
                            selectedEmoji = nil
                        } label: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .background(selectedEmoji == nil ? Color.appPrimarySoft : Color.appSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(selectedEmoji == nil ? Color.appPrimary : Color.appBorder))

                        ForEach(emojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 22))
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .background(selectedEmoji == emoji ? Color.appPrimarySoft : Color.appSurface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(selectedEmoji == emoji ? Color.appPrimary : Color.appBorder))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("名前") {
                TextField("名前", text: $displayName)
                    .textInputAutocapitalization(.never)
            }

            if let error = appState.errorMessage {
                Section {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appError)
                }
            }
        }
        .modernFormBackground()
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(appState.isProcessing ? "保存中…" : "保存") {
                    Task {
                        let saved = await appState.updateProfile(displayName: displayName, iconEmoji: selectedEmoji)
                        if saved { dismiss() }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.appHeart)
                .disabled(!canSave)
            }
        }
        .onAppear {
            displayName = appState.profile?.displayName ?? appState.displayName
            selectedEmoji = appState.profile?.iconEmoji ?? appState.selectedEmoji
        }
    }
}

private struct CoupleNameSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""

    private var canSave: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.isProcessing
    }

    var body: some View {
        List {
            Section {
                TextField("例：花男と花子", text: $groupName)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("couple-name-field")
            } header: {
                Text("カップル名")
            } footer: {
                Text("ホームや設定で表示される、ふたりの名前です。")
            }

            if let error = appState.errorMessage {
                Section {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appError)
                }
            }
        }
        .modernFormBackground()
        .navigationTitle("カップル名")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(appState.isProcessing ? "保存中…" : "保存") {
                    Task {
                        let saved = await appState.updateCoupleName(groupName)
                        if saved { dismiss() }
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.appHeart)
                .disabled(!canSave)
            }
        }
        .onAppear {
            groupName = appState.initialTemplate?.group.name ?? ""
        }
    }
}

private struct PartnerInfoSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    AvatarView(emoji: appState.partnerProfile?.iconEmoji, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.partnerProfile?.displayName ?? "未連携")
                            .font(.system(size: 18, weight: .bold))
                        Text(appState.partnerProfile == nil ? "相手が参加すると表示されます" : "連携済み")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.appSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("ふたり") {
                SettingsInfoRow(
                    title: "カップル名",
                    value: appState.initialTemplate?.group.name ?? "未設定",
                    systemImage: "heart.fill"
                )
                SettingsInfoRow(
                    title: "メンバー",
                    value: "\(appState.initialTemplate?.group.memberIds.count ?? 1)人",
                    systemImage: "person.2"
                )
            }

            Section {
                Label("相手解除は保留中です", systemImage: "lock.fill")
                    .foregroundStyle(Color.appSecondary)
            } footer: {
                Text("誤操作の影響が大きいため、解除導線は仕様確定後に実装します。")
            }
        }
        .modernFormBackground()
        .navigationTitle("相手情報")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("rewardNotificationEnabled") private var rewardNotificationEnabled = true

    var body: some View {
        List {
            Section {
                Toggle("ごほうび券交換通知", isOn: $rewardNotificationEnabled)
            } footer: {
                Text("通知はごほうび券が交換されたときだけ送ります。ちゃりん、スタンプ、使用済みでは通知しません。")
            }

            Section {
                Button {
                    Task { await appState.requestPushNotifications() }
                } label: {
                    SettingsActionRow(
                        title: appState.notificationsEnabled ? "Push通知はオンです" : "Push通知を許可",
                        systemImage: appState.notificationsEnabled ? "bell.badge.fill" : "bell.fill"
                    )
                }
                .disabled(appState.isProcessing || appState.notificationsEnabled)
            }
        }
        .modernFormBackground()
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppPreferenceSettingsView: View {
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("themeMode") private var themeMode = "system"

    var body: some View {
        List {
            Section("音") {
                Toggle("効果音", isOn: $soundEffectsEnabled)
            }

            Section {
                Picker("表示", selection: $themeMode) {
                    Text("端末に合わせる").tag("system")
                    Text("ライト").tag("light")
                    Text("ダーク").tag("dark")
                }
                .pickerStyle(.inline)
            } header: {
                Text("テーマ")
            } footer: {
                Text("端末設定に合わせるか、ライト／ダークを固定できます。")
            }
        }
        .modernFormBackground()
        .navigationTitle("音とテーマ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AvatarView: View {
    let emoji: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.appPrimarySoft)
            Circle().stroke(Color.appBorder)
            if let emoji {
                Text(emoji).font(.system(size: size * 0.44))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Color.appDisabled)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appHeart)
                .frame(width: 26)
            Text(title)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct SettingsActionRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(Color.appText)
    }
}

private struct BankCard: View {
    let bank: PiggyBank
    let targetReward: Reward?
    let onSelectTarget: () -> Void
    let onExchange: (Reward) -> Void

    private var remainingCoins: Int {
        max((targetReward?.requiredCoins ?? 0) - bank.balance, 0)
    }

    private var progress: Double {
        guard let requiredCoins = targetReward?.requiredCoins, requiredCoins > 0 else { return 0 }
        return min(Double(bank.balance) / Double(requiredCoins), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    bank.ownerType == .shared ? "ふたり" : "自分",
                    systemImage: bank.ownerType == .shared ? "person.2.fill" : "person.fill"
                )
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.appHeart)

                Spacer()

                Text(bank.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)
                    .lineLimit(1)
            }
            .padding(.bottom, 4)

            Spacer(minLength: 2)

            Group {
                if bank.ownerType == .shared {
                    Image("DoublePiggyBank")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 178, height: 126)
                        .clipped()
                        .accessibilityLabel("ふたりの貯金箱キャラクター")
                } else {
                    Image("PiggyBank")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 126, height: 126)
                        .accessibilityLabel("おねがいチャリンの貯金箱キャラクター")
                }
            }

            Text(bank.balance.formatted())
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("コイン")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.appSecondary)
                .padding(.top, -3)

            Spacer(minLength: 10)

            rewardPanel
        }
        .padding(18)
        .background(BankCardBackground())
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .shadow(color: Color.appText.opacity(0.08), radius: 12, y: 5)
    }

    @ViewBuilder
    private var rewardPanel: some View {
        if let targetReward {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(targetReward.iconEmoji)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("次のごほうび")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.appSecondary)
                        Text(targetReward.title)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                    }
                    Spacer()
                    if remainingCoins == 0 {
                        Button(action: { onExchange(targetReward) }) {
                            Text("交換する")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.appOnPrimary)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(Color.appPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("home-exchange-reward-button")
                    } else {
                        Text("あと\(remainingCoins.formatted())")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.appHeart)
                    }
                }
                if remainingCoins > 0 {
                    ProgressView(value: progress)
                        .tint(Color.appPrimary)
                }
            }
            .padding(12)
            .background(Color.appPrimarySoft)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        } else {
            Button(action: onSelectTarget) {
                Label("ごほうび券を作る", systemImage: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct BankCardBackground: View {
    var body: some View {
        ZStack {
            Color.appSurface

            VStack {
                HStack {
                    motif("sparkles", size: 19)
                    Spacer()
                    motif("heart.fill", size: 14)
                }
                Spacer()
                HStack {
                    motif("heart.fill", size: 18)
                    Spacer()
                    motif("sparkles", size: 22)
                }
            }
            .padding(34)

            Canvas { context, size in
                let stripe = Path { path in
                    var offset: CGFloat = -size.height
                    while offset < size.width {
                        path.move(to: CGPoint(x: offset, y: size.height))
                        path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                        offset += 34
                    }
                }
                context.stroke(
                    stripe,
                    with: .color(Color.appPrimary.opacity(0.15)),
                    lineWidth: 1
                )
            }
        }
    }

    private func motif(_ systemName: String, size: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Color.appHeart.opacity(0.14))
    }
}

private struct HomeEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.appSecondary)
            .frame(maxWidth: .infinity, minHeight: 58)
    }
}

private struct RecordRow: View {
    let record: ActivityRecord

    private var dateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: record.createdAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(record.iconEmoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(Color.appPrimarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(dateText).font(.system(size: 11)).foregroundStyle(Color.appSecondary)
            }
            Spacer()
            Text(record.coinDelta > 0 ? "+\(record.coinDelta)" : "\(record.coinDelta)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(record.coinDelta >= 0 ? Color.appSuccess : Color.appError)
        }
        .padding(12)
    }
}

private struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            VStack(spacing: 0) { content }
                .background(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
    }
}

private struct RequestRow: View {
    let request: RequestItem
    let onCharin: () -> Void

    var body: some View {
        Button(action: onCharin) {
            HStack(spacing: 10) {
                Text(request.iconEmoji)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(Color.appPrimarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                    Text("+\(request.coinAmount)コイン ・ \(request.repeatType.displayName)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appSecondary)
                }
                Spacer()
                Text("ちゃりん")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appOnPrimary)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-charin-\(request.id)")
    }
}

struct RequestsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var bankType: PiggyBank.OwnerType = .personal
    @State private var expandedRequestId: String?
    @State private var editorRoute: RequestEditorRoute?
    @State private var charinRequest: RequestItem?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-previewRequestEditor") {
            _editorRoute = State(initialValue: .create(.personal))
        }
        #endif
    }

    private var requests: [RequestItem] {
        (appState.initialTemplate?.requests ?? [])
            .filter { $0.status == .active && $0.piggyBankType == bankType }
            .sorted {
                if $0.completionCount == $1.completionCount { return $0.updatedAt > $1.updatedAt }
                return $0.completionCount > $1.completionCount
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopTabBar(
                items: [
                    (PiggyBank.OwnerType.personal, "おねがい"),
                    (PiggyBank.OwnerType.shared, "ふたりのおねがい")
                ],
                selection: $bankType
            )
            .padding(.bottom, 12)
            .accessibilityIdentifier("request-bank-picker")

            if requests.isEmpty {
                ContentUnavailableView {
                    Label("まだおねがいがありません", systemImage: "heart.text.square")
                } actions: {
                    Button("おねがいを作る") { editorRoute = .create(bankType) }
                        .buttonStyle(PrimaryButtonStyle())
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("よく使う順") {
                        ForEach(requests) { request in
                            RequestListCard(
                                request: request,
                                isExpanded: expandedRequestId == request.id,
                                canEdit: request.createdBy == appState.authenticatedUser?.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        expandedRequestId = expandedRequestId == request.id ? nil : request.id
                                    }
                                },
                                onEdit: { editorRoute = .edit(request) },
                                onCharin: { charinRequest = request }
                            )
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .brandNavigationTitle("おねがい")
        .toolbar {
            Button { editorRoute = .create(bankType) } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("おねがいを追加")
            .accessibilityIdentifier("add-request-button")
        }
        .sheet(item: $editorRoute) { route in
            NavigationStack {
                switch route {
                case .create(let initialBankType):
                    RequestEditorView(request: nil, initialBankType: initialBankType)
                case .edit(let request):
                    RequestEditorView(request: request, initialBankType: request.piggyBankType)
                }
            }
        }
        .sheet(item: $charinRequest) { request in
            CharinConfirmationSheet(request: request)
                .presentationDetents([.height(430)])
        }
        .onChange(of: bankType) {
            expandedRequestId = nil
        }
    }
}

private enum RequestEditorRoute: Identifiable {
    case create(PiggyBank.OwnerType)
    case edit(RequestItem)

    var id: String {
        switch self {
        case .create(let type): "create-\(type.rawValue)"
        case .edit(let request): "edit-\(request.id)"
        }
    }
}

private struct RequestListCard: View {
    let request: RequestItem
    let isExpanded: Bool
    let canEdit: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onCharin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text(request.iconEmoji).font(.system(size: 30)).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("+\(request.coinAmount)コイン ・ \(request.repeatType.displayName)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appSecondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appSecondary)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

                Button(action: onCharin) {
                    Text("ちゃりん")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appOnPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityIdentifier("request-list-charin-\(request.id)")
            }
            .padding(12)

            if isExpanded && canEdit {
                Divider()
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appHeart)
                .accessibilityIdentifier("edit-request-\(request.id)")
            }
        }
        .background(Color.appSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.appText.opacity(0.055), radius: 7, y: 3)
        .accessibilityIdentifier("request-card-\(request.id)")
    }
}

private struct RequestEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let request: RequestItem?
    @State private var title: String
    @State private var iconEmoji: String
    @State private var coinAmount: Int
    @State private var bankType: PiggyBank.OwnerType
    @State private var repeatType: RequestItem.RepeatType
    @State private var showsHideConfirmation = false

    private let emojiOptions = ["💆", "🧽", "🧹", "🛒", "🍳", "☕️", "✨", "❤️"]
    private let coinOptions = [50, 100, 150, 200, 300, 500]

    init(request: RequestItem?, initialBankType: PiggyBank.OwnerType) {
        self.request = request
        _title = State(initialValue: request?.title ?? "")
        _iconEmoji = State(initialValue: request?.iconEmoji ?? "✨")
        _coinAmount = State(initialValue: request?.coinAmount ?? 100)
        _bankType = State(initialValue: request?.piggyBankType ?? initialBankType)
        _repeatType = State(initialValue: request?.repeatType ?? .repeatable)
    }

    private var draft: RequestDraft {
        RequestDraft(
            title: title,
            iconEmoji: iconEmoji,
            coinAmount: coinAmount,
            piggyBankType: bankType,
            repeatType: repeatType
        )
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.isProcessing
    }

    var body: some View {
        Form {
            Section("おねがい") {
                Picker("アイコン", selection: $iconEmoji) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Text(emoji).tag(emoji)
                    }
                }
                TextField("おねがいの名前", text: $title)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("request-title-field")
            }

            Section("コイン") {
                Picker("コイン", selection: $coinAmount) {
                    ForEach(coinOptions, id: \.self) { amount in
                        Text("\(amount)コイン").tag(amount)
                    }
                }
            }

            Section("貯金箱") {
                Picker("貯金箱", selection: $bankType) {
                    Text("自分").tag(PiggyBank.OwnerType.personal)
                    Text("ふたり").tag(PiggyBank.OwnerType.shared)
                }
                .pickerStyle(.segmented)
            }

            Section("タイプ") {
                Picker("タイプ", selection: $repeatType) {
                    Text("繰り返し").tag(RequestItem.RepeatType.repeatable)
                    Text("1回限り").tag(RequestItem.RepeatType.oneTime)
                }
                .pickerStyle(.segmented)
            }

            if let errorMessage = appState.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.appError)
                }
            }

            if request != nil {
                Section {
                    Button("このおねがいを非表示にする", role: .destructive) {
                        showsHideConfirmation = true
                    }
                    .disabled(appState.isProcessing)
                }
            }
        }
        .modernFormBackground()
        .brandNavigationTitle(request == nil ? "おねがいを作る" : "おねがいを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存する") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("save-request-button")
            }
        }
        .confirmationDialog(
            "このおねがいを非表示にしますか？",
            isPresented: $showsHideConfirmation,
            titleVisibility: .visible
        ) {
            Button("非表示にする", role: .destructive) { hide() }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear { appState.clearError() }
    }

    private func save() {
        Task {
            let succeeded: Bool
            if let request {
                succeeded = await appState.updateRequest(request, draft: draft)
            } else {
                succeeded = await appState.createRequest(draft)
            }
            if succeeded { dismiss() }
        }
    }

    private func hide() {
        guard let request else { return }
        Task {
            if await appState.hideRequest(request) { dismiss() }
        }
    }
}

private extension RequestItem.RepeatType {
    var displayName: String {
        switch self {
        case .repeatable: "繰り返し"
        case .oneTime: "1回限り"
        }
    }
}

struct CharinConfirmationSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let request: RequestItem

    private var bank: PiggyBank? { appState.piggyBank(for: request) }
    private var reward: Reward? { bank.flatMap(appState.nearestReward(for:)) }
    private var remainingCoins: Int? {
        guard let bank, let reward else { return nil }
        return max(reward.requiredCoins - bank.balance - request.coinAmount, 0)
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.appBorder)
                .frame(width: 38, height: 5)

            Text("このおねがいをちゃりんしますか？")
                .font(.system(size: 20, weight: .bold))

            HStack(spacing: 12) {
                Text(request.iconEmoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.title).font(.system(size: 16, weight: .semibold))
                    Text("+\(request.coinAmount)コイン")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appHeart)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 7) {
                if let bank {
                    Label("\(bank.name)に入ります", systemImage: "banknote.fill")
                }
                if let reward, let remainingCoins {
                    Text(remainingCoins == 0 ?
                         "\(reward.iconEmoji) \(reward.title)を交換できます" :
                         "あと\(remainingCoins)コインで \(reward.iconEmoji) \(reward.title)")
                        .foregroundStyle(remainingCoins == 0 ? Color.appSuccess : Color.appSecondary)
                }
            }
            .font(.system(size: 13, weight: .medium))

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.appError)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("キャンセル") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("ちゃりんする") {
                    Task {
                        if await appState.charin(request) { dismiss() }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(bank == nil || appState.isProcessing)
                .accessibilityIdentifier("confirm-charin-button")
            }
        }
        .padding(16)
        .background(Color.appBackground)
        .onAppear { appState.clearError() }
    }
}

struct CharinCelebrationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var coinOffset: CGFloat = -58
    @State private var coinScale: CGFloat = 0.72
    @State private var coinOpacity = 1.0
    @State private var pigScale = 1.0
    @State private var glowOpacity = 0.0
    @State private var burstProgress: CGFloat = 0
    @State private var burstOpacity = 0.0
    @State private var flashOpacity = 0.0
    @State private var titleScale = 0.94
    @State private var balanceScale = 0.94

    private var isShared: Bool {
        guard let bankId = appState.activeCharin?.record.piggyBankId else { return false }
        return appState.initialTemplate?.piggyBanks.first { $0.id == bankId }?.ownerType == .shared
    }

    private var pigImageName: String {
        isShared ? "CharinDoublePiggyBank" : "CharinSinglePiggyBank"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()
            Color.appPrimary.opacity(flashOpacity).ignoresSafeArea()

            if let result = appState.activeCharin {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack(alignment: .top) {
                        CelebrationBurst(progress: burstProgress, isShared: isShared)
                            .frame(width: 360, height: 270)
                            .padding(.top, 18)
                            .opacity(burstOpacity)
                        Circle()
                            .fill(Color.appPrimary.opacity(glowOpacity))
                            .frame(width: isShared ? 300 : 230, height: isShared ? 190 : 230)
                            .blur(radius: 22)
                            .padding(.top, 32)
                        Image(pigImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: isShared ? 310 : 220)
                            .scaleEffect(pigScale)
                            .brightness(glowOpacity * 0.08)
                            .shadow(color: Color.appPrimary.opacity(glowOpacity), radius: 18)
                            .padding(.top, 42)
                        if isShared {
                            ForEach([-65.0, 58.0], id: \.self) { xOffset in
                                CharinCoinView()
                                    .offset(x: xOffset, y: coinOffset)
                                    .scaleEffect(coinScale)
                                    .opacity(coinOpacity)
                            }
                        } else {
                            CharinCoinView()
                                .offset(x: 7, y: coinOffset)
                                .scaleEffect(coinScale)
                                .opacity(coinOpacity)
                        }
                    }
                    .frame(height: 270)

                    Text("ちゃりん！")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.appHeart)
                        .scaleEffect(titleScale)
                        .shadow(color: Color.appHeart.opacity(glowOpacity * 0.55), radius: 8)

                    VStack(spacing: 3) {
                        Text("現在の残高")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(result.record.balanceAfter)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                            Text("コイン")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundStyle(Color.appText)
                        Text("\(result.record.balanceBefore)コインから  +\(result.record.coinDelta)コイン")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appHeart)
                    }
                    .scaleEffect(balanceScale)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("charin-current-balance")

                    if let reward = result.targetReward {
                        Text(reward.becameExchangeable ?
                             "\(reward.iconEmoji) \(reward.title)が\n交換できるようになりました" :
                             "あと\(reward.remainingCoins)コインで\n\(reward.iconEmoji) \(reward.title)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(reward.becameExchangeable ? Color.appSuccess : Color.appSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(.bottom, 82)
            }

        }
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.58)) {
                coinOffset = 29
                coinScale = 1
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-holdCharinCoin") { return }
            if ProcessInfo.processInfo.arguments.contains("-holdCharinBurst") {
                coinOpacity = 0
                pigScale = 1.06
                glowOpacity = 0.58
                burstProgress = 0.5
                burstOpacity = 1
                flashOpacity = 0.1
                titleScale = 1.08
                balanceScale = 1.06
                return
            }
            if ProcessInfo.processInfo.arguments.contains("-holdCharinGlow") {
                coinOpacity = 0
                pigScale = 1.06
                glowOpacity = 0.78
                return
            }
            if ProcessInfo.processInfo.arguments.contains("-holdCharinCelebration") {
                coinOpacity = 0
                return
            }
            #endif
            try? await Task.sleep(for: .milliseconds(520))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.16)) {
                coinOpacity = 0
                pigScale = 1.06
                glowOpacity = 0.78
                flashOpacity = 0.16
                titleScale = 1.08
                balanceScale = 1.06
            }
            burstOpacity = 1
            // Commit one visible frame before the burst starts fading outward.
            try? await Task.sleep(for: .milliseconds(24))
            withAnimation(.easeOut(duration: 0.65)) { burstProgress = 1 }
            try? await Task.sleep(for: .milliseconds(190))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                pigScale = 1
                glowOpacity = 0
                flashOpacity = 0
                titleScale = 1
                balanceScale = 1
            }
            try? await Task.sleep(for: .milliseconds(1_290))
            appState.finishCharinCelebration()
        }
    }
}

private struct CelebrationBurst: View {
    let progress: CGFloat
    let isShared: Bool
    private let colors: [Color] = [.appPrimary, .appHeart, .appAccent, .appSuccess]

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                BurstConfettiPiece(
                    index: index,
                    progress: progress,
                    color: colors[index % colors.count],
                    isShared: isShared
                )
            }

            ForEach(0..<4, id: \.self) { index in
                BurstSymbol(
                    index: index,
                    progress: progress,
                    color: colors[(index + 1) % colors.count],
                    isShared: isShared
                )
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct BurstConfettiPiece: View {
    let index: Int
    let progress: CGFloat
    let color: Color
    let isShared: Bool

    var body: some View {
        let angle = Double(index) * (2 * Double.pi / 16) - (Double.pi / 2)
        let radius: CGFloat = isShared ? 150 + 90 * progress : 100 + 100 * progress
        let opacity = Double(1 - progress)
        Capsule()
            .fill(color)
            .frame(width: index.isMultiple(of: 3) ? 7 : 5, height: index.isMultiple(of: 2) ? 20 : 14)
            .rotationEffect(.radians(angle + Double(progress) * 1.2))
            .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius * 0.72)
            .opacity(opacity)
    }
}

private struct BurstSymbol: View {
    let index: Int
    let progress: CGFloat
    let color: Color
    let isShared: Bool

    var body: some View {
        let angle = Double(index) * (Double.pi / 2) - (Double.pi / 4)
        let opacity = Double(1 - progress)
        Image(systemName: index.isMultiple(of: 2) ? "sparkles" : "heart.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(color)
            .offset(
                x: CGFloat(cos(angle)) * ((isShared ? 150 : 105) + 60 * progress),
                y: CGFloat(sin(angle)) * ((isShared ? 86 : 72) + 42 * progress)
            )
            .scaleEffect(0.65 + progress * 0.65)
            .opacity(opacity)
    }
}

private struct CharinCoinView: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.appAccent)
            Circle().stroke(Color.appPrimary, lineWidth: 4)
            Circle().stroke(Color.white.opacity(0.55), lineWidth: 2).padding(7)
            Image(systemName: "heart.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.appPrimary)
        }
        .frame(width: 52, height: 52)
        .shadow(color: Color.appAccent.opacity(0.28), radius: 5, y: 3)
        .accessibilityHidden(true)
    }
}

struct CharinUndoToast: View {
    @EnvironmentObject private var appState: AppState
    let pending: PendingCharinUndo

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(Int(ceil(pending.expiresAt.timeIntervalSince(context.date))), 0)
            HStack(spacing: 12) {
                Text("ちゃりんしました")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("取り消す \(remaining)秒") {
                    Task { _ = await appState.cancelLatestCharin() }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.appPrimary)
                .disabled(remaining == 0 || appState.isProcessing)
                .accessibilityIdentifier("cancel-charin-button")
            }
        }
        .foregroundStyle(Color.appSurface)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.appText)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        .task(id: pending.expiresAt) {
            let delay = max(pending.expiresAt.timeIntervalSinceNow, 0)
            try? await Task.sleep(for: .seconds(delay))
            appState.expireCharinUndoIfNeeded()
        }
    }
}

struct AppToastView: View {
    @EnvironmentObject private var appState: AppState
    let toast: AppToast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 28, height: 28)
                .background(Color.appAccent.opacity(0.22))
                .clipShape(Circle())
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(Color.appSurface)
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Color.appText)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        .task(id: toast.id) {
            let delay = max(toast.expiresAt.timeIntervalSinceNow, 0)
            try? await Task.sleep(for: .seconds(delay))
            appState.expireToastIfNeeded(id: toast.id)
        }
    }
}

struct RewardsView: View {
    private enum SectionTab: String, CaseIterable {
        case rewards = "ごほうび券"
        case tickets = "持っている券"
    }

    private enum RewardStatusFilter: String, CaseIterable {
        case nearest = "あと少し"
        case exchangeable = "交換できる"
        case all = "すべて"
    }

    private enum BankFilter: String, CaseIterable {
        case all = "すべて"
        case personal = "自分"
        case shared = "ふたり"
    }

    private enum TicketFilter: String, CaseIterable {
        case unused = "使える券"
        case used = "使った券"
    }

    @EnvironmentObject private var appState: AppState
    @State private var section: SectionTab = .rewards
    @State private var statusFilter: RewardStatusFilter = .nearest
    @State private var bankFilter: BankFilter = .all
    @State private var editorRoute: RewardEditorRoute?
    @State private var expandedRewardId: String?
    @State private var exchangeSelection: RewardExchangeSelection?
    @State private var ticketFilter: TicketFilter = .unused
    @State private var selectedTicket: Ticket?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-previewRewardEditor") {
            _statusFilter = State(initialValue: .all)
            _editorRoute = State(initialValue: .create)
        }
        #endif
    }

    private var activeRewards: [Reward] {
        (appState.initialTemplate?.rewards ?? [])
            .filter { $0.status == .active }
            .filter(matchesBankFilter)
            .filter { reward in
                switch statusFilter {
                case .nearest: nearestRewardIds.contains(reward.id)
                case .exchangeable: isExchangeable(reward)
                case .all: true
                }
            }
            .sorted { lhs, rhs in
                if appState.hasExchangedReward(lhs) != appState.hasExchangedReward(rhs) {
                    return !appState.hasExchangedReward(lhs)
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var nearestRewardIds: Set<String> {
        let banks = appState.initialTemplate?.piggyBanks.filter { $0.status == .active } ?? []
        return Set(banks.compactMap { appState.nearestReward(for: $0)?.id })
    }

    private func bank(for reward: Reward) -> PiggyBank? {
        let banks = appState.initialTemplate?.piggyBanks ?? []
        switch reward.piggyBankType {
        case .personal:
            return banks.first {
                $0.status == .active && $0.ownerType == .personal &&
                ($0.ownerUserId == reward.createdBy || $0.ownerUserId == appState.authenticatedUser?.id)
            }
        case .shared:
            return banks.first { $0.status == .active && $0.ownerType == .shared }
        }
    }

    private func matchesBankFilter(_ reward: Reward) -> Bool {
        switch bankFilter {
        case .all: true
        case .personal: reward.piggyBankType == .personal
        case .shared: reward.piggyBankType == .shared
        }
    }

    private func isExchangeable(_ reward: Reward) -> Bool {
        guard !appState.hasExchangedReward(reward) else { return false }
        guard let bank = bank(for: reward) else { return false }
        return bank.balance >= reward.requiredCoins
    }

    var body: some View {
        VStack(spacing: 0) {
            TopTabBar(
                items: SectionTab.allCases.map { ($0, $0.rawValue) },
                selection: $section,
                accessibilityIdentifiers: ["reward-section-rewards", "reward-section-tickets"]
            )
            .padding(.bottom, 14)

            if section == .rewards {
                rewardList
            } else {
                ticketContent
            }
        }
        .background(Color.appBackground)
        .brandNavigationTitle("ごほうび")
        .toolbar {
            Button {
                statusFilter = .all
                bankFilter = .all
                editorRoute = .create
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("ごほうび券を追加")
            .accessibilityIdentifier("add-reward-button")
        }
        .sheet(item: $editorRoute) { route in
            NavigationStack {
                switch route {
                case .create:
                    RewardEditorView(reward: nil)
                case .edit(let reward):
                    RewardEditorView(reward: reward)
                }
            }
        }
        .sheet(item: $exchangeSelection) { selection in
            RewardExchangeConfirmationView(reward: selection.reward, bank: selection.bank)
                .presentationDetents([.height(430)])
        }
        .sheet(item: $selectedTicket) { ticket in
            NavigationStack { TicketDetailView(ticket: ticket) }
        }
        .fullScreenCover(item: $appState.issuedTicket) { ticket in
            TicketIssuedView(
                ticket: ticket,
                onViewTickets: {
                    section = .tickets
                    ticketFilter = .unused
                    appState.issuedTicket = nil
                },
                onClose: { appState.issuedTicket = nil }
            )
        }
        .onChange(of: statusFilter) { expandedRewardId = nil }
        .onChange(of: bankFilter) { expandedRewardId = nil }
        .onAppear {
            if appState.rewardCreationRequested {
                statusFilter = .all
                bankFilter = .all
                editorRoute = .create
                appState.rewardCreationRequested = false
            }
            if appState.usableTicketsRequested {
                section = .tickets
                ticketFilter = .unused
                appState.usableTicketsRequested = false
            }
        }
    }

    private var rewardList: some View {
        VStack(spacing: 12) {
            Picker("状態", selection: $statusFilter) {
                ForEach(RewardStatusFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue)
                        .tag(filter)
                        .accessibilityIdentifier("reward-status-\(filter.rawValue)")
                }
            }
            .pickerStyle(.segmented)
            .padding(6)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder))
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(BankFilter.allCases, id: \.self) { filter in
                    Button {
                        bankFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(bankFilter == filter ? Color.appText : Color.appSecondary)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(bankFilter == filter ? Color.appPrimary : Color.appSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reward-bank-filter-\(filter.rawValue)")
                }
            }
            .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(spacing: 12) {
                    if activeRewards.isEmpty {
                        RewardEmptyState(statusFilter: statusFilter.rawValue)
                    } else {
                        ForEach(activeRewards) { reward in
                            RewardCard(
                                reward: reward,
                                bank: bank(for: reward),
                                isExchangeable: isExchangeable(reward),
                                isExchanged: appState.hasExchangedReward(reward),
                                isExpanded: expandedRewardId == reward.id,
                                canEdit: reward.createdBy == appState.authenticatedUser?.id,
                                onTap: {
                                    guard reward.createdBy == appState.authenticatedUser?.id else { return }
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        expandedRewardId = expandedRewardId == reward.id ? nil : reward.id
                                    }
                                },
                                onEdit: { editorRoute = .edit(reward) },
                                onExchange: {
                                    guard let bank = bank(for: reward) else { return }
                                    exchangeSelection = RewardExchangeSelection(reward: reward, bank: bank)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var ticketContent: some View {
        let filteredTickets = appState.tickets.filter {
            ticketFilter == .unused ? $0.status == .unused : $0.status == .used
        }
        VStack(spacing: 12) {
            Picker("券の状態", selection: $ticketFilter) {
                ForEach(TicketFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue)
                        .tag(filter)
                        .accessibilityIdentifier("ticket-filter-\(filter == .unused ? "unused" : "used")")
                }
            }
            .pickerStyle(.segmented)
            .padding(6)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder))
            .padding(.horizontal, 16)

            if filteredTickets.isEmpty {
                ticketEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTickets) { ticket in
                            TicketListCard(ticket: ticket) { selectedTicket = ticket }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var ticketEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "ticket")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(Color.appSecondary)
            Text("まだ持っている券がありません")
                .font(.system(size: 18, weight: .bold))
            Text("ごほうび券を交換してみよう")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RewardExchangeSelection: Identifiable {
    let reward: Reward
    let bank: PiggyBank
    var id: String { reward.id }
}

private enum RewardEditorRoute: Identifiable {
    case create
    case edit(Reward)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let reward): "edit-\(reward.id)"
        }
    }
}

private struct RewardCard: View {
    let reward: Reward
    let bank: PiggyBank?
    let isExchangeable: Bool
    let isExchanged: Bool
    let isExpanded: Bool
    let canEdit: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onExchange: () -> Void

    private var balance: Int { bank?.balance ?? 0 }
    private var progress: Double {
        guard reward.requiredCoins > 0 else { return 0 }
        return min(Double(balance) / Double(reward.requiredCoins), 1)
    }
    private var remaining: Int { max(reward.requiredCoins - balance, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(reward.iconEmoji)
                            .font(.system(size: 32))
                            .frame(width: 52, height: 52)
                            .background(Color.appPrimarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(reward.title)
                                    .font(.system(size: 17, weight: .bold))
                                    .lineLimit(2)
                            }
                            Label(
                                reward.piggyBankType == .shared ? "ふたりの貯金箱" : "自分の貯金箱",
                                systemImage: reward.piggyBankType == .shared ? "person.2.fill" : "person.fill"
                            )
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.appSecondary)
                        }
                        Spacer(minLength: 4)
                        if canEdit {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.appSecondary)
                        }
                    }
                    .contentShape(Rectangle())

                    HStack(alignment: .firstTextBaseline) {
                        Text("必要コイン")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.appSecondary)
                        Spacer()
                        Text("\(reward.requiredCoins.formatted())")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("コイン")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

                ProgressView(value: progress)
                    .tint(isExchangeable ? Color.appSuccess : Color.appPrimary)

                HStack {
                    Text("\(balance.formatted()) / \(reward.requiredCoins.formatted())コイン")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.appSecondary)
                    Spacer()
                    if isExchanged {
                        Label("交換済み", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.appSecondary)
                    } else if isExchangeable {
                        Label("交換できます", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.appSuccess)
                    } else {
                        Text("あと\(remaining.formatted())コイン")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.appHeart)
                    }
                }

                if isExchangeable {
                    Button(action: onExchange) {
                        Text("交換する")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("exchange-reward-\(reward.id)")
                }
            }
            .padding(16)

            if isExpanded && canEdit {
                Divider()
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appHeart)
                .accessibilityIdentifier("edit-reward-\(reward.id)")
            }
        }
        .background(Color.appSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.appText.opacity(0.055), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reward-card-\(reward.id)")
    }
}

private struct RewardExchangeConfirmationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let reward: Reward
    let bank: PiggyBank

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Color.appBorder).frame(width: 38, height: 5)
            Text(reward.iconEmoji).font(.system(size: 48))
            Text("\(reward.title)を\n交換しますか？")
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            Text("\(reward.requiredCoins.formatted())コインを使って\nごほうび券を発行します。")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.appSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 4) {
                Text("交換後の残高")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)
                Text("\(bank.balance.formatted()) → \((bank.balance - reward.requiredCoins).formatted())コイン")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            if let error = appState.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Color.appError)
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button("キャンセル") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("交換する") {
                    Task {
                        if await appState.exchangeReward(reward, from: bank) { dismiss() }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(appState.isProcessing)
                .accessibilityIdentifier("confirm-exchange-reward-button")
            }
        }
        .padding(16)
        .background(Color.appBackground)
        .onAppear { appState.clearError() }
    }
}

private struct TicketIssuedView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ticket: Ticket
    let onViewTickets: () -> Void
    let onClose: () -> Void
    @State private var cardScale: CGFloat = 0.72
    @State private var cardOpacity = 0.0
    @State private var glowOpacity = 0.0
    @State private var burstProgress: CGFloat = 0
    @State private var burstOpacity = 0.0
    @State private var titleScale: CGFloat = 0.82

    private var giftSourceText: String {
        "\(appState.partnerProfile?.displayName ?? "相手")からのごほうび"
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Circle()
                .fill(Color.appPrimary.opacity(glowOpacity))
                .frame(width: 330, height: 330)
                .blur(radius: 38)
                .offset(y: -170)

            VStack(spacing: 18) {
                Spacer(minLength: 28)

                Text("やった！")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appHeart)
                    .scaleEffect(titleScale)
                    .shadow(color: Color.appHeart.opacity(glowOpacity), radius: 10)
                Text("ごほうび券を発行しました")
                    .font(.system(size: 20, weight: .bold))

                ZStack {
                    CelebrationBurst(progress: burstProgress, isShared: false)
                        .frame(width: 360, height: 290)
                        .opacity(burstOpacity)

                    VStack(spacing: 13) {
                        HStack {
                            Image(systemName: "gift.fill")
                            Text(giftSourceText)
                            Spacer()
                            Image(systemName: "heart.fill")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appOnPrimary)
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(Color.appPrimary)

                        Text(ticket.iconEmoji)
                            .font(.system(size: 72))
                            .frame(height: 86)
                        Text(ticket.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                            .padding(.horizontal, 16)
                        Text("相手に見せて使おう")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appSecondary)
                            .padding(.bottom, 18)
                    }
                    .frame(width: 310)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
                    .shadow(color: Color.appPrimary.opacity(0.26), radius: 20, y: 10)
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)
                }
                .frame(height: 310)

                Text("次の楽しみが、ひとつ増えました")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)

                Spacer(minLength: 20)
                Button("持っている券を見る", action: onViewTickets)
                    .buttonStyle(PrimaryButtonStyle())
                Button("閉じる", action: onClose)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .accessibilityIdentifier("ticket-issued-view")
        .task {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if reduceMotion {
                cardScale = 1
                cardOpacity = 1
                titleScale = 1
                return
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.62)) {
                cardScale = 1
                cardOpacity = 1
                titleScale = 1.08
                glowOpacity = 0.5
            }
            try? await Task.sleep(for: .milliseconds(180))
            burstOpacity = 1
            try? await Task.sleep(for: .milliseconds(24))
            withAnimation(.easeOut(duration: 0.8)) { burstProgress = 1 }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                titleScale = 1
                glowOpacity = 0.22
            }
        }
    }
}

private struct TicketListCard: View {
    let ticket: Ticket
    let onShow: () -> Void

    var body: some View {
        Button(action: onShow) {
            HStack(spacing: 14) {
                Text(ticket.iconEmoji)
                    .font(.system(size: 34))
                    .frame(width: 54, height: 54)
                    .background(Color.appPrimarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 5) {
                    Text(ticket.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.appText)
                    Text(ticket.ticketType == .shared ? "ふたりの券" : "個人の券")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appSecondary)
                    Text(ticket.status == .used ?
                         "使用日：\(ticket.usedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")" :
                         (ticket.expiresAt.map { "期限：\($0.formatted(date: .abbreviated, time: .omitted))" } ?? "期限なし"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.appSecondary)
                }
                Spacer()
                Text("券を表示")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.appHeart)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.appSurface)
        .opacity(ticket.status == .used ? 0.58 : 1)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.appText.opacity(0.055), radius: 8, y: 3)
        .accessibilityIdentifier("券を表示")
    }
}

private struct TicketDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ticket: Ticket
    @State private var showsUseConfirmation = false
    @State private var celebrationPulse = false
    @State private var shimmerOffset: CGFloat = -280

    private var currentTicket: Ticket {
        appState.tickets.first { $0.id == ticket.id } ?? ticket
    }

    private var giftSourceText: String {
        "\(appState.partnerProfile?.displayName ?? "相手")からのごほうび"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text(giftSourceText)
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                        Label(
                            currentTicket.ticketType == .shared ? "ふたり" : "個人",
                            systemImage: currentTicket.ticketType == .shared ? "person.2.fill" : "person.fill"
                        )
                        .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(currentTicket.status == .used ? Color.appText : Color.appOnPrimary)
                    .padding(.horizontal, 20)
                    .frame(height: 58)
                    .background(currentTicket.status == .used ? Color.appBorder : Color.appPrimary)
                    .overlay {
                        if currentTicket.status == .unused && !reduceMotion {
                            Capsule()
                                .fill(Color.white.opacity(0.34))
                                .frame(width: 54, height: 100)
                                .rotationEffect(.degrees(20))
                                .blur(radius: 7)
                                .offset(x: shimmerOffset)
                        }
                    }
                    .clipped()

                    VStack(spacing: 18) {
                        ZStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.appHeart.opacity(0.2))
                                .rotationEffect(.degrees(celebrationPulse ? -10 : 5))
                                .scaleEffect(celebrationPulse ? 1.16 : 0.92)
                                .offset(x: -76, y: celebrationPulse ? -41 : -31)
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.appAccent)
                                .rotationEffect(.degrees(celebrationPulse ? 12 : -8))
                                .scaleEffect(celebrationPulse ? 1.2 : 0.86)
                                .offset(x: 82, y: celebrationPulse ? -31 : -43)
                            Text(currentTicket.iconEmoji)
                                .font(.system(size: 94))
                                .minimumScaleFactor(0.8)
                                .scaleEffect(celebrationPulse ? 1.035 : 0.985)
                                .offset(y: celebrationPulse ? -5 : 3)
                        }
                        .frame(height: 128)

                        Text(currentTicket.title)
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(currentTicket.status == .used ? "この券は使用済みです" : "この券を相手に見せて\n使ってください")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(currentTicket.status == .used ? Color.appSecondary : Color.appText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 30)

                    TicketPerforationDivider()

                    VStack(spacing: 14) {
                        TicketDetailRow(label: "発行日", value: currentTicket.issuedAt.formatted(date: .numeric, time: .omitted))
                        TicketDetailRow(label: "期限", value: currentTicket.expiresAt?.formatted(date: .numeric, time: .omitted) ?? "なし")
                        if let usedAt = currentTicket.usedAt {
                            TicketDetailRow(label: "使用日", value: usedAt.formatted(date: .numeric, time: .omitted))
                        }
                    }
                    .padding(20)
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
                .shadow(color: Color.appPrimary.opacity(0.2), radius: 18, y: 8)
                .opacity(currentTicket.status == .used ? 0.68 : 1)

                if currentTicket.status == .unused {
                    Button("使用済みにする") { showsUseConfirmation = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(appState.isProcessing)
                        .accessibilityIdentifier("use-ticket-button")
                }
                if let error = appState.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Color.appError)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.appBackground)
        .brandNavigationTitle("ごほうび券")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
        }
        .confirmationDialog(
            "使用済みにしますか？",
            isPresented: $showsUseConfirmation,
            titleVisibility: .visible
        ) {
            Button("使用済みにする", role: .destructive) {
                Task {
                    if await appState.useTicket(currentTicket) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        try? await Task.sleep(for: .milliseconds(900))
                        dismiss()
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("一度使用済みにすると戻せません。")
        }
        .onAppear { appState.clearError() }
        .task(id: currentTicket.status) {
            guard currentTicket.status == .unused, !reduceMotion else {
                celebrationPulse = false
                shimmerOffset = -280
                return
            }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                celebrationPulse = true
            }
            withAnimation(.linear(duration: 2.35).repeatForever(autoreverses: false)) {
                shimmerOffset = 280
            }
        }
    }
}

private struct TicketPerforationDivider: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 6) {
                    ForEach(0..<28, id: \.self) { _ in
                        Capsule()
                            .fill(Color.appBorder)
                            .frame(width: 7, height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                Circle()
                    .fill(Color.appBackground)
                    .frame(width: 22, height: 22)
                    .position(x: 0, y: 11)
                Circle()
                    .fill(Color.appBackground)
                    .frame(width: 22, height: 22)
                    .position(x: proxy.size.width, y: 11)
            }
        }
        .frame(height: 22)
    }
}

private struct TicketDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Color.appSecondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.system(size: 15))
    }
}

private struct RewardEditorView: View {
    private enum ExpirySelection: String, CaseIterable {
        case none = "期限なし"
        case sevenDays = "7日"
        case thirtyDays = "30日"
        case date = "日付指定"
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let reward: Reward?
    @State private var title: String
    @State private var iconEmoji: String
    @State private var requiredCoins: Int
    @State private var bankType: PiggyBank.OwnerType
    @State private var expirySelection: ExpirySelection
    @State private var expiryDate: Date
    @State private var showsHideConfirmation = false

    private let emojiOptions = ["☕️", "🍰", "🍿", "🎬", "🍖", "🍽️", "🎁", "🧖", "🎟️", "❤️"]

    init(reward: Reward?) {
        self.reward = reward
        _title = State(initialValue: reward?.title ?? "")
        _iconEmoji = State(initialValue: reward?.iconEmoji ?? "🎁")
        _requiredCoins = State(initialValue: reward?.requiredCoins ?? 500)
        _bankType = State(initialValue: reward?.piggyBankType ?? .personal)
        let selection: ExpirySelection = switch reward?.expiresInType {
        case .days where reward?.expiresInDays == 7: .sevenDays
        case .days: .thirtyDays
        case .date: .date
        default: .none
        }
        _expirySelection = State(initialValue: selection)
        _expiryDate = State(initialValue: reward?.expiresAt ?? Calendar.current.date(byAdding: .day, value: 30, to: Date())!)
    }

    private var draft: RewardDraft {
        let expiry: (Reward.ExpiryType, Int?, Date?) = switch expirySelection {
        case .none: (.none, nil, nil)
        case .sevenDays: (.days, 7, nil)
        case .thirtyDays: (.days, 30, nil)
        case .date: (.date, nil, expiryDate)
        }
        return RewardDraft(
            title: title,
            iconEmoji: iconEmoji,
            requiredCoins: requiredCoins,
            piggyBankType: bankType,
            expiresInType: expiry.0,
            expiresInDays: expiry.1,
            expiresAt: expiry.2
        )
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        requiredCoins > 0 &&
        (expirySelection != .date || expiryDate > Date()) &&
        !appState.isProcessing
    }

    var body: some View {
        Form {
            Section("ごほうび券") {
                Picker("アイコン", selection: $iconEmoji) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Text(emoji).tag(emoji)
                    }
                }
                TextField("ごほうび券の名前", text: $title)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("reward-title-field")
            }

            Section("必要コイン") {
                TextField("必要コイン", value: $requiredCoins, format: .number)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("reward-coins-field")
                Stepper("\(requiredCoins.formatted())コイン", value: $requiredCoins, in: 50...100_000, step: 50)
            }

            Section("貯金箱") {
                Picker("貯金箱", selection: $bankType) {
                    Text("自分").tag(PiggyBank.OwnerType.personal)
                    Text("ふたり").tag(PiggyBank.OwnerType.shared)
                }
                .pickerStyle(.segmented)
            }

            Section("期限") {
                Picker("期限", selection: $expirySelection) {
                    ForEach(ExpirySelection.allCases, id: \.self) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                if expirySelection == .date {
                    DatePicker(
                        "日付",
                        selection: $expiryDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                }
            }

            if let errorMessage = appState.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.appError)
                }
            }

            if reward != nil {
                Section {
                    Button("このごほうび券を非表示にする", role: .destructive) {
                        showsHideConfirmation = true
                    }
                    .disabled(appState.isProcessing)
                }
            }
        }
        .modernFormBackground()
        .brandNavigationTitle(reward == nil ? "ごほうび券を作る" : "ごほうび券を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存する") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("save-reward-button")
            }
        }
        .confirmationDialog(
            "このごほうび券を非表示にしますか？",
            isPresented: $showsHideConfirmation,
            titleVisibility: .visible
        ) {
            Button("非表示にする", role: .destructive) { hide() }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear { appState.clearError() }
    }

    private func save() {
        Task {
            let succeeded: Bool
            if let reward {
                succeeded = await appState.updateReward(reward, draft: draft)
            } else {
                succeeded = await appState.createReward(draft)
            }
            if succeeded { dismiss() }
        }
    }

    private func hide() {
        guard let reward else { return }
        Task {
            if await appState.hideReward(reward) { dismiss() }
        }
    }
}

private struct RewardEmptyState: View {
    let statusFilter: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.appSecondary)
            Text("\(statusFilter)のごほうび券はありません")
                .font(.system(size: 16, weight: .bold))
            Text("条件を変えると、ほかの券を確認できます")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.appSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

struct RecordsView: View {
    private enum ActorFilter: String, CaseIterable {
        case all = "すべて"
        case mine = "自分"
        case partner = "相手"
    }

    private enum BankRecordFilter: String, CaseIterable {
        case all = "すべて"
        case personal = "自分"
        case shared = "ふたり"
    }

    @EnvironmentObject private var appState: AppState
    @State private var actorFilter: ActorFilter = .all
    @State private var bankFilter: BankRecordFilter = .all
    @State private var reactionRecordId: String?
    @State private var selectedTicket: Ticket?

    private var visibleRecords: [ActivityRecord] {
        appState.records
            .filter { $0.status == .active }
            .filter { record in
                switch actorFilter {
                case .all: return true
                case .mine: return record.userId == appState.authenticatedUser?.id
                case .partner: return record.userId != appState.authenticatedUser?.id
                }
            }
            .filter { record in
                guard bankFilter != .all else { return true }
                let ownerType = appState.initialTemplate?.piggyBanks.first { $0.id == record.piggyBankId }?.ownerType
                return bankFilter == .personal ? ownerType == .personal : ownerType == .shared
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var monthlyCharinTotal: Int {
        let calendar = Calendar.current
        return visibleRecords
            .filter { $0.type == .charin && calendar.isDate($0.createdAt, equalTo: Date(), toGranularity: .month) }
            .map(\.coinDelta)
            .reduce(0, +)
    }

    private var dayGroups: [(date: Date, records: [ActivityRecord])] {
        let calendar = Calendar.current
        return Dictionary(grouping: visibleRecords) { calendar.startOfDay(for: $0.createdAt) }
            .map { (date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                MonthlyRecordSummary(totalCoins: monthlyCharinTotal)

                RecordFilterChipRow(
                    title: "表示",
                    items: ActorFilter.allCases.map { ($0, $0.rawValue) },
                    selection: $actorFilter
                )

                RecordFilterChipRow(
                    title: "貯金箱",
                    items: BankRecordFilter.allCases.map { ($0, $0.rawValue) },
                    selection: $bankFilter
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if dayGroups.isEmpty {
                ContentUnavailableView {
                    Label("まだきろくがありません", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("最初のおねがいをちゃりんしてみよう")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(dayGroups, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(dayTitle(group.date))
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                VStack(spacing: 0) {
                                    ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                                        RecordHistoryRow(
                                            record: record,
                                            actorName: actorName(for: record),
                                            reaction: appState.reactions.first { $0.recordId == record.id },
                                            canReact: canReact(to: record),
                                            showsReactionPicker: reactionRecordId == record.id,
                                            onToggleReactionPicker: {
                                                withAnimation(.easeInOut(duration: 0.16)) {
                                                    reactionRecordId = reactionRecordId == record.id ? nil : record.id
                                                }
                                            },
                                            onSelectReaction: { stamp in
                                                reactionRecordId = nil
                                                Task { _ = await appState.setReaction(stamp, for: record) }
                                            },
                                            onOpenTicket: ticket(for: record).map { ticket in
                                                { selectedTicket = ticket }
                                            }
                                        )
                                        .zIndex(reactionRecordId == record.id ? 1 : 0)
                                        if index < group.records.count - 1 {
                                            Divider().padding(.leading, 66)
                                        }
                                    }
                                }
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder))
                                .shadow(color: Color.appText.opacity(0.055), radius: 8, y: 3)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.appBackground)
        .brandNavigationTitle("きろく")
        .sheet(item: $selectedTicket) { ticket in
            NavigationStack { TicketDetailView(ticket: ticket) }
        }
        .onChange(of: actorFilter) { reactionRecordId = nil }
        .onChange(of: bankFilter) { reactionRecordId = nil }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今日" }
        if calendar.isDateInYesterday(date) { return "昨日" }
        return date.formatted(.dateTime.month().day().locale(Locale(identifier: "ja_JP")))
    }

    private func actorName(for record: ActivityRecord) -> String {
        if record.userId == appState.authenticatedUser?.id {
            return appState.profile?.displayName ?? "あなた"
        }
        return appState.partnerProfile?.displayName ?? "相手"
    }

    private func canReact(to record: ActivityRecord) -> Bool {
        record.type == .charin && record.userId != appState.authenticatedUser?.id
    }

    private func ticket(for record: ActivityRecord) -> Ticket? {
        switch record.targetType {
        case "ticket":
            return appState.tickets.first { $0.id == record.targetId }
        case "reward":
            return appState.tickets.first { $0.rewardId == record.targetId }
        default:
            return nil
        }
    }
}

private struct RecordFilterChipRow<Selection: Hashable>: View {
    let title: String
    let items: [(Selection, String)]
    @Binding var selection: Selection

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.appSecondary)
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            selection = item.0
                        }
                    } label: {
                        Text(item.1)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selection == item.0 ? Color.appText : Color.appSecondary)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(selection == item.0 ? Color.appPrimarySoft : Color.appSurface)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MonthlyRecordSummary: View {
    let totalCoins: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 38, height: 38)
                .background(Color.appPrimarySoft)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("今月のちゃりん")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)
                Text("\(totalCoins)コイン")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder))
    }
}

private struct RecordHistoryRow: View {
    let record: ActivityRecord
    let actorName: String
    let reaction: Reaction?
    let canReact: Bool
    let showsReactionPicker: Bool
    let onToggleReactionPicker: () -> Void
    let onSelectReaction: (Reaction.StampType) -> Void
    let onOpenTicket: (() -> Void)?

    private var actionText: String {
        switch record.type {
        case .charin: "\(actorName)がちゃりん"
        case .rewardExchange: "\(actorName)が交換"
        case .ticketUsed: "\(actorName)が使用済みにしました"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(record.iconEmoji)
                .font(.system(size: 23))
                .frame(width: 42, height: 42)
                .background(Color.appPrimarySoft)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text("\(actionText)・\(record.createdAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if record.coinDelta != 0 {
                Text(record.coinDelta > 0 ? "+\(record.coinDelta)" : "\(record.coinDelta)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(record.coinDelta > 0 ? Color.appSuccess : Color.appError)
            }
            if canReact {
                Button(action: onToggleReactionPicker) {
                    Text(reaction?.stampType.emoji ?? "☺️")
                        .font(.system(size: 19))
                        .frame(width: 44, height: 44)
                        .background(reaction == nil ? Color.appBackground : Color.appPrimarySoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(reaction == nil ? "スタンプを選ぶ" : "スタンプを変更")
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenTicket?()
        }
        .overlay(alignment: .bottomTrailing) {
            if showsReactionPicker {
                HStack(spacing: 2) {
                    ForEach(Reaction.StampType.allCases, id: \.self) { stamp in
                        Button { onSelectReaction(stamp) } label: {
                            Text(stamp.emoji).font(.system(size: 20)).frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(stamp.label)
                    }
                }
                .padding(6)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.appBorder))
                .shadow(color: Color.appText.opacity(0.14), radius: 10, y: 4)
                .offset(y: 52)
            }
        }
    }
}
