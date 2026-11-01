import BakeActivityUI
import SwiftUI
import WidgetKit

/// The widget extension: only the bake's Live Activity (lock screen, Dynamic Island and the
/// Apple Watch Smart Stack). All drawing lives in the package.
@main
struct ClocheWidgets: WidgetBundle {
    var body: some Widget {
        BakeLiveActivity()
    }
}
