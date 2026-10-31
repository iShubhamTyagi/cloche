import Foundation

/// Hinge angle to door art. UIKit reports the hinge in radians: π when the Duo lies flat,
/// 0 when shut. The oven door lies flat when the phone is open and lifts as it folds.
enum DoorGeometry {
    /// Degrees the door is lifted off flat: 0 flat open, 180 shut over the oven.
    static func liftDegrees(hingeAngle: Double) -> Double {
        guard hingeAngle.isFinite else { return 0 }
        let clamped = min(max(hingeAngle, 0), .pi)
        return (Double.pi - clamped) * 180 / .pi
    }

    /// The handoff draws the ajar door at 34° when no hinge reading is available.
    static let defaultAjarLift: Double = 34
}
