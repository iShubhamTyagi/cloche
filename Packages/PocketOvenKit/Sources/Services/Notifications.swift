import Domain
import Foundation

public enum NotificationPermission: Sendable, Equatable {
    case notDetermined
    case allowed
    case denied
}

/// Local notifications only; no push entitlement (PRD §11).
@MainActor
public protocol NotificationScheduling: AnyObject {
    func permission() async -> NotificationPermission
    /// Shows the system prompt. Returns whether notifications are now allowed.
    func requestPermission() async -> Bool
    func schedule(_ kind: SessionNotification, at date: Date)
    func cancel(_ kind: SessionNotification)
}

/// Notification wording. Generic on purpose: nothing about what the player is working on
/// ever leaves the app, even to the lock screen.
public struct NotificationContent: Equatable, Sendable {
    public let title: String
    public let body: String

    public static func content(for kind: SessionNotification) -> NotificationContent {
        switch kind {
        case .bakeReady:
            NotificationContent(
                title: String(localized: "Your bake is ready", bundle: .module),
                body: String(localized: "It keeps warm until you open the oven. Finish what you're doing first.", bundle: .module)
            )
        case .breakOver:
            NotificationContent(
                title: String(localized: "Served", bundle: .module),
                body: String(localized: "Your break is over and the dish is in your recipe book.", bundle: .module)
            )
        }
    }
}

#if canImport(UserNotifications)
import UserNotifications

@MainActor
public final class UserNotificationScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    public override init() {
        super.init()
        center.delegate = self
    }

    public func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .allowed
        }
    }

    public func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func schedule(_ kind: SessionNotification, at date: Date) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        let text = NotificationContent.content(for: kind)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        let request = UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        center.add(request)
    }

    public func cancel(_ kind: SessionNotification) {
        center.removePendingNotificationRequests(withIdentifiers: [kind.rawValue])
        center.removeDeliveredNotifications(withIdentifiers: [kind.rawValue])
    }

    /// In the foreground the app's own screen and chime say it; no banner on top.
    public nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.list]
    }
}
#endif
