import DesignSystem
import Domain
import SwiftUI

/// Boards "Duo 3" and "Duo 4": with the phone shut, the outer screen shows the front of the oven
/// (`OvenFrame`) in the same place and size as the oven on the open screen (`OvenStage`):
/// the dish baking behind the glass, the time on the display, a caption and progress line
/// underneath. When ready the display reads "Prêt." and a glow breathes.
struct CoverBakeScreen: View {
    let recipe: Recipe
    let bake: Bake
    let isReady: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowIsBright = false

    var body: some View {
        CoverDisplay {
            bakeFront
        }
        .background {
            ZStack {
                Palette.black
                if isReady {
                    // Ready glow, breathing over 4 s; covers the whole screen so it fades out softly.
                    RadialGradient(colors: [Palette.accent.opacity(glowIsBright ? 0.2 : 0.07), .clear], center: .center, startRadius: 0, endRadius: 360)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .onAppear {
            guard isReady, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIsBright = true
            }
        }
    }

    private var bakeFront: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max((bake.endsAt ?? context.date).timeIntervalSince(context.date), 0)
            let progress = bake.duration > 0 ? min(max(1 - remaining / bake.duration, 0), 1) : 1

            CoverStage {
                OvenFrame(
                    plate: isReady ? Text("Prêt.", bundle: .module) : Text(CountdownFormat.clock(remaining)),
                    isPlateItalic: isReady,
                    heat: isReady ? 1 : 0.35 + 0.5 * progress,
                    dish: Dish(recipeID: recipe.id),
                    dishProgress: isReady ? 1 : progress
                )
            } caption: {
                CoverCaption(
                    text: isReady
                        ? Text("Ready · lift the lid to open the door", bundle: .module)
                        : Text("Baking · \(recipe.name)", bundle: .module),
                    progress: isReady ? nil : progress
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isReady
                ? Text("\(recipe.name) ready. Lift the lid to open the door.", bundle: .module)
                : Text("\(CountdownFormat.clock(remaining)) left in the bake", bundle: .module))
            .accessibilityIdentifier(isReady ? "bake.ready" : "bake.timer")
            // Keeps static art moving slightly over a 90-minute bake (Guideline 2.4.2).
            .offset(y: BurnInDrift.offset(at: context.date, period: 60, range: 7, step: 1))
        }
    }
}

#Preview("Baking") {
    CoverBakeScreen(recipe: StarterRecipes.vanillaCupcakes, bake: Bake(BakeRequest(recipe: StarterRecipes.vanillaCupcakes, length: .quick, source: .hinge)), isReady: false)
        .frame(width: 466, height: 678)
}

#Preview("Ready") {
    CoverBakeScreen(recipe: StarterRecipes.largeCake, bake: Bake(BakeRequest(recipe: StarterRecipes.largeCake, length: .long, source: .hinge)), isReady: true)
        .frame(width: 466, height: 678)
}
