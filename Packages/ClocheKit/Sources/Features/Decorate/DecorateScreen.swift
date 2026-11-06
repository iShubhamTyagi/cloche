import DesignSystem
import Domain
import SwiftUI

/// The break and the serve, in one continuous scene: the dish comes from the oven along the slab
/// to the turntable, is decorated there, and is served there.
struct DecorateScreen: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let breakEndsAt: Date
    /// Set once served: the same screen carries on, so the cake stays on its turntable.
    let served: Grade?
    let onServeNow: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: DecorStudioModel
    /// False while the dish is on its way from the oven.
    @State private var isSettled: Bool

    /// `playsIntro`: arriving from Decorate; false when coming back to a break already running.
    init(recipe: Recipe, outcome: BakeOutcome, breakEndsAt: Date, served: Grade?, playsIntro: Bool,
         onServeNow: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.recipe = recipe
        self.outcome = outcome
        self.breakEndsAt = breakEndsAt
        self.served = served
        self.onServeNow = onServeNow
        self.onDone = onDone
        _model = State(initialValue: DecorStudioView.makeModel(recipe: recipe, outcome: outcome, served: served))
        _isSettled = State(initialValue: !playsIntro || served != nil)
    }

    var body: some View {
        ZStack {
            DecorStudioView(model: model, recipe: recipe, outcome: outcome, breakEndsAt: breakEndsAt, served: served,
                            isActive: isSettled || reduceMotion, onServeNow: onServeNow, onDone: onDone)
            if !isSettled, !reduceMotion, !model.isServing {
                let grade = GradeCalculator.grade(outcome, served: true)
                StationMoveView(
                    model: model,
                    dish: Dish(recipeID: recipe.id),
                    progress: grade.isHalfBaked ? max(outcome.doneness * 0.5, 0.3) : 1,
                    browning: grade.browning
                ) {
                    isSettled = true
                }
            }
        }
    }
}
