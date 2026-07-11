import SwiftUI

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum AppRadius {
    static let control: CGFloat = 8
    static let card: CGFloat = 8
}

extension Color {
    static let appBackground = Color("Background")
    static let appSurface = Color("Surface")
    static let appPrimary = Color("Primary")
    static let appPrimarySoft = Color("PrimarySoft")
    static let appAccent = Color("CoinAccent")
    static let appHeart = Color("Heart")
    static let appText = Color("TextPrimary")
    static let appSecondary = Color("TextSecondary")
    static let appDisabled = Color("TextDisabled")
    static let appBorder = Color("Border")
    static let appSuccess = Color("Success")
    static let appError = Color("Error")
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.appText : Color.appDisabled)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled ? (configuration.isPressed ? Color.appAccent : Color.appPrimary) : Color.appPrimarySoft)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.appText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(configuration.isPressed ? Color.appPrimarySoft : Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.control).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
    }
}

struct MascotView: View {
    enum Size {
        case onboarding, authentication, compact, result

        var width: CGFloat {
            switch self {
            case .onboarding: 190
            case .authentication: 116
            case .compact: 94
            case .result: 188
            }
        }
    }

    let size: Size

    var body: some View {
        Image("PiggyBank")
            .resizable()
            .scaledToFit()
            .frame(width: size.width)
            .offset(x: 4)
            .accessibilityLabel("おねがいチャリンの貯金箱キャラクター")
    }
}

struct BrandTitle: View {
    let title: String
    var compact = true
    var showsMark = true

    var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            if showsMark {
                Image("PiggyBank")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: compact ? (showsMark ? 17 : 16) : 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BrandPatternBackground: View {
    var body: some View {
        ZStack {
            Color.appSurface
            Canvas { context, size in
                let stripe = Path { path in
                    var offset: CGFloat = -size.height
                    while offset < size.width {
                        path.move(to: CGPoint(x: offset, y: size.height))
                        path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                        offset += 34
                    }
                }
                context.stroke(stripe, with: .color(Color.appPrimary.opacity(0.14)), lineWidth: 1)
            }
        }
    }
}

struct TopTabBar<Item: Hashable>: View {
    let items: [(value: Item, title: String)]
    @Binding var selection: Item
    var accessibilityIdentifiers: [String]? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = item.value }
                } label: {
                    VStack(spacing: 10) {
                        Text(item.title)
                            .font(.system(size: 15, weight: selection == item.value ? .bold : .semibold))
                            .foregroundStyle(selection == item.value ? Color.appText : Color.appSecondary)
                            .frame(maxWidth: .infinity)
                        Capsule()
                            .fill(selection == item.value ? Color.appPrimary : Color.clear)
                            .frame(height: 3)
                            .padding(.horizontal, 18)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityIdentifiers?[safe: index] ?? "")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .background(Color.appSurface)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.appBorder).frame(height: 1) }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct BrandNavigationTitleModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandTitle(title: title, showsMark: title.count <= 6)
                }
            }
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.appText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground.ignoresSafeArea())
    }
}

extension View {
    func appScreen() -> some View { modifier(ScreenBackground()) }
    func brandNavigationTitle(_ title: String) -> some View {
        modifier(BrandNavigationTitleModifier(title: title))
    }
    func modernFormBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.appBackground)
    }
}
