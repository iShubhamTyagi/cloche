import Foundation

/// The turntable: the brass collar starts and stops it, with an eased (constant-acceleration)
/// spin-up and spin-down. Its angle is a pure function of the start/stop events, so a replay or
/// a time-lapse turns it exactly as it turned.
public struct Turntable: Equatable, Sendable {
    public struct Event: Equatable, Sendable {
        public var time: Double
        public var spinning: Bool
        /// Revolutions per second when spinning.
        public var speed: Double
    }

    /// Speeds offered by the speed setting (revolutions per second).
    public static let speeds: [Double] = [0.12, 0.2, 0.32]
    /// Seconds to reach full speed or to stop.
    public static let ramp: Double = 0.6

    public private(set) var events: [Event] = []

    public init() {}

    public var isSpinning: Bool { events.last?.spinning ?? false }

    public mutating func toggle(at time: Double, speed: Double) {
        events.append(Event(time: time, spinning: !isSpinning, speed: speed))
    }

    public mutating func setSpeed(_ speed: Double, at time: Double) {
        guard isSpinning else { return }
        events.append(Event(time: time, spinning: true, speed: speed))
    }

    /// Angular velocity (rad/s) and angle (rad) at `time`.
    public func state(at time: Double) -> (angle: Double, velocity: Double) {
        var angle = 0.0, velocity = 0.0, now = events.first?.time ?? time
        for (i, event) in events.enumerated() where event.time <= time {
            // Advance from `now` to this event at the current (ramping) state.
            (angle, velocity) = Self.advance(angle: angle, velocity: velocity, target: Self.target(events, before: i),
                                             duration: event.time - now)
            now = event.time
        }
        let target = events.last(where: { $0.time <= time }).map { $0.spinning ? $0.speed * 2 * .pi : 0 } ?? 0
        return Self.advance(angle: angle, velocity: velocity, target: target, duration: max(time - now, 0))
    }

    public func angle(at time: Double) -> Double { state(at: time).angle }

    /// Rotates a world-space point (mm, about the plate's Z axis) into plate-local coordinates.
    public func toPlate(_ p: SIMD3<Float>, at time: Double) -> SIMD3<Float> {
        let a = Float(-angle(at: time))
        return SIMD3(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a), p.z)
    }

    private static func target(_ events: [Event], before index: Int) -> Double {
        guard index > 0 else { return 0 }
        let e = events[index - 1]
        return e.spinning ? e.speed * 2 * .pi : 0
    }

    /// Constant acceleration toward `target` (reached in `ramp` from rest at the top speed),
    /// then constant velocity.
    static func advance(angle: Double, velocity: Double, target: Double, duration: Double) -> (Double, Double) {
        guard duration > 0 else { return (angle, velocity) }
        let accel = max(speeds.max() ?? 1, 0.01) * 2 * .pi / ramp
        let gap = target - velocity
        let rampTime = min(abs(gap) / accel, duration)
        let a = gap >= 0 ? accel : -accel
        let v1 = velocity + a * rampTime
        let rampAngle = velocity * rampTime + 0.5 * a * rampTime * rampTime
        return (angle + rampAngle + v1 * (duration - rampTime), v1)
    }
}
