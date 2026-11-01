import DesignSystem
import Domain
import SwiftUI

/// Board "4 Reveal": the phone was turned over after a finished bake. The oven door drops
/// about its bottom hinge (700 ms) and steam rises over the dish. Reduce Motion cross-fades.
struct RevealScreen: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var doorOpen = 0.0

    var body: some View {
        let browning = GradeCalculator.grade(outcome, served: true).browning
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.margin)
            EyebrowLabel(Text(recipe.name))
            Text("Prêt.", bundle: .module)
                .textStyle(.hero)
                .foregroundStyle(Palette.sand)
                .accessibilityIdentifier("reveal.title")
                .padding(.top, Spacing.s2)

            OvenView(plate: Text("Prêt.", bundle: .module), isPlateItalic: true, heat: 1, doorOpen: doorOpen, dishProgress: 1, browning: browning, dish: Dish(recipeID: recipe.id))
                .overlay {
                    // Over the cavity (left 74% of the oven), rising from the dishes.
                    SteamView(centerX: 0.39, startY: 0.62)
                        .opacity(doorOpen)
                }
                .frame(maxWidth: 342)
            .padding(.top, Spacing.margin)

            Spacer(minLength: Spacing.margin)

            Button(action: onContinue) {
                Text("See how it turned out", bundle: .module)
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("reveal.continue")
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.s2)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .pocketScreenBackground()
        .onAppear {
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.15)) { doorOpen = 1 }
            } else {
                withAnimation(.easeInOut(duration: 0.7).delay(0.15)) { doorOpen = 1 }
            }
        }
    }
}

/// Reveal then grade for a full bake; straight to the grade when the door was opened early.
struct GradedFlow: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let send: (SessionEvent) -> Void

    @State private var showsGrade = false

    var body: some View {
        Group {
            if outcome.isFullyBaked && !showsGrade {
                RevealScreen(recipe: recipe, outcome: outcome) { showsGrade = true }
            } else {
                GradeScreen(recipe: recipe, outcome: outcome, onDecorate: { send(.decorate) }, onServePlain: { send(.servePlain) })
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showsGrade)
    }
}
