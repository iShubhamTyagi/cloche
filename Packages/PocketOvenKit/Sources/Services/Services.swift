import Domain
import os

/// Routes engine effects to the services that perform them.
@MainActor
public final class SessionEffectRouter: SessionEffectPerforming {
    private let haptics: any HapticPlaying
    private let announcer: any Announcing
    private let sounds: any SoundPlaying
    private let notifications: any NotificationScheduling
    private let soundsEnabled: () -> Bool
    private let logger = Logger(subsystem: "com.shubhamtyagi.pocketoven", category: "Session")

    /// - Parameter soundsEnabled: the player's Sounds setting, read when each sound would play.
    public init(haptics: any HapticPlaying, announcer: any Announcing, sounds: any SoundPlaying, notifications: any NotificationScheduling, soundsEnabled: @escaping () -> Bool) {
        self.haptics = haptics
        self.announcer = announcer
        self.sounds = sounds
        self.notifications = notifications
        self.soundsEnabled = soundsEnabled
    }

    public func perform(_ effects: [SessionEffect]) {
        for effect in effects {
            logger.notice("effect \(String(describing: effect), privacy: .public)")
            switch effect {
            case let .scheduleNotification(kind, date):
                notifications.schedule(kind, at: date)
            case let .cancelNotification(kind):
                notifications.cancel(kind)
            case let .cue(cue):
                let plan = FeedbackPlan.plan(for: cue)
                if let haptic = plan.haptic { haptics.play(haptic) }
                if let announcement = plan.announcement { announcer.announce(announcement) }
                if let sound = plan.sound, soundsEnabled() { sounds.play(sound) }
            }
        }
    }
}
