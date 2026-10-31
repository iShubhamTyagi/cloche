#if canImport(UIKit)
import UIKit

/// Keeps the screen from auto-locking while a bake runs (DR-3).
@MainActor
public protocol ScreenAwakeControlling: AnyObject {
    var keepsScreenAwake: Bool { get set }
}

/// Uses the idle timer only; it never changes brightness or other system settings (2.5.9).
@MainActor
public final class IdleTimerScreenAwake: ScreenAwakeControlling {
    public init() {}

    public var keepsScreenAwake: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}
#endif
