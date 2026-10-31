import DesignSystem
import Domain
import Services
import SwiftUI

/// Shows the screen for the current session phase. The door, not navigation, moves the player
/// between phases.
struct SessionRootView: View {
    let session: SessionController
    let screenAwake: any ScreenAwakeControlling

    private var recipe: Recipe { StarterRecipes.vanillaCupcakes }

    var body: some View {
        let copy = DoorCopy(source: session.doorSource)
        Group {
            switch session.phase {
            case .idle:
                PrepScreen(recipe: recipe, doorCopy: copy) { temperature in
                    session.preheat(recipe, temperature: temperature)
                }
                .transition(.opacity)
            case let .armed(bake):
                PreheatScreen(recipe: recipe, temperature: bake.temperature, doorCopy: DoorCopy(source: bake.source)) {
                    session.send(.cancelPreheat)
                }
                .transition(.opacity)
            case let .baking(bake):
                bakeScreen(bake, isReady: false)
            case let .ready(bake):
                bakeScreen(bake, isReady: true)
            default:
                InterimPhaseView(phase: session.phase, send: session.send)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phaseKey)
        .onChange(of: phaseKey, initial: true) {
            screenAwake.keepsScreenAwake = KeepAwakePolicy.keepsAwake(session.phase)
        }
    }

    /// A Duo closed by its hinge shows the bake on its outer screen; everywhere else the
    /// screen is face down and goes black.
    @ViewBuilder
    private func bakeScreen(_ bake: Bake, isReady: Bool) -> some View {
        let recipe = StarterRecipes.recipe(id: bake.recipeID)
        if bake.source == .hinge {
            CoverBakeScreen(recipe: recipe, bake: bake, isReady: isReady)
                .transition(.opacity)
        } else {
            FaceDownBakeScreen(recipe: recipe, bake: bake, isReady: isReady)
                .transition(.opacity)
        }
    }

    /// Animates only when the phase changes, not on every tick inside a phase.
    private var phaseKey: String {
        switch session.phase {
        case .idle: "idle"
        case .armed: "armed"
        case .baking: "baking"
        case .ajar: "ajar"
        case .ready: "ready"
        case .graded: "graded"
        case .decorating: "decorating"
        case .served: "served"
        }
    }
}
