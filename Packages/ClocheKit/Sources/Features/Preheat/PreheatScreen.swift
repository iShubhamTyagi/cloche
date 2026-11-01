import DesignSystem
import Domain
import SwiftUI

/// Board "2 Preheat": the oven is ready and the bake starts when the door closes.
/// There is no start button; the door is the only control.
struct PreheatScreen: View {
    let recipe: Recipe
    let bake: Bake
    let doorCopy: DoorCopy
    /// Starts the bake without turning the phone over; nil hides the option (the Duo's hinge).
    var onStartWithoutTurning: (() -> Void)?
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.s1) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .regular))
                        .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.text)
                .accessibilityLabel(Text("Back", bundle: .module))
                .accessibilityIdentifier("preheat.back")
                EyebrowLabel(bake.isDemo ? Text("Demo bake · no stars", bundle: .module) : Text("Ready to bake", bundle: .module))
                Spacer()
            }
            .padding(.leading, -Spacing.s3)

            OvenView(plate: Text("Ready", bundle: .module), heat: 0.7)
                .frame(maxWidth: 342)
                .padding(.top, Spacing.s4)

            VStack(spacing: Spacing.s3) {
                Text("The oven is ready.", bundle: .module)
                    .textStyle(.title)
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("preheat.title")
                doorCopy.preheatHelper
                    .textStyle(.body)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                StatusPill(doorCopy.waitingPill)
                    .padding(.top, Spacing.s1)
            }
            .padding(.top, Spacing.margin)

            Spacer(minLength: Spacing.margin)

            summary

            if let footer = doorCopy.preheatFooter {
                footer
                    .textStyle(.note)
                    .foregroundStyle(Palette.subtle)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.s4)
            }

            if let onStartWithoutTurning {
                ManualDoorButton(title: Text("Start without turning over", bundle: .module), identifier: "preheat.startManually", action: onStartWithoutTurning)
                    .padding(.top, Spacing.s2)
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.s2)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .pocketScreenBackground()
    }

    private var summary: some View {
        HStack(spacing: 0) {
            cell(Text("Recipe", bundle: .module), Text(recipe.name))
            divider
            cell(Text("Oven", bundle: .module), BakeLengthPicker.name(bake.length))
            divider
            cell(Text("Bake", bundle: .module), bake.isDemo ? Text("15 sec", bundle: .module) : Text("\(bake.length.minutes) min", bundle: .module))
        }
        .padding(.vertical, Spacing.s3)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line1).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line1).frame(height: 1) }
    }

    private var divider: some View {
        Rectangle().fill(Palette.line1).frame(width: 1, height: 36)
    }

    private func cell(_ label: Text, _ value: Text) -> some View {
        VStack(spacing: Spacing.s1) {
            EyebrowLabel(label)
            value
                .textStyle(.voice(17))
                .foregroundStyle(Palette.sand)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PreheatScreen(recipe: StarterRecipes.vanillaCupcakes, bake: Bake(BakeRequest(recipe: StarterRecipes.vanillaCupcakes, length: .quick, source: .faceDown, isDemo: true)), doorCopy: DoorCopy(source: .faceDown)) {}
}
