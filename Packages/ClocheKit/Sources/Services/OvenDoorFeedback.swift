import Foundation

/// Sound and touch for the oven door as it moves, wherever the angle comes from (the iPhone's
/// swipe, the Duo's hinge). Feed it every angle; it plays a thud and a firm haptic when the door
/// comes back to shut from at least `thudFrom` open. (No opening sound: the owner removed the
/// creak, 2026-11-03.)
/// Sounds follow the player's Sounds setting; the audio session respects the silent switch.
@MainActor
public final class OvenDoorFeedback {
    public static let shutAngle = 1.5
    public static let thudFrom = 8.0

    private let sounds: any SoundPlaying
    private let haptics: any HapticPlaying
    private let soundsEnabled: () -> Bool
    private var lastAngle: Double?
    private var maxSinceShut = 0.0

    public init(sounds: any SoundPlaying, haptics: any HapticPlaying, soundsEnabled: @escaping () -> Bool) {
        self.sounds = sounds
        self.haptics = haptics
        self.soundsEnabled = soundsEnabled
    }

    /// The door's angle in degrees, 0 shut.
    public func doorMoved(to angle: Double) {
        defer { lastAngle = angle }
        guard let last = lastAngle else { return }        // the first reading only sets the state
        maxSinceShut = max(maxSinceShut, angle)
        if last > Self.shutAngle, angle <= Self.shutAngle {
            if maxSinceShut >= Self.thudFrom {
                if soundsEnabled() { sounds.play(.doorThud) }
                haptics.play(.doorLatch)
            }
            maxSinceShut = 0
        }
    }
}
