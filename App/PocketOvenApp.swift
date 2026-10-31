import Features
import SwiftUI

@main
struct PocketOvenApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            AppRootView(session: environment.session, doorSensor: environment.doorSensor, debug: environment.debug)
                .preferredColorScheme(.dark)
                // Handoff: helper text, tabs, chips and buttons scale to about 130%.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}
