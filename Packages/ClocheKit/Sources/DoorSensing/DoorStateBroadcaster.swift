import Domain
import Foundation

/// Fans one sensor's door state out to any number of listeners. New listeners get the
/// current state straight away; repeated identical states are dropped.
@MainActor
final class DoorStateBroadcaster {
    private(set) var current: DoorState?
    private var continuations: [UUID: AsyncStream<DoorState>.Continuation] = [:]

    func stream() -> AsyncStream<DoorState> {
        let (stream, continuation) = AsyncStream.makeStream(of: DoorState.self, bufferingPolicy: .bufferingNewest(8))
        let id = UUID()
        continuations[id] = continuation
        if let current { continuation.yield(current) }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    func send(_ state: DoorState) {
        guard state != current else { return }
        current = state
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }
}
