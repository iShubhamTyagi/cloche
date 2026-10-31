import DoorSensing
import Foundation
import Features

/// Composition root: the only place concrete services are created and wired together.
@MainActor
final class AppEnvironment {
    let doorSensor = AdaptiveDoorSensor()

    let debug = DebugOptions(
        showsComponentGallery: LaunchArguments.contains("-componentGallery"),
        showsDoorReadout: LaunchArguments.contains("-doorDebug")
    )
}

/// Debug switches passed by scripts/run.sh and the UI tests. Ignored by release builds.
private enum LaunchArguments {
    static func contains(_ flag: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }
}
