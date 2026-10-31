import DoorSensing
import Domain
import Features
import Foundation
import Persistence
import Services

/// Composition root: the only place concrete services are created and wired together.
@MainActor
final class AppEnvironment {
    let dependencies: FeatureDependencies
    let debug: DebugOptions

    init() {
        debug = DebugOptions(
            showsComponentGallery: LaunchArguments.contains("-componentGallery"),
            showsDoorReadout: LaunchArguments.contains("-doorDebug")
        )

        let isFresh = LaunchArguments.contains("-freshSession")
        let store: any SessionSnapshotStoring
        let settings: AppSettings
        if isFresh {
            // UI tests start from a clean Prep screen with default settings. The notification
            // pre-prompt is skipped unless a test asks for it with -notificationPrompt.
            store = InMemorySessionSnapshotStore()
            let defaults = UserDefaults(suiteName: "ui-test-\(UUID().uuidString)") ?? .standard
            settings = AppSettings(defaults: defaults)
            settings.hasAskedForNotifications = !LaunchArguments.contains("-notificationPrompt")
        } else {
            store = (try? FileSessionSnapshotStore.standard()) ?? InMemorySessionSnapshotStore()
            settings = AppSettings()
        }

        let doorSensor = AdaptiveDoorSensor()
        let notifications = UserNotificationScheduler()
        let router = SessionEffectRouter(
            haptics: UIKitHaptics(),
            announcer: VoiceOverAnnouncer(),
            sounds: AVSoundPlayer(),
            notifications: notifications,
            soundsEnabled: { [settings] in settings.soundsOn }
        )
        let session = SessionController(door: doorSensor, time: SystemTimeProvider(), store: store, effects: router)

        dependencies = FeatureDependencies(
            session: session,
            doorSensor: doorSensor,
            settings: settings,
            screenAwake: IdleTimerScreenAwake(),
            notifications: notifications
        )
    }
}

/// Debug switches passed by scripts/run.sh and the UI tests.
private enum LaunchArguments {
    static func contains(_ flag: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }
}
