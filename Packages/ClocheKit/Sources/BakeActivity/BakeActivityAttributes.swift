import ActivityKit
import Foundation

/// The bake's Live Activity: on the lock screen, the Dynamic Island and, mirrored by the system,
/// the Apple Watch Smart Stack (PRD BK-8, WT-1 to WT-3). Shared by the app, which starts and
/// updates it, and the widget extension, which draws it.
///
/// Holds only bake state (Guideline 2.5.16), and nothing about the dish, like the notifications.
public struct BakeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public enum Stage: String, Codable, Hashable, Sendable {
            /// Door shut, counting down to `endsAt`.
            case baking
            /// Door open mid-bake; counting down the grace to `graceEndsAt`.
            case ajar
            /// Finished and keeping warm.
            case ready
        }

        public var stage: Stage
        public var startedAt: Date
        public var endsAt: Date
        public var graceEndsAt: Date?

        public init(stage: Stage, startedAt: Date, endsAt: Date, graceEndsAt: Date? = nil) {
            self.stage = stage
            self.startedAt = startedAt
            self.endsAt = endsAt
            self.graceEndsAt = graceEndsAt
        }

        /// When this state stops being true without the app saying so: the bake ends at `endsAt`,
        /// the grace at `graceEndsAt`. The views read `isStale` to show what comes next, because
        /// the app may be suspended at that moment.
        public var staleDate: Date? {
            switch stage {
            case .baking: endsAt
            case .ajar: graceEndsAt
            case .ready: nil
            }
        }
    }

    public init() {}
}
