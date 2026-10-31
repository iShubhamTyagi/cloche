import Domain

/// Plays back a fixed sequence of door states. Used by tests and the debug menu,
/// because the simulator's Duo posture is switched by hand and can't be scripted.
public struct ScriptedFoldStateService: FoldStateService {
    public struct Step: Sendable, Equatable {
        public let state: DoorState
        public let delay: Duration

        public init(_ state: DoorState, after delay: Duration = .zero) {
            self.state = state
            self.delay = delay
        }
    }

    public let source: DoorSource
    private let steps: [Step]

    public init(source: DoorSource = .faceDown, steps: [Step]) {
        self.source = source
        self.steps = steps
    }

    public func doorStates() -> AsyncStream<DoorState> {
        let steps = steps
        return AsyncStream { continuation in
            let task = Task {
                for step in steps {
                    if step.delay > .zero {
                        try? await Task.sleep(for: step.delay)
                    }
                    guard !Task.isCancelled else { break }
                    continuation.yield(step.state)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
