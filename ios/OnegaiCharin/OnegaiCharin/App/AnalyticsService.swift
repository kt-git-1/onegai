import FirebaseAnalytics
import Foundation

enum AnalyticsEvent: String {
    case signUpCompleted = "sign_up_completed"
    case templateApplied = "template_applied"
    case inviteScreenViewed = "invite_screen_viewed"
    case inviteSent = "invite_sent"
    case inviteJoined = "invite_joined"
    case charinCompleted = "charin_completed"
    case charinCanceled = "charin_canceled"
    case rewardExchanged = "reward_exchanged"
    case ticketUsed = "ticket_used"
    case reactionAdded = "reaction_added"
    case day1Retention = "day_1_retention"
    case day7Retention = "day_7_retention"
}

final class AnalyticsService {
    typealias LogHandler = (String, [String: Any]) -> Void

    static let shared = AnalyticsService()

    private let isEnabled: Bool
    private let logHandler: LogHandler

    init(
        isEnabled: Bool = AnalyticsService.shouldEnableAnalytics(),
        logHandler: @escaping LogHandler = { eventName, parameters in
            Analytics.logEvent(eventName, parameters: parameters)
        }
    ) {
        self.isEnabled = isEnabled
        self.logHandler = logHandler
    }

    func log(_ event: AnalyticsEvent, parameters: [String: Any?] = [:]) {
        guard isEnabled else { return }
        let compactParameters = parameters.compactMapValues { value -> Any? in
            switch value {
            case let value as String where !value.isEmpty:
                return value
            case let value as Int:
                return value
            case let value as Double:
                return value
            case let value as Bool:
                return value ? 1 : 0
            default:
                return nil
            }
        }
        logHandler(event.rawValue, compactParameters)
    }

    private static func shouldEnableAnalytics() -> Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        if arguments.contains("-disableAnalytics")
            || arguments.contains("-previewPhase")
            || environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        #endif
        return true
    }
}
