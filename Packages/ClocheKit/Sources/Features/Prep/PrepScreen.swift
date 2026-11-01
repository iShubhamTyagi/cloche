import DesignSystem
import Domain
import SwiftUI

/// Board "1 Prep". The oven, door shut, fills the top half; the bottom half picks how long to
/// bake. Each length loads its own dish onto the rack (Quick cupcakes, Medium a small cake,
/// Long a large cake), visible through the door's glass. The art is a placeholder for the 3D
/// assets; the half-and-half layout is what stays.
struct PrepScreen: View {
    let doorCopy: DoorCopy
    let onSettings: () -> Void
    let onBake: (BakeLength) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var length: BakeLength = .quick

    private var recipe: Recipe { StarterRecipes.recipe(for: length) }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ovenHalf
                    .frame(height: proxy.size.height / 2)
                optionsHalf
                    .frame(height: proxy.size.height / 2)
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.s2)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .pocketScreenBackground()
        .background(alignment: .top) { heroGlow }
    }

    private var ovenHalf: some View {
        VStack(spacing: 0) {
            header
            OvenView(
                plate: Text(CountdownFormat.clock(TimeInterval(length.minutes * 60))),
                heat: 0.4,
                doorOpen: 0,
                dishProgress: 0,
                dish: Dish(recipeID: recipe.id),
                hasClearGlass: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15), value: length)
            .accessibilityIdentifier("prep.oven")
        }
    }

    private var optionsHalf: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(recipe.name)
                    .textStyle(.name.sized(30, lineHeight: 34))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("prep.recipe")
                EyebrowLabel(Text(recipe.region))
            }
            .padding(.top, Spacing.margin)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: length)

            VStack(alignment: .leading, spacing: 10) {
                EyebrowLabel(Text("Oven", bundle: .module))
                BakeLengthPicker(selection: $length)
            }
            .padding(.top, 22)

            Spacer(minLength: Spacing.s4)

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
                .padding(.top, 10)
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
        .frame(minHeight: HitTarget.minimum)
    }

    private var heroGlow: some View {
        RadialGradient(colors: [Palette.accent.opacity(0.17), .clear], center: .center, startRadius: 0, endRadius: 220)
            .frame(height: 420)
            .offset(y: 40)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    PrepScreen(doorCopy: DoorCopy(source: .faceDown), onSettings: {}) { _ in }
}
