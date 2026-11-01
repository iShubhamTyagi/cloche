#if canImport(UIKit)
import DoorSensing
import Domain
import SwiftUI
import UIKit

/// Leaving the app mid-bake counts as opening the oven (owner's rule, 2026-11-01): going home,
/// to another app, or into the app switcher, Notification Centre or Control Centre. The usual
/// 15 s door-ajar grace applies, so coming back and closing the door in time keeps the bake.
///
/// Locking the phone does not count. iOS can't say "locked" at once, so leaving is treated as
/// opening straight away, and undone if the device reports its protected data going away (it
/// does about 10 s after a passcode-protected phone locks). A short background task keeps the app
/// awake to hear it. Without a passcode there is no such signal, and a lock counts as leaving.
@MainActor
final class AppAwayMonitor {
    private let sensor: AdaptiveDoorSensor
    private var leftDuringBake = false
    private var lockedWhileAway = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lockObserver: (any NSObjectProtocol)?

    init(sensor: AdaptiveDoorSensor) {
        self.sensor = sensor
        lockObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked() }
        }
    }

    /// `isBaking`: the bake is in the oven (baking or door ajar). Other phases are unaffected.
    func scenePhaseChanged(to phase: ScenePhase, isBaking: Bool) {
        switch phase {
        case .active:
            returned()
        case .inactive:
            if isBaking { left() }
        case .background:
            if isBaking || leftDuringBake {
                left()
                beginBackgroundWindow()
            }
        @unknown default:
            break
        }
    }

    private func left() {
        guard !lockedWhileAway else { return }
        leftDuringBake = true
        sensor.isAppAway = true
    }

    private func screenLocked() {
        guard leftDuringBake else { return }
        // It was a lock, not leaving: hand the door back to the real sensors.
        lockedWhileAway = true
        sensor.isAppAway = false
        endBackgroundWindow()
    }

    private func returned() {
        // A door worked by hand stays open after leaving; the player closes it to carry on.
        if leftDuringBake, !lockedWhileAway, sensor.manualOverride == .closed {
            sensor.manualOverride = .open
        }
        leftDuringBake = false
        lockedWhileAway = false
        sensor.isAppAway = false
        endBackgroundWindow()
    }

    private func beginBackgroundWindow() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Cloche.lockCheck") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundWindow() }
        }
    }

    private func endBackgroundWindow() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
#endif
