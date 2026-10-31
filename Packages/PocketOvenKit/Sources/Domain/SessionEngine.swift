import Foundation

/// Where the session is. Codable so it survives force-quit and is restored on relaunch.
public enum SessionPhase: Codable, Equatable, Sendable {
    case idle
    /// Preheated; waiting for the door to close.
    case armed(Bake)
    case baking(Bake)
    /// Door opened mid-bake. The bake keeps going; if the door stays open past the grace,
    /// the bake ends half-baked at the moment it was opened.
    case ajar(Bake, openedAt: Date, graceEndsAt: Date)
    /// Finished and keeping warm, with no penalty however long the player keeps working.
    case ready(Bake)
    /// Out of the oven; the grade card is showing.
    case graded(BakeOutcome)
    case decorating(BakeOutcome, breakEndsAt: Date)
    case served(BakeOutcome, Grade)
}

public enum SessionEvent: Equatable, Sendable {
    case preheat(BakeRequest)
    case cancelPreheat
    case door(DoorState)
    /// A deadline may have passed (timer fired, app relaunched, returned to foreground).
    case tick
    case decorate
    case servePlain
    case serveNow
    case done
}

public enum SessionNotification: String, Codable, Sendable {
    case bakeReady
    case breakOver
}

/// Moments that get a sound, haptic or VoiceOver announcement.
public enum SessionCue: Equatable, Sendable {
    case bakeStarted
    case doorAjar
    case bakeResumed
    case bakeReady
    case bakeEndedEarly
    case doorOpened
    case served(stars: Int)
}

/// Work the engine asks the outside world to do. The engine itself does no I/O.
public enum SessionEffect: Equatable, Sendable {
    case scheduleNotification(SessionNotification, at: Date)
    case cancelNotification(SessionNotification)
    case cue(SessionCue)
}

/// The prep → bake → reveal → break → serve state machine (PRD §5). Pure and deterministic:
/// callers pass the current time with every event and carry out the returned effects.
public struct SessionEngine: Codable, Equatable, Sendable {
    public static let graceDuration: TimeInterval = 15

    public private(set) var phase: SessionPhase = .idle
    /// Last door state reported by the sensor.
    public private(set) var door: DoorState = .open

    public init() {}

    /// When the next `.tick` must be sent, if anything is waiting on time.
    public var nextDeadline: Date? {
        switch phase {
        case let .baking(bake):
            bake.endsAt
        case let .ajar(bake, _, graceEndsAt):
            min(graceEndsAt, bake.endsAt ?? graceEndsAt)
        case let .decorating(_, breakEndsAt):
            breakEndsAt
        case .idle, .armed, .ready, .graded, .served:
            nil
        }
    }

    public mutating func handle(_ event: SessionEvent, now: Date) -> [SessionEffect] {
        // Settle anything already due before reacting, so the order of events is always right.
        var effects = advance(to: now)

        switch (phase, event) {
        case let (.idle, .preheat(request)):
            phase = .armed(Bake(request))
            if door == .closed { effects += startBake(now: now) }

        case (.armed, .cancelPreheat):
            phase = .idle

        case let (_, .door(state)):
            door = state
            effects += doorChanged(now: now)

        case let (.graded(outcome), .decorate):
            let breakEndsAt = now.addingTimeInterval(outcome.bake.breakDuration)
            phase = .decorating(outcome, breakEndsAt: breakEndsAt)
            effects.append(.scheduleNotification(.breakOver, at: breakEndsAt))

        case let (.graded(outcome), .servePlain):
            effects += serve(outcome, decorated: false)

        case let (.decorating(outcome, _), .serveNow):
            effects.append(.cancelNotification(.breakOver))
            effects += serve(outcome, decorated: true)

        case (.served, .done):
            phase = .idle

        default:
            // Events that don't apply to the current phase are ignored, e.g. decorate without a bake.
            break
        }
        return effects
    }

    // MARK: - Transitions

    private mutating func doorChanged(now: Date) -> [SessionEffect] {
        switch phase {
        case .armed where door == .closed:
            return startBake(now: now)

        case let .baking(bake) where door != .closed:
            phase = .ajar(bake, openedAt: now, graceEndsAt: now.addingTimeInterval(Self.graceDuration))
            return [.cue(.doorAjar)]

        case let .ajar(bake, _, _) where door == .closed:
            phase = .baking(bake)
            return [.cue(.bakeResumed)]

        case let .ready(bake) where door == .open:
            // A partly open Duo (ajar) waits; the reveal needs the door fully open.
            phase = .graded(BakeOutcome(bake: bake, doneness: 1))
            return [.cue(.doorOpened)]

        default:
            return []
        }
    }

    private mutating func startBake(now: Date) -> [SessionEffect] {
        guard case let .armed(bake) = phase else { return [] }
        let started = bake.started(at: now)
        phase = .baking(started)
        guard let endsAt = started.endsAt else { return [] }
        return [.scheduleNotification(.bakeReady, at: endsAt), .cue(.bakeStarted)]
    }

    private mutating func serve(_ outcome: BakeOutcome, decorated: Bool) -> [SessionEffect] {
        let grade = GradeCalculator.grade(outcome, served: decorated)
        phase = .served(outcome, grade)
        return [.cue(.served(stars: grade.stars))]
    }

    /// Applies every deadline that has passed by `now`, earliest first.
    private mutating func advance(to now: Date) -> [SessionEffect] {
        var effects: [SessionEffect] = []
        while let deadline = nextDeadline, deadline <= now {
            effects += fire(deadline: deadline)
        }
        return effects
    }

    private mutating func fire(deadline: Date) -> [SessionEffect] {
        switch phase {
        case let .baking(bake):
            return finish(bake)

        case let .ajar(bake, openedAt, graceEndsAt):
            if let endsAt = bake.endsAt, endsAt <= graceEndsAt {
                // The timer ran out during the grace: the bake is done, no penalty.
                return finish(bake)
            }
            phase = .graded(BakeOutcome(bake: bake, doneness: bake.doneness(openedAt: openedAt)))
            return [.cancelNotification(.bakeReady), .cue(.bakeEndedEarly)]

        case let .decorating(outcome, _):
            // Auto-serve when the break clock runs out (DC-2).
            return serve(outcome, decorated: true)

        case .idle, .armed, .ready, .graded, .served:
            assertionFailure("No deadline in this phase")
            return []
        }
    }

    private mutating func finish(_ bake: Bake) -> [SessionEffect] {
        phase = .ready(bake)
        var effects: [SessionEffect] = [.cue(.bakeReady)]
        if door == .open {
            phase = .graded(BakeOutcome(bake: bake, doneness: 1))
            effects.append(.cue(.doorOpened))
        }
        return effects
    }
}
