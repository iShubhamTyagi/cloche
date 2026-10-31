import DoorSensing
import Domain
import Foundation
import Observation
import os

/// Drives `SessionEngine` with real inputs: door states, the clock and app lifecycle.
/// Saves after every change and wakes itself at the engine's next deadline.
@MainActor
@Observable
public final class SessionController {
    public private(set) var engine: SessionEngine

    public var phase: SessionPhase { engine.phase }
    public var doorSource: DoorSource { door.source }

    @ObservationIgnored private let door: any FoldStateService
    @ObservationIgnored private let time: any TimeProviding
    @ObservationIgnored private let store: any SessionSnapshotStoring
    @ObservationIgnored private let effects: any SessionEffectPerforming
    @ObservationIgnored private var doorTask: Task<Void, Never>?
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.shubhamtyagi.pocketoven", category: "Session")

    public init(door: any FoldStateService, time: any TimeProviding, store: any SessionSnapshotStoring, effects: any SessionEffectPerforming) {
        self.door = door
        self.time = time
        self.store = store
        self.effects = effects
        do {
            engine = try store.load() ?? SessionEngine()
        } catch {
            logger.error("Could not restore session: \(error.localizedDescription, privacy: .public)")
            engine = SessionEngine()
        }
        listenToDoor()
        // Settle anything that came due while the app was away.
        send(.tick)
    }

    public func preheat(_ recipe: Recipe, temperature: Temperature, isDemo: Bool = false) {
        send(.preheat(BakeRequest(recipe: recipe, temperature: temperature, source: door.source, isDemo: isDemo)))
    }

    public func send(_ event: SessionEvent) {
        let produced = engine.handle(event, now: time.now)
        do {
            try store.save(engine)
        } catch {
            logger.error("Could not save session: \(error.localizedDescription, privacy: .public)")
        }
        effects.perform(produced)
        scheduleNextDeadline()
    }

    private func listenToDoor() {
        let states = door.doorStates()
        doorTask = Task { [weak self] in
            for await state in states {
                self?.send(.door(state))
            }
        }
    }

    private func scheduleNextDeadline() {
        deadlineTask?.cancel()
        guard let deadline = engine.nextDeadline else { return }
        let delay = max(0, deadline.timeIntervalSince(time.now))
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.send(.tick)
        }
    }
}
