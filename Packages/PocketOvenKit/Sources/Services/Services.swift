import Domain
import os

/// Routes engine effects to the services that perform them. Notifications, sound and haptics
/// join in slices 1.7 and 1.8; until then effects are logged so the flow can be followed.
@MainActor
public final class SessionEffectRouter: SessionEffectPerforming {
    private let logger = Logger(subsystem: "com.shubhamtyagi.pocketoven", category: "Session")

    public init() {}

    public func perform(_ effects: [SessionEffect]) {
        for effect in effects {
            logger.notice("effect \(String(describing: effect), privacy: .public)")
        }
    }
}
