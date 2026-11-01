import DesignSystem
import Domain
import SwiftUI

/// The Duo folded shut on Prep, before a bake: the outside of the same oven, in the same place
/// and size as on the inner screen, with the chosen dish waiting behind the glass.
struct CoverIdleScreen: View {
    let length: BakeLength

    private var recipe: Recipe { StarterRecipes.recipe(for: length) }

    var body: some View {
        OvenStage {
            Color.clear
        } oven: {
            OvenView(
                plate: Text(CountdownFormat.clock(TimeInterval(length.minutes * 60))),
                heat: 0.4,
                dishProgress: 0,
                dish: Dish(recipeID: recipe.id),
                hasClearGlass: true
            )
        } content: {
            VStack(spacing: Spacing.s3) {
                EyebrowLabel(Text("\(recipe.name) · \(length.minutes) min", bundle: .module))
                Text("Open the phone to start your bake.", bundle: .module)
                    .textStyle(.body)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("cover.idle")
            }
            .padding(.top, Spacing.margin)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Palette.black.ignoresSafeArea())
    }
}

#Preview {
    CoverIdleScreen(length: .medium)
        .frame(width: 466, height: 678)
}
