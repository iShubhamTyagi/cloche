import Domain
import Foundation

/// Decides "face down on a flat surface" from the gravity vector's z component
/// (+1 when the screen faces the floor). Pure, so it can be tested without a device.
public struct FaceDownDetector: Sendable {
    public struct Thresholds: Sendable {
        /// About 23° from flat. A tilted book or a soft sofa stays below this.
        public var closeAtZ: Double = 0.92
        /// Lower than `closeAtZ` so small wobbles don't toggle the door.
        public var openBelowZ: Double = 0.80
        /// How long the phone must stay flat and face down before the door counts as shut.
        public var settleSeconds: TimeInterval = 0.8

        public init() {}
    }

    public private(set) var state: DoorState = .open
    private let thresholds: Thresholds
    private var flatSince: TimeInterval?

    public init(thresholds: Thresholds = Thresholds()) {
        self.thresholds = thresholds
    }

    /// - Parameters:
    ///   - gravityZ: `CMDeviceMotion.gravity.z`.
    ///   - time: a monotonic timestamp in seconds, such as `CMDeviceMotion.timestamp`.
    public mutating func update(gravityZ: Double, at time: TimeInterval) -> DoorState {
        if state == .closed {
            if gravityZ < thresholds.openBelowZ {
                state = .open
                flatSince = nil
            }
            return state
        }

        guard gravityZ >= thresholds.closeAtZ else {
            flatSince = nil
            return state
        }
        if let flatSince {
            if time - flatSince >= thresholds.settleSeconds { state = .closed }
        } else {
            flatSince = time
        }
        return state
    }
}
