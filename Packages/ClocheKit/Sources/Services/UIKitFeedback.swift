#if canImport(UIKit)
import UIKit

/// Haptics through UIKit's feedback generators. They do nothing where the hardware is absent.
@MainActor
public final class UIKitHaptics: HapticPlaying {
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)

    public init() {}

    public func play(_ haptic: Haptic) {
        switch haptic {
        case .doorLatch: rigid.impactOccurred(intensity: 0.8)
        case .doorThunk: heavy.impactOccurred()
        case .softThud: soft.impactOccurred(intensity: 0.7)
        }
    }
}

@MainActor
public final class VoiceOverAnnouncer: Announcing {
    public init() {}

    public func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
#endif
