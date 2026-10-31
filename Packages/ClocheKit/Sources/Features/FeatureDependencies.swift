import DoorSensing
import Services

/// Everything the screens need, built once by the app's composition root.
@MainActor
public struct FeatureDependencies {
    public let session: SessionController
    public let doorSensor: AdaptiveDoorSensor
    public let settings: AppSettings
    public let screenAwake: any ScreenAwakeControlling
    public let notifications: any NotificationScheduling

    public init(session: SessionController, doorSensor: AdaptiveDoorSensor, settings: AppSettings, screenAwake: any ScreenAwakeControlling, notifications: any NotificationScheduling) {
        self.session = session
        self.doorSensor = doorSensor
        self.settings = settings
        self.screenAwake = screenAwake
        self.notifications = notifications
    }
}
