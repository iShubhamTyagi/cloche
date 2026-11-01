import DesignSystem
import SwiftUI

/// A quiet text button that works the oven door by hand, for when the phone can't be turned
/// face down (the simulator, or a player who'd rather not).
struct ManualDoorButton: View {
    let title: Text
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            title
        }
        .buttonStyle(.text)
        .accessibilityIdentifier(identifier)
    }
}
