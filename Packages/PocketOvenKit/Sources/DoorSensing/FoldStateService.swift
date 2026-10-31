import Domain

/// The single "is the door closed?" signal. Every door mode conforms to it, and the
/// session engine never knows which one it has (PL-1).
@MainActor
public protocol FoldStateService: AnyObject {
    var source: DoorSource { get }

    /// Emits the current state first (if known), then every change.
    func doorStates() -> AsyncStream<DoorState>
}
