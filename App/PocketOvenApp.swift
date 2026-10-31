import Features
import SwiftUI

@main
struct PocketOvenApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView(showsComponentGallery: LaunchOptions.showsComponentGallery)
                .preferredColorScheme(.dark)
                // Handoff: helper text, tabs, chips and buttons scale to about 130%.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}

/// Debug switches passed as launch arguments by scripts/run.sh and UI tests.
private enum LaunchOptions {
    static var showsComponentGallery: Bool {
        ProcessInfo.processInfo.arguments.contains("-componentGallery")
    }
}
