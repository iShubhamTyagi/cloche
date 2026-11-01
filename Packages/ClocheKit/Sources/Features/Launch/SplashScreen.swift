import DesignSystem
import SwiftUI

/// Shown for a moment on every cold launch, before Prep. Deliberately empty for now: just the
/// ground colour, so it hands off seamlessly from the system launch screen. Art comes later.
struct SplashScreen: View {
    /// How long the splash stays before the main screen fades in.
    static let duration: Duration = .seconds(1)

    var body: some View {
        Color.clear
            .pocketScreenBackground()
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .accessibilityIdentifier("splash")
    }
}

#Preview {
    SplashScreen()
}
