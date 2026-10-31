import Domain

/// The single "is the door closed?" signal. Every door mode conforms to it, and the
/// session engine never knows which one it has (PL-1).
public protocol FoldStateService: Sendable {
    var source: DoorSource { get }

    /// Emits the current state first, then every change.
    func doorStates() -> AsyncStream<DoorState>
}
