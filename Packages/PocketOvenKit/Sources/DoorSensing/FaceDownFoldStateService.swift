#if canImport(CoreMotion)
import CoreMotion
import Domain
import Observation

/// Door for iPhones without a hinge: shut when the phone lies face down and flat.
/// Uses device motion (gravity), which needs no permission prompt.
@MainActor
@Observable
public final class FaceDownFoldStateService: FoldStateService {
    public let source: DoorSource = .faceDown
    /// Latest gravity z, for the debug readout.
    public private(set) var gravityZ: Double?

    /// False in the simulator, which has no motion sensors.
    public var isAvailable: Bool { motion.isDeviceMotionAvailable }

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var detector = FaceDownDetector()
    @ObservationIgnored private let broadcaster = DoorStateBroadcaster()

    public init() {}

    public func doorStates() -> AsyncStream<DoorState> {
        broadcaster.stream()
    }

    /// Sensors run only while a bake needs them, to save battery.
    public func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            MainActor.assumeIsolated {
                self?.receive(gravityZ: data.gravity.z, at: data.timestamp)
            }
        }
    }

    public func stop() {
        motion.stopDeviceMotionUpdates()
    }

    private func receive(gravityZ: Double, at time: TimeInterval) {
        self.gravityZ = gravityZ
        broadcaster.send(detector.update(gravityZ: gravityZ, at: time))
    }
}
#endif
