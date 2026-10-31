import Domain
import Foundation

/// Haptics from the design handoff. Device only; the simulator can't play them.
public enum Haptic: Equatable, Sendable {
    /// Bake start: the door latching shut.
    case doorLatch
    /// Reveal: the oven door dropping open.
    case doorThunk
    /// Serve: a soft thud as the dish lands on the table.
    case softThud
}

@MainActor
public protocol HapticPlaying: AnyObject {
    func play(_ haptic: Haptic)
}

/// Spoken updates for VoiceOver users (handoff "Announcements").
@MainActor
public protocol Announcing: AnyObject {
    func announce(_ message: String)
}

/// What each session cue sounds and feels like. Pure, so the mapping is tested.
public struct FeedbackPlan: Equatable, Sendable {
    public let haptic: Haptic?
    public let announcement: String?

    public init(haptic: Haptic?, announcement: String?) {
        self.haptic = haptic
        self.announcement = announcement
    }

    public static func plan(for cue: SessionCue) -> FeedbackPlan {
        switch cue {
        case .bakeStarted:
            FeedbackPlan(haptic: .doorLatch, announcement: String(localized: "Bake started", bundle: .module))
        case .doorAjar:
            FeedbackPlan(haptic: nil, announcement: String(localized: "Door ajar, 15 seconds", bundle: .module))
        case .bakeResumed:
            FeedbackPlan(haptic: .doorLatch, announcement: String(localized: "Door shut, still baking", bundle: .module))
        case .bakeReady:
            FeedbackPlan(haptic: nil, announcement: String(localized: "Bake ready", bundle: .module))
        case .bakeEndedEarly:
            FeedbackPlan(haptic: nil, announcement: String(localized: "Bake ended early. It still goes in your recipe book.", bundle: .module))
        case .doorOpened:
            FeedbackPlan(haptic: .doorThunk, announcement: nil)
        case let .served(stars):
            FeedbackPlan(haptic: .softThud, announcement: String(localized: "Served. \(stars) of 3 stars", bundle: .module))
        }
    }
}
