import DesignSystem
import Domain
import SwiftUI

/// Shows the screen for the current session phase. The door, not navigation, moves the player
/// between phases.
struct SessionRootView: View {
    let session: SessionController

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
            default:
                InterimPhaseView(phase: session.phase, send: session.send)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phaseKey)
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
