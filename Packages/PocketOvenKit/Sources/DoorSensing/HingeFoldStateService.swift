#if canImport(UIKit)
import Domain
import Observation
import os
import UIKit

/// What the adaptive sensor needs from the hinge adapter, without naming the iOS 27.1 type.
@MainActor
protocol HingeSensing: FoldStateService {
    var reading: HingeReading? { get }
    var hasReported: Bool { get }
    func attach(to view: UIView)
}

/// Reads the iPhone Duo hinge through `UIHingeInteraction`. On iPhones without a hinge the
/// update's hinge is nil, which reports as open and lets the face-down sensor take over.
@available(iOS 27.1, *)
@MainActor
@Observable
final class HingeFoldStateService: HingeSensing {
    let source: DoorSource = .hinge
    /// Latest hinge report; nil means this device has no hinge (or none reported yet).
    private(set) var reading: HingeReading?
    private(set) var hasReported = false

    @ObservationIgnored private let broadcaster = DoorStateBroadcaster()
    @ObservationIgnored private var interaction: UIHingeInteraction?
    /// Gate 0: records what the hinge reports during slow opens and closes.
    @ObservationIgnored private let logger = Logger(subsystem: "com.shubhamtyagi.pocketoven", category: "Hinge")

    init() {
        interaction = UIHingeInteraction { [weak self] _, update in
            MainActor.assumeIsolated {
                self?.receive(update.hinge.map { HingeReading($0) })
            }
        }
    }

    func attach(to view: UIView) {
        guard let interaction, interaction.view !== view else { return }
        view.addInteraction(interaction)
    }

    func doorStates() -> AsyncStream<DoorState> {
        broadcaster.stream()
    }

    func receive(_ reading: HingeReading?) {
        if let reading {
            logger.notice("hinge status=\(reading.status.rawValue, privacy: .public) angle=\(reading.angle, privacy: .public)")
        } else {
            logger.notice("hinge none")
        }
        hasReported = true
        self.reading = reading
        broadcaster.send(reading?.doorState ?? .open)
    }
}

@available(iOS 27.1, *)
extension HingeReading {
    @MainActor
    init(_ hinge: UIHinge) {
        let status: Status = switch hinge.status {
        case .closed: .closed
        case .partiallyOpen: .partiallyOpen
        case .fullyOpen: .fullyOpen
        case .unknown: .unknown
        @unknown default: .unknown
        }
        self.init(status: status, angle: Double(hinge.angle))
    }
}
#endif
