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
                .tabItem { Label("お願い", systemImage: "heart.text.square") }
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
            }
        }
    }
}

private struct AppHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title).font(.system(size: 20, weight: .bold))
            Spacer()
            Button {} label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(Color.appSecondary)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedBankIndex: Int
    @State private var charinRequest: RequestItem?

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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AppHeader(title: "おねがいチャリン")

                if banks.isEmpty {
                    ContentUnavailableView(
                        "貯金箱を読み込めませんでした",
                        systemImage: "tray",
                        description: Text("画面を開き直して、もう一度お試しください。")
                    )
                    .frame(minHeight: 360)
                } else {
                    Text(isShared ? "ふたり" : "自分")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appSecondary)

                    TabView(selection: $selectedBankIndex) {
                        ForEach(Array(banks.enumerated()), id: \.element.id) { index, bank in
                            BankCard(
                                bank: bank,
                                targetReward: appState.initialTemplate?.rewards.first { $0.id == bank.targetRewardId },
                                onSelectTarget: { appState.selectedTab = 2 }
                            )
                            .padding(.horizontal, 1)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 274)

                    HStack(spacing: 7) {
                        ForEach(banks.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedBankIndex ? Color.appHeart : Color.appBorder)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .frame(height: 12)

                    HomeSection(title: isShared ? "ふたりのお願い" : "よく使うお願い") {
                        if selectedRequests.isEmpty {
                            HomeEmptyRow(text: "まだお願いがありません")
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
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $charinRequest) { request in
            CharinConfirmationSheet(request: request)
                .presentationDetents([.height(430)])
        }
    }
}

private struct BankCard: View {
    let bank: PiggyBank
    let targetReward: Reward?
    let onSelectTarget: () -> Void

    private var remainingCoins: Int {
        max((targetReward?.requiredCoins ?? 0) - bank.balance, 0)
    }

    private var progress: Double {
        guard let requiredCoins = targetReward?.requiredCoins, requiredCoins > 0 else { return 0 }
        return min(Double(bank.balance) / Double(requiredCoins), 1)
    }

    var body: some View {
        VStack(spacing: 7) {
            Text(bank.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Group {
                if bank.ownerType == .shared {
                    Image("DoublePiggyBank")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .frame(height: 88)
                        .clipped()
                        .accessibilityLabel("ふたりの貯金箱キャラクター")
                } else {
                    MascotView(size: .compact)
                }
            }
            .frame(height: 88)
            Text("\(bank.balance.formatted())コイン")
                .font(.system(size: 28, weight: .bold)).monospacedDigit()
            if let targetReward {
                Text("目標：\(targetReward.iconEmoji) \(targetReward.title)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appSecondary)
                    .lineLimit(1)
                Text(remainingCoins == 0 ? "交換できます" : "あと\(remainingCoins.formatted())コイン")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appHeart)
                ProgressView(value: progress)
                    .tint(Color.appPrimary)
                    .padding(.horizontal, 20)
            } else {
                Text("目標のごほうび券を選ぼう")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appSecondary)
                Button("ごほうび券を選ぶ", action: onSelectTarget)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appText)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 238)
        .padding(18)
        .background(Color.appSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
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
            Text(record.iconEmoji).font(.system(size: 24)).frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(dateText).font(.system(size: 11)).foregroundStyle(Color.appSecondary)
            }
            Spacer()
            Text(record.coinDelta > 0 ? "+\(record.coinDelta)" : "\(record.coinDelta)")
                .font(.system(size: 13, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 16, weight: .semibold))
            VStack(spacing: 0) { content }
                .background(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct RequestRow: View {
    let request: RequestItem
    let onCharin: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(request.iconEmoji).font(.system(size: 24)).frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(request.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text("+\(request.coinAmount)コイン ・ \(request.repeatType.displayName)").font(.system(size: 11)).foregroundStyle(Color.appSecondary)
            }
            Spacer()
            Button("ちゃりん", action: onCharin)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appText)
                .padding(.horizontal, 13).frame(height: 36)
                .background(Color.appPrimary).clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(12)
    }
}

struct RequestsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var bankType: PiggyBank.OwnerType = .personal
    @State private var expandedRequestId: String?
    @State private var editorRoute: RequestEditorRoute?
    @State private var charinRequest: RequestItem?

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
            Picker("貯金箱", selection: $bankType) {
                Text("お願い").tag(PiggyBank.OwnerType.personal)
                Text("ふたりのお願い").tag(PiggyBank.OwnerType.shared)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .accessibilityIdentifier("request-bank-picker")

            if requests.isEmpty {
                ContentUnavailableView {
                    Label("まだお願いがありません", systemImage: "heart.text.square")
                } actions: {
                    Button("お願いを作る") { editorRoute = .create(bankType) }
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
        .navigationTitle("お願い")
        .toolbar {
            Button { editorRoute = .create(bankType) } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("お願いを追加")
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

                Button("ちゃりん", action: onCharin)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appText)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            Section("お願い") {
                Picker("アイコン", selection: $iconEmoji) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Text(emoji).tag(emoji)
                    }
                }
                TextField("お願いの名前", text: $title)
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
                    Button("このお願いを非表示にする", role: .destructive) {
                        showsHideConfirmation = true
                    }
                    .disabled(appState.isProcessing)
                }
            }
        }
        .navigationTitle(request == nil ? "お願いを作る" : "お願いを編集")
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
            "このお願いを非表示にしますか？",
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
    private var reward: Reward? { bank.flatMap(appState.targetReward(for:)) }
    private var remainingCoins: Int? {
        guard let bank, let reward else { return nil }
        return max(reward.requiredCoins - bank.balance - request.coinAmount, 0)
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.appBorder)
                .frame(width: 38, height: 5)

            Text("このお願いをちゃりんしますか？")
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

struct RewardsView: View {
    @State private var owned = false

    var body: some View {
        VStack(spacing: 12) {
            Picker("券", selection: $owned) {
                Text("ごほうび券").tag(false)
                Text("持っている券").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            List {
                Label(owned ? "スタバごほうび券　使用する" : "スタバごほうび券　700コイン", systemImage: "cup.and.heat.waves.fill")
                Label(owned ? "映画ごほうび券　使用する" : "映画ごほうび券　1,200コイン", systemImage: "film.fill")
                Label(owned ? "焼肉デート券　使用する" : "焼肉デート券　5,000コイン", systemImage: "fork.knife")
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.appBackground)
        .navigationTitle("ごほうび")
    }
}

struct RecordsView: View {
    var body: some View {
        List {
            Section("今月") {
                record("マッサージ10分", detail: "今日 20:12", amount: "+100")
                record("皿洗い", detail: "昨日 19:30", amount: "+50")
                record("スタバごほうび券", detail: "7月8日", amount: "-700")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("きろく")
    }

    private func record(_ title: String, detail: String, amount: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(Color.appSecondary)
            }
            Spacer()
            Text(amount).foregroundStyle(amount.hasPrefix("+") ? Color.appSuccess : Color.appError)
            Button(action: {}) { Image(systemName: "face.smiling") }.buttonStyle(.plain)
        }
    }
}
