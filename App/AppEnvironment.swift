import DoorSensing
import Domain
import Features
import Foundation
import Persistence
import Services

/// Composition root: the only place concrete services are created and wired together.
@MainActor
final class AppEnvironment {
    let doorSensor: AdaptiveDoorSensor
    let session: SessionController
    let debug: DebugOptions

    init() {
        debug = DebugOptions(
            showsComponentGallery: LaunchArguments.contains("-componentGallery"),
            showsDoorReadout: LaunchArguments.contains("-doorDebug")
        )
        doorSensor = AdaptiveDoorSensor()

        let store: any SessionSnapshotStoring
        if LaunchArguments.contains("-freshSession") {
            // UI tests start from a clean Prep screen.
            store = InMemorySessionSnapshotStore()
        } else if let file = try? FileSessionSnapshotStore.standard() {
            store = file
        } else {
            store = InMemorySessionSnapshotStore()
        }

        session = SessionController(door: doorSensor, time: SystemTimeProvider(), store: store, effects: SessionEffectRouter())
    }
}

/// Debug switches passed by scripts/run.sh and the UI tests.
private enum LaunchArguments {
    static func contains(_ flag: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }
}
