import Domain
import os

/// Routes engine effects to the services that perform them. Notifications join in slice 1.8
/// and sounds in 2.9; anything not yet handled is logged.
@MainActor
public final class SessionEffectRouter: SessionEffectPerforming {
    private let haptics: any HapticPlaying
    private let announcer: any Announcing
    private let logger = Logger(subsystem: "com.shubhamtyagi.pocketoven", category: "Session")

    public init(haptics: any HapticPlaying, announcer: any Announcing) {
        self.haptics = haptics
        self.announcer = announcer
    }

    public func perform(_ effects: [SessionEffect]) {
        for effect in effects {
            logger.notice("effect \(String(describing: effect), privacy: .public)")
            if case let .cue(cue) = effect {
                let plan = FeedbackPlan.plan(for: cue)
                if let haptic = plan.haptic { haptics.play(haptic) }
                if let announcement = plan.announcement { announcer.announce(announcement) }
            }
        }
    }
}
