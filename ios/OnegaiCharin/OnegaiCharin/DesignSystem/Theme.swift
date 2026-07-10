import SwiftUI

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
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
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.appText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(configuration.isPressed ? Color.appPrimarySoft : Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
}
