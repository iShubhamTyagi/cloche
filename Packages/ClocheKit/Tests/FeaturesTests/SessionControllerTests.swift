import DoorSensing
import Domain
@testable import Features
import Foundation
import Persistence
import Testing

final class TestTimeProvider: TimeProviding, @unchecked Sendable {
    var now: Date

    init(_ now: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        self.now = now
    }
}

@MainActor
final class RecordingEffects: SessionEffectPerforming {
    private(set) var performed: [SessionEffect] = []

    func perform(_ effects: [SessionEffect]) {
        performed += effects
    }
}

/// A door the test opens and closes by hand.
@MainActor
final class ManualDoor: FoldStateService {
    let source: DoorSource = .faceDown
    private var continuation: AsyncStream<DoorState>.Continuation?

    func doorStates() -> AsyncStream<DoorState> {
        let (stream, continuation) = AsyncStream.makeStream(of: DoorState.self)
        self.continuation = continuation
        return stream
    }

    func set(_ state: DoorState) {
        continuation?.yield(state)
    }
}

@MainActor
struct SessionControllerTests {
    private let recipe = StarterRecipes.vanillaCupcakes

    @Test func preheatThenClosingTheDoorStartsTheBakeAndSavesIt() async throws {
        let door = ManualDoor()
        let time = TestTimeProvider()
        let store = InMemorySessionSnapshotStore()
        let effects = RecordingEffects()
        let session = SessionController(door: door, time: time, store: store, effects: effects)

        session.preheat(recipe, length: .quick)
        #expect(session.phase.isArmed)

        door.set(.closed)
        try await waitUntil { session.phase.isBaking }

        #expect(try store.load() == session.engine)
        #expect(effects.performed.contains(.cue(.bakeStarted)))
        #expect(effects.performed.contains(.scheduleNotification(.bakeReady, at: time.now.addingTimeInterval(1500))))
    }

    @Test func restoresASavedBakeAndCatchesUpOnTimeThatPassed() throws {
        let time = TestTimeProvider()
        var saved = SessionEngine()
        _ = saved.handle(.preheat(BakeRequest(recipe: recipe, length: .quick, source: .faceDown)), now: time.now)
        _ = saved.handle(.door(.closed), now: time.now)

        // Relaunch two hours later.
        time.now = time.now.addingTimeInterval(7200)
        let session = SessionController(door: ManualDoor(), time: time, store: InMemorySessionSnapshotStore(saved), effects: RecordingEffects())

        if case .ready = session.phase {} else {
            Issue.record("Expected ready, got \(session.phase)")
        }
    }

    @Test func backFromPreheatReturnsToPrep() {
        let session = SessionController(door: ManualDoor(), time: TestTimeProvider(), store: InMemorySessionSnapshotStore(), effects: RecordingEffects())
        session.preheat(recipe, length: .quick)
        session.send(.cancelPreheat)
        #expect(session.phase == .idle)
    }

    @Test func preheatRecordsTheActiveDoorSource() {
        let session = SessionController(door: ManualDoor(), time: TestTimeProvider(), store: InMemorySessionSnapshotStore(), effects: RecordingEffects())
        session.preheat(recipe, length: .quick)
        if case let .armed(bake) = session.phase {
            #expect(bake.source == .faceDown)
        } else {
            Issue.record("Expected armed")
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }
}

extension SessionPhase {
    var isArmed: Bool { if case .armed = self { true } else { false } }
    var isBaking: Bool { if case .baking = self { true } else { false } }
}
