import Domain

/// One report from the Duo's hinge, independent of UIKit so the mapping can be tested.
public struct HingeReading: Equatable, Sendable {
    public enum Status: String, Sendable {
        case unknown
        case closed
        case partiallyOpen
        case fullyOpen
    }

    public let status: Status
    /// As reported by UIKit; used for effects only, never layout.
    public let angle: Double

    public init(status: Status, angle: Double) {
        self.status = status
        self.angle = angle
    }

    /// PRD §6: half-open counts as ajar, never closed, so a tented phone can't cheat the
    /// timer. Unknown is treated as open.
    public var doorState: DoorState {
        switch status {
        case .closed: .closed
        case .partiallyOpen: .ajar
        case .fullyOpen, .unknown: .open
        }
    }
}
