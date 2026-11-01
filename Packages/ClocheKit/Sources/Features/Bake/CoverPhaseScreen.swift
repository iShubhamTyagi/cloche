import DesignSystem
import Domain
import SwiftUI

/// Whatever the session is doing, a Duo folded shut shows the front of the oven on its cover,
/// upright as the folded phone is held (`CoverDisplay`). The open-screen layouts are never drawn
/// on the cover.
struct CoverPhaseScreen: View {
    let phase: SessionPhase
    /// The length picked on Prep, for the folded-before-a-bake state.
    let length: BakeLength

    var body: some View {
        switch phase {
        case .idle:
            CoverIdleScreen(length: length)
        case let .armed(bake):
            let recipe = StarterRecipes.recipe(id: bake.recipeID)
            CoverMessageScreen(
                plate: Text(CountdownFormat.clock(bake.duration)),
                heat: 0.4,
                dish: Dish(recipeID: recipe.id),
                caption: Text("Starting · \(recipe.name)", bundle: .module)
            )
        case let .baking(bake):
            CoverBakeScreen(recipe: StarterRecipes.recipe(id: bake.recipeID), bake: bake, isReady: false)
        case let .ready(bake):
            CoverBakeScreen(recipe: StarterRecipes.recipe(id: bake.recipeID), bake: bake, isReady: true)
        case let .ajar(bake, _, graceEndsAt):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                CoverMessageScreen(
                    plate: Text(CountdownFormat.seconds(graceEndsAt.timeIntervalSince(context.date))),
                    heat: 0.8,
                    dish: Dish(recipeID: bake.recipeID),
                    dishProgress: bake.progress(at: context.date),
                    browning: .pale,
                    caption: Text("Door ajar · close it to keep baking", bundle: .module)
                )
            }
        case let .graded(outcome):
            outcomeScreen(outcome, plate: outcome.isFullyBaked ? Text("Prêt.", bundle: .module) : Text("Done", bundle: .module), caption: Text("Open the phone to see your bake", bundle: .module))
        case let .decorating(outcome, breakEndsAt):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                outcomeScreen(outcome, plate: Text(CountdownFormat.clock(breakEndsAt.timeIntervalSince(context.date))), caption: Text("Break · open the phone to decorate", bundle: .module))
            }
        case let .served(outcome, _):
            outcomeScreen(outcome, plate: Text("Served", bundle: .module), caption: Text("Served · open the phone to bake again", bundle: .module))
        }
    }

    private func outcomeScreen(_ outcome: BakeOutcome, plate: Text, caption: Text) -> some View {
        let grade = GradeCalculator.grade(outcome, served: true)
        return CoverMessageScreen(
            plate: plate,
            isPlateItalic: outcome.isFullyBaked,
            heat: 0.3,
            dish: Dish(recipeID: outcome.bake.recipeID),
            dishProgress: grade.isHalfBaked ? max(outcome.doneness * 0.5, 0.3) : 1,
            browning: grade.browning,
            caption: caption
        )
    }
}

/// The oven front with a caption, for every cover state that isn't the live bake.
struct CoverMessageScreen: View {
    let plate: Text
    var isPlateItalic = false
    var heat: Double = 0.3
    let dish: Dish
    var dishProgress: Double = 0
    var browning: Browning = .golden
    let caption: Text

    var body: some View {
        CoverDisplay {
            CoverStage {
                OvenFrame(plate: plate, isPlateItalic: isPlateItalic, heat: heat, dish: dish, dishProgress: dishProgress, browning: browning)
            } caption: {
                CoverCaption(text: caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .background(Palette.black.ignoresSafeArea())
    }
}
