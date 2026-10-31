import Foundation

/// Formats remaining time the way every timer in the app shows it: minutes and seconds,
/// rounded up so the display reads "0:00" only when time is really up.
public enum CountdownFormat {
    /// "24:59", "4:12", "0:05". A 90-minute bake reads "90:00".
    public static func clock(_ remaining: TimeInterval) -> String {
        let total = wholeSecondsRemaining(remaining)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// Bare seconds for short countdowns such as the 15 s door-ajar grace: "15", "3", "0".
    public static func seconds(_ remaining: TimeInterval) -> String {
        String(wholeSecondsRemaining(remaining))
    }

    static func wholeSecondsRemaining(_ remaining: TimeInterval) -> Int {
        guard remaining.isFinite, remaining > 0 else { return 0 }
        return Int(remaining.rounded(.up))
    }
}
