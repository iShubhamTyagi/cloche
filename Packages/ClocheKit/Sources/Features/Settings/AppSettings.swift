import DoorSensing
import Foundation
import Observation

/// The player's settings, kept in UserDefaults (privacy manifest reason CA92.1).
@MainActor
@Observable
public final class AppSettings {
    private enum Key {
        static let keepsScreenAwake = "keepsScreenAwake"
        static let soundsOn = "soundsOn"
        static let doorMode = "doorMode"
        static let hasAskedForNotifications = "hasAskedForNotifications"
    }

    /// DR-3: on by default.
    public var keepsScreenAwake: Bool {
        didSet { defaults.set(keepsScreenAwake, forKey: Key.keepsScreenAwake) }
    }

    /// BK-7: oven sounds can be muted; the silent switch always wins.
    public var soundsOn: Bool {
        didSet { defaults.set(soundsOn, forKey: Key.soundsOn) }
    }

    /// DR-8: Duo owners can choose face-down.
    public var doorMode: DoorModePreference {
        didSet { defaults.set(doorMode.rawValue, forKey: Key.doorMode) }
    }

    /// The notification pre-prompt is shown once, on the first Preheat.
    public var hasAskedForNotifications: Bool {
        didSet { defaults.set(hasAskedForNotifications, forKey: Key.hasAskedForNotifications) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.keepsScreenAwake: true, Key.soundsOn: true])
        keepsScreenAwake = defaults.bool(forKey: Key.keepsScreenAwake)
        soundsOn = defaults.bool(forKey: Key.soundsOn)
        doorMode = defaults.string(forKey: Key.doorMode).flatMap(DoorModePreference.init(rawValue:)) ?? .automatic
        hasAskedForNotifications = defaults.bool(forKey: Key.hasAskedForNotifications)
    }
}
