import Foundation

/// OLED burn-in guard for screens left on during a bake: content moves a few points in small
/// steps, too slowly to read as motion (handoff motion table; kept under Reduce Motion).
public enum BurnInDrift {
    /// Vertical offset at `date`: a triangle wave across `range` points over `period` seconds,
    /// moved in whole `step`-point increments.
    public static func offset(at date: Date, period: TimeInterval, range: Double, step: Double = 2) -> Double {
        guard period > 0, range > 0 else { return 0 }
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        let raw = triangle * range - range / 2
        return (raw / step).rounded() * step
    }
}
