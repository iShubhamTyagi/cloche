import DesignSystem
import Domain
import SwiftUI

/// Board "1 Prep": pick a temperature and preheat. Gate 0 has one hard-coded dish; the recipe
/// circles, recipe book, settings and work label arrive with their features (2.1, 2.6, 2.10, 3.4).
struct PrepScreen: View {
    let recipe: Recipe
    let doorCopy: DoorCopy
    let onPreheat: (Temperature) -> Void

    @State private var temperature: Temperature = .medium

    var body: some View {
        VStack(spacing: 0) {
            header

            CupcakeView(progress: 1, icing: .rose, showsPlate: true)
                .frame(width: 236, height: 236)
                .padding(.top, Spacing.s2)

            VStack(spacing: 6) {
                Text(recipe.name)
                    .textStyle(.name.sized(34, lineHeight: 38))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                EyebrowLabel(Text("\(recipe.bakeMinutes) min · \(recipe.region)", bundle: .module))
            }
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 10) {
                EyebrowLabel(Text("Oven", bundle: .module))
                TemperaturePicker(selection: $temperature)
            }
            .padding(.top, 22)

            Spacer(minLength: Spacing.margin)

            Button {
                onPreheat(temperature)
            } label: {
                HStack(spacing: Spacing.s2) {
                    Text("Preheat", bundle: .module)
                    Text("· \(recipe.bakeMinutes) min", bundle: .module)
                        .textStyle(.voice(17))
                }
            }
            .buttonStyle(.primary)
            .accessibilityLabel(Text("Preheat, \(recipe.bakeMinutes) minutes", bundle: .module))
            .accessibilityIdentifier("prep.preheat")

            doorCopy.afterPreheatNote
                .textStyle(.note)
                .foregroundStyle(Palette.muted)
                .padding(.top, 10)
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.s2)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .pocketScreenBackground()
        .background(alignment: .top) { heroGlow }
    }

    private var header: some View {
        HStack {
            Text("Pocket Oven", bundle: .module)
                .textStyle(.voice(22))
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("prep.title")
            Spacer()
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
    PrepScreen(recipe: StarterRecipes.vanillaCupcakes, doorCopy: DoorCopy(source: .faceDown)) { _ in }
}
