#if canImport(UIKit)
import Domain
import Observation
import UIKit

/// The one `FoldStateService` the app uses. It owns the hinge and face-down adapters,
/// picks the active one with `DoorModeResolver`, and forwards only that one's states.
@MainActor
@Observable
public final class AdaptiveDoorSensor: FoldStateService {
    public private(set) var source: DoorSource = .faceDown
    public private(set) var state: DoorState = .open
    public private(set) var hingePresent = false

    public var preference: DoorModePreference = .automatic {
        didSet { reselect() }
    }

    /// A door worked by hand: "Start without turning over" (and the debug readout in the
    /// simulator, where there is no face-down). Wins over the real sensors while set.
    public var manualOverride: DoorState? {
        didSet { forward() }
    }

    /// The player left the app mid-bake (home, another app, the app switcher). Leaving counts as
    /// opening the oven, so this wins over every sensor and the manual door while set.
    public var isAppAway = false {
        didSet { forward() }
    }

    public let faceDown: FaceDownFoldStateService
    public var hingeReading: HingeReading? { hinge?.reading }

    @ObservationIgnored private let hinge: (any HingeSensing)?
    @ObservationIgnored private let broadcaster = DoorStateBroadcaster()
    @ObservationIgnored private var latest: [DoorSource: DoorState] = [:]
    @ObservationIgnored private var listeners: [Task<Void, Never>] = []

    public init() {
        faceDown = FaceDownFoldStateService()
        if #available(iOS 27.1, *) {
            hinge = HingeFoldStateService()
        } else {
            hinge = nil
        }
        listen(to: faceDown)
        if let hinge { listen(to: hinge) }
        reselect()
    }

    public func doorStates() -> AsyncStream<DoorState> {
        broadcaster.stream()
    }

    /// The hinge interaction must live on a view in the window; see `HingeSensorAnchor`.
    func attachHinge(to view: UIView) {
        hinge?.attach(to: view)
    }

    private func listen(to sensor: any FoldStateService) {
        let source = sensor.source
        let stream = sensor.doorStates()
        listeners.append(Task { [weak self] in
            for await state in stream {
                guard let self else { return }
                self.latest[source] = state
                if source == .hinge {
                    self.hingePresent = self.hinge?.reading != nil
                    self.reselect()
                } else {
                    self.forward()
                }
            }
        })
    }

    private func reselect() {
        source = DoorModeResolver.source(hingePresent: hingePresent, preference: preference)
        if source == .faceDown { faceDown.start() } else { faceDown.stop() }
        forward()
    }

    private func forward() {
        var next = latest[source] ?? .open
        if let manualOverride { next = manualOverride }
        if isAppAway { next = .open }
        state = next
        broadcaster.send(next)
    }
}
#endif
