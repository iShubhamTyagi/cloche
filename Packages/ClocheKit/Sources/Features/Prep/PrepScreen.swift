import DesignSystem
import Domain
import SwiftUI

/// Board "1 Prep". The oven slot (`OvenFrame`) fills the whole top half, edge to edge; the bottom half picks how long to
/// bake. Each length loads its own dish onto the rack (Quick cupcakes, Medium a small cake,
/// Long a large cake), visible through the door's glass. The art is a placeholder for the 3D
/// assets; the half-and-half layout is what stays.
struct PrepScreen: View {
    let doorCopy: DoorCopy
    let onSettings: () -> Void
    /// Owned by the session root so the choice survives a fold to the cover screen and back.
    @Binding var length: BakeLength
    let onBake: (BakeLength) -> Void
    /// Development builds only: a 5 s bake that runs itself into decorating. Nil hides the button.
    var onDevBake: ((BakeLength) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// On the open Duo the options lie on the oven door's glass (`OvenStage`): tighter spacing.
    @Environment(\.isOnDoorGlass) private var isOnDoorGlass

    private var recipe: Recipe { StarterRecipes.recipe(for: length) }

    var body: some View {
        OvenStage {
            header
        } oven: {
            oven
        } content: {
            optionsHalf
        }
        .pocketScreenBackground()
    }

    private var oven: some View {
        OvenFrame(
            plate: Text(CountdownFormat.clock(TimeInterval(length.minutes * 60))),
            heat: 0.4,
            dish: Dish(recipeID: recipe.id),
            isDoorPlayable: true,
            dishFliesIn: true
        )
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15), value: length)
        .accessibilityIdentifier("prep.oven")
    }

    private var optionsHalf: some View {
        VStack(spacing: 0) {
            VStack(spacing: isOnDoorGlass ? Spacing.s1 : 6) {
                Text(recipe.name)
                    .textStyle(isOnDoorGlass ? .name.sized(26, lineHeight: 30) : .name.sized(30, lineHeight: 34))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("prep.recipe")
                EyebrowLabel(Text(recipe.region))
            }
            .padding(.top, isOnDoorGlass ? Spacing.s2 : Spacing.margin)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: length)

            VStack(alignment: .leading, spacing: 10) {
                EyebrowLabel(Text("Oven", bundle: .module))
                BakeLengthPicker(selection: $length)
            }
            .padding(.top, isOnDoorGlass ? Spacing.s3 : 22)

            Spacer(minLength: isOnDoorGlass ? Spacing.s2 : Spacing.s4)

            Button {
                onBake(length)
            } label: {
                HStack(spacing: Spacing.s2) {
                    Text("Bake", bundle: .module)
                    Text("· \(length.minutes) min", bundle: .module)
                        .textStyle(.voice(17))
                }
            }
            .buttonStyle(.primary)
            .accessibilityLabel(Text("Bake, \(length.minutes) minutes", bundle: .module))
            .accessibilityIdentifier("prep.bake")

            doorCopy.afterPreheatNote
                .textStyle(.note)
                .foregroundStyle(Palette.muted)
                .padding(.top, isOnDoorGlass ? Spacing.s1 : 10)
        }
    }

    private var header: some View {
        HStack {
            Text("Cloche", bundle: .module)
                .textStyle(.voice(22))
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("prep.title")
            Spacer()
            #if DEBUG
            if let onDevBake {
                // Debug-only, never shipped, so not localized.
                Menu {
                    Button { onDevBake(.quick) } label: { Text(verbatim: "Cupcakes") }
                    Button { onDevBake(.medium) } label: { Text(verbatim: "Cake") }
                } label: {
                    Text(verbatim: "5s")
                        .textStyle(.control)
                        .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.muted)
                .accessibilityLabel(Text(verbatim: "Dev bake, 5 seconds, to decorating"))
                .accessibilityIdentifier("prep.devBake")
            }
            #endif
            Button(action: onSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .light))
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            .accessibilityLabel(Text("Settings", bundle: .module))
            .accessibilityIdentifier("prep.settings")
            .padding(.trailing, -Spacing.s3)
        }
    }
}

#Preview {
    @Previewable @State var length = BakeLength.quick
    PrepScreen(doorCopy: DoorCopy(source: .faceDown), onSettings: {}, length: $length) { _ in }
}
