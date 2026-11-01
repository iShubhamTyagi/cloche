import BakeActivity
import Domain
import Foundation
import os

/// Mirrors the session to the bake's Live Activity. Only the session controller calls it.
@MainActor
public protocol BakeActivityPresenting: AnyObject {
    func reflect(_ phase: SessionPhase)
}

/// Which Live Activity state a phase shows; nil means no activity. A bake has started once the
/// door first shuts, so preheating shows nothing.
public enum BakeActivityContent {
    public static func state(for phase: SessionPhase) -> BakeActivityAttributes.ContentState? {
        switch phase {
        case let .baking(bake):
            guard let startedAt = bake.startedAt, let endsAt = bake.endsAt else { return nil }
            return .init(stage: .baking, startedAt: startedAt, endsAt: endsAt)
        case let .ajar(bake, _, graceEndsAt):
            guard let startedAt = bake.startedAt, let endsAt = bake.endsAt else { return nil }
            return .init(stage: .ajar, startedAt: startedAt, endsAt: endsAt, graceEndsAt: graceEndsAt)
        case let .ready(bake):
            guard let startedAt = bake.startedAt, let endsAt = bake.endsAt else { return nil }
            return .init(stage: .ready, startedAt: startedAt, endsAt: endsAt)
        case .idle, .armed, .graded, .decorating, .served:
            return nil
        }
    }
}

#if canImport(ActivityKit)
import ActivityKit

/// Starts the activity when a bake starts, updates it on each change (door ajar, shut again,
/// ready) and ends it once the bake is out of the oven. The timer counts down on the device from
/// the stored end time, so nothing is sent while it runs.
@MainActor
public final class ActivityKitBakeActivity: BakeActivityPresenting {
    private var shown: BakeActivityAttributes.ContentState?
    /// False until the first call, which always acts: it ends an activity left over from an
    /// earlier launch when no bake is running.
    private var hasReflected = false
    private let logger = Logger(subsystem: "com.shubhamtyagi.cloche", category: "LiveActivity")

    public init() {}

    public func reflect(_ phase: SessionPhase) {
        let state = BakeActivityContent.state(for: phase)
        guard !hasReflected || state != shown || (state != nil && Activity<BakeActivityAttributes>.activities.isEmpty) else { return }
        hasReflected = true
        shown = state
        guard let state else {
            endAll()
            return
        }
        let content = ActivityContent(state: state, staleDate: state.staleDate)
        if Activity<BakeActivityAttributes>.activities.contains(where: { $0.activityState == .active }) {
            Task { await Self.updateActive(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.notice("Live Activities are off; skipping")
            return
        }
        do {
            _ = try Activity.request(attributes: BakeActivityAttributes(), content: content, pushType: nil)
            logger.notice("Live Activity started")
        } catch {
            logger.error("Live Activity not started: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func endAll() {
        Task { await Self.endAll() }
    }

    // `Activity` isn't Sendable, so each helper looks the activities up itself, off the main actor.

    private nonisolated static func updateActive(_ content: ActivityContent<BakeActivityAttributes.ContentState>) async {
        for activity in Activity<BakeActivityAttributes>.activities where activity.activityState == .active {
            await activity.update(content)
        }
    }

    private nonisolated static func endAll() async {
        for activity in Activity<BakeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
