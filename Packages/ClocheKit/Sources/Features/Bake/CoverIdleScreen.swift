import DesignSystem
import Domain
import SwiftUI

/// The Duo folded shut on Prep, before a bake: the oven front, upright as the folded phone is held
/// and where the oven was on the open screen (`CoverDisplay`, `CoverStage`), cold, with the
/// chosen dish waiting behind the glass.
struct CoverIdleScreen: View {
    let length: BakeLength

    private var recipe: Recipe { StarterRecipes.recipe(for: length) }

    var body: some View {
        CoverDisplay {
            CoverStage {
                OvenFrame(
                    plate: Text(CountdownFormat.clock(TimeInterval(length.minutes * 60))),
                    heat: 0.2,
                    dish: Dish(recipeID: recipe.id)
                )
            } caption: {
                CoverCaption(text: Text("Open the phone to start · \(recipe.name)", bundle: .module))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(recipe.name), \(length.minutes) minutes. Open the phone to start your bake.", bundle: .module))
        .accessibilityIdentifier("cover.idle")
        .background(Palette.black.ignoresSafeArea())
    }
}

/// The single line under the oven on the cover, with an optional progress line (board Duo 3).
struct CoverCaption: View {
    let text: Text
    var progress: Double?

    var body: some View {
        VStack(spacing: Spacing.s3) {
            EyebrowLabel(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line1)
                        Capsule().fill(Palette.text.opacity(0.85)).frame(width: proxy.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 2)
                .frame(maxWidth: 320)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CoverIdleScreen(length: .medium)
        .frame(width: 466, height: 678)
}
