import DoorSensing
import os
import Services
import SwiftUI

extension EnvironmentValues {
    /// The folded Duo's cover is what's on screen: lay out for the sideways cover (`CoverDisplay`).
    @Entry var isOnCover = false
    /// The open Duo's hinge angle in degrees (0 shut, 180 flat open), for the oven door to follow
    /// as the phone folds and unfolds. Nil on phones without a hinge: the door then follows the
    /// screen's own `doorOpen`. An effect only, never layout (CLAUDE.md).
    @Entry var hingeDoorAngle: Double?
    /// The content is laid on the open oven door's glass (the open Duo): screens tighten their
    /// spacing to fit it.
    @Entry var isOnDoorGlass = false
    /// How hot the oven's tubes look, 0 cold (black rods) to 1 glowing. The app preheats from 0
    /// to 1 over the first seconds after launch (`AppRootView`); visual only.
    @Entry var ovenHeat: Double = 1
    /// The oven door's thud and haptic on shutting, fed with door angles.
    @Entry var doorFeedback: OvenDoorFeedback?
}

/// Which screen the folded Duo is showing, decided from two signals.
///
/// The hinge alone isn't enough: launched while folded, the simulator's first hinge report has
/// been `fullyOpen`, which put the open portrait layout on the sideways cover. The window can't
/// be wrong about its own size: on a phone with a hinge, a window narrower than the inner screen
/// (cover 466 pt wide, inner 669 pt) is the cover.
enum FoldSignal {
    /// Narrower than the Duo's inner screen and wider than any cover.
    static let coverMaxWidth: CGFloat = 560
    /// Within this many degrees of shut (20: the inner screen is all but closed) the inner screen can't be seen any more: switch to the
    /// cover's layout already, so it is drawn before the system moves the window to the cover.
    static let preCloseDegrees = 20.0
    /// Fold timing: hinge reports (category Hinge), the window moving between screens, and
    /// the layout switching. Read with `log show --predicate 'subsystem == "com.shubhamtyagi.cloche"'`.
    static let log = Logger(subsystem: "com.shubhamtyagi.cloche", category: "Fold")

    @MainActor
    static func isOnCover(sensor: AdaptiveDoorSensor, windowWidth: CGFloat) -> Bool {
        if let reading = sensor.hingeReading {
            if reading.status == .closed { return true }
            if reading.status == .partiallyOpen, reading.angle * 180 / .pi <= preCloseDegrees { return true }
        }
        return sensor.hingePresent && windowWidth > 0 && windowWidth < coverMaxWidth
    }

    /// The hinge angle in degrees while the Duo is open, nil otherwise.
    @MainActor
    static func doorAngle(sensor: AdaptiveDoorSensor, isOnCover: Bool) -> Double? {
        guard !isOnCover, let reading = sensor.hingeReading else { return nil }
        return min(max(reading.angle * 180 / .pi, 0), 180)
    }
}
