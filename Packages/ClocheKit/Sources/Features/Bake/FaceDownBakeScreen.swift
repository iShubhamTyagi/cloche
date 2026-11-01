import DesignSystem
import Domain
import SwiftUI

/// Board "3 Bake, face-down": pure black (OLED off), a dim countdown and a breathing line.
/// Nobody sees it while the phone is face down; it is what shows when the phone is turned over.
struct FaceDownBakeScreen: View {
    let recipe: Recipe
    let bake: Bake
    let isReady: Bool
    /// Opens the oven by hand when the bake was started without turning the phone over.
    var onOpen: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: Spacing.margin) {
                EyebrowLabel(bake.isDemo
                    ? Text("Demo · \(recipe.name)", bundle: .module)
                    : Text("\(recipe.name) · \(BakeLengthPicker.nameString(bake.length))", bundle: .module))
                if isReady {
                    Text("Prêt.", bundle: .module)
                        .textStyle(.hero)
                        .foregroundStyle(Palette.sand)
                        .accessibilityIdentifier("bake.ready")
                } else {
                    Text(CountdownFormat.clock(remaining(at: context.date)))
                        .textStyle(.numeral(76))
                        .foregroundStyle(Palette.subtle)
                        .accessibilityLabel(Text("\(CountdownFormat.clock(remaining(at: context.date))) left in the bake", bundle: .module))
                        .accessibilityIdentifier("bake.timer")
                }
                BreathingLine(isBreathing: !isReady)
            }
            .offset(y: BurnInDrift.offset(at: context.date, period: 90, range: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            if let onOpen {
                ManualDoorButton(title: Text("Open the oven", bundle: .module), identifier: "bake.openManually", action: onOpen)
                    // Kept dim: this screen stays on for up to 90 minutes (Guideline 2.4.2).
                    .opacity(0.45)
                    .padding(.bottom, Spacing.margin)
            }
        }
        .background(Palette.black.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func remaining(at date: Date) -> TimeInterval {
        (bake.endsAt ?? date).timeIntervalSince(date)
    }
}
