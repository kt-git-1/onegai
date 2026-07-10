import SwiftUI

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
    @State private var shared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AppHeader(title: "おねがいチャリン")
                Picker("貯金箱", selection: $shared) {
                    Text("自分").tag(false)
                    Text("ふたり").tag(true)
                }
                .pickerStyle(.segmented)

                BankCard(shared: shared)

                HomeSection(title: shared ? "ふたりのお願い" : "よく使うお願い") {
                    RequestRow(emoji: shared ? "🧹" : "💆", title: shared ? "ふたりで部屋を片付ける" : "マッサージ10分", coins: shared ? 200 : 100)
                    Divider()
                    RequestRow(emoji: shared ? "🥢" : "🧺", title: shared ? "デートの予定を決める" : "皿洗い", coins: shared ? 300 : 50)
                }

                HomeSection(title: shared ? "最近のふたりのきろく" : "最近のきろく") {
                    HStack(spacing: 10) {
                        Text(shared ? "🧹" : "💆").font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(shared ? "部屋を片付ける" : "マッサージ10分").font(.system(size: 14, weight: .semibold))
                            Text("今日 20:12").font(.system(size: 11)).foregroundStyle(Color.appSecondary)
                        }
                        Spacer()
                        Text(shared ? "+200" : "+100").foregroundStyle(Color.appSuccess).fontWeight(.semibold)
                    }
                    .padding(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BankCard: View {
    let shared: Bool

    var body: some View {
        VStack(spacing: 7) {
            MascotView(size: .compact).frame(height: 88)
            Text(shared ? "2,800コイン" : "520コイン")
                .font(.system(size: 28, weight: .bold)).monospacedDigit()
            Text(shared ? "目標：🍖 焼肉デートごほうび券" : "目標：☕️ スタバごほうび券")
                .font(.system(size: 13)).foregroundStyle(Color.appSecondary)
            Text(shared ? "あと2,200コイン" : "あと180コイン")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.appHeart)
            ProgressView(value: shared ? 0.56 : 0.74)
                .tint(Color.appPrimary)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.appSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
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
    let emoji: String
    let title: String
    let coins: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 24)).frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text("+\(coins)コイン ・ 繰り返し").font(.system(size: 11)).foregroundStyle(Color.appSecondary)
            }
            Spacer()
            Button("ちゃりん") {}
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appText)
                .padding(.horizontal, 13).frame(height: 36)
                .background(Color.appPrimary).clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(12)
    }
}

struct RequestsView: View {
    var body: some View {
        List {
            Section("よく使う順") {
                Label("マッサージ10分　+100コイン", systemImage: "hands.sparkles")
                Label("皿洗い　+50コイン", systemImage: "drop.fill")
                Label("買い出し　+80コイン", systemImage: "basket.fill")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("お願い")
        .toolbar { Button(action: {}) { Image(systemName: "plus") } }
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
