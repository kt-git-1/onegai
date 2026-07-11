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

    var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            Image("PiggyBank")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: compact ? 17 : 22, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
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
                    BrandTitle(title: title)
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
}
