import DesignSystem
import SwiftUI

/// Explains the one notification before the system asks (Guideline 4.5.4). Either answer
/// continues to Preheat; the app works fully without notifications.
struct NotificationPrePrompt: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(spacing: Spacing.margin) {
            Image(systemName: "bell")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.sand)
                .accessibilityHidden(true)
            Text("A nudge when it's ready", bundle: .module)
                .textStyle(.title.sized(32, lineHeight: 36))
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("With the phone face down you won't see the screen. One notification tells you the bake is done. Nothing else, ever.", bundle: .module)
                .textStyle(.body)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onAllow) {
                Text("Allow notifications", bundle: .module)
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("notifications.allow")
            Button(action: onNotNow) {
                Text("Not now", bundle: .module)
            }
            .buttonStyle(.text)
            .accessibilityIdentifier("notifications.notNow")
        }
        .padding(Spacing.margin)
        .padding(.top, Spacing.margin)
        .pocketScreenBackground()
        .presentationDetents([.medium])
    }
}
