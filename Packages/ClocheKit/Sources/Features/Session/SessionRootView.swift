import DesignSystem
import DoorSensing
import Domain
import Services
import SwiftUI

/// Shows the screen for the current session phase. The door, not navigation, moves the player
/// between phases; the only sheets are Settings and the one-time notification pre-prompt.
struct SessionRootView: View {
    let dependencies: FeatureDependencies

    @State private var showsSettings = false
    @State private var pendingPreheat: PendingPreheat?

    private var session: SessionController { dependencies.session }

    var body: some View {
        let copy = DoorCopy(source: session.doorSource)
        Group {
            switch session.phase {
            case .idle:
                PrepScreen(doorCopy: copy, onSettings: { showsSettings = true }) { length in
                    preheat(PendingPreheat(length: length, isDemo: false))
                }
                .transition(.opacity)
            case let .armed(bake):
                PreheatScreen(recipe: StarterRecipes.recipe(id: bake.recipeID), bake: bake, doorCopy: DoorCopy(source: bake.source)) {
                    session.send(.cancelPreheat)
                }
                .transition(.opacity)
            case let .baking(bake):
                bakeScreen(bake, isReady: false)
            case let .ready(bake):
                bakeScreen(bake, isReady: true)
            case let .ajar(bake, _, graceEndsAt):
                Group {
                    if bake.source == .hinge {
                        DuoAjarScreen(bake: bake, graceEndsAt: graceEndsAt, hingeAngle: dependencies.doorSensor.hingeReading?.angle)
                    } else {
                        AjarScreen(bake: bake, graceEndsAt: graceEndsAt)
                    }
                }
                .transition(.opacity)
            case let .graded(outcome):
                Group {
                    if outcome.bake.source == .hinge {
                        DuoGradeScreen(recipe: StarterRecipes.recipe(id: outcome.bake.recipeID), outcome: outcome, hingeAngle: dependencies.doorSensor.hingeReading?.angle, send: session.send)
                    } else {
                        GradedFlow(recipe: StarterRecipes.recipe(id: outcome.bake.recipeID), outcome: outcome, send: session.send)
                    }
                }
                .transition(.opacity)
            default:
                InterimPhaseView(phase: session.phase, send: session.send)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phaseKey)
        .onChange(of: phaseKey, initial: true) { updateKeepAwake() }
        .onChange(of: dependencies.settings.keepsScreenAwake) { updateKeepAwake() }
        .sheet(isPresented: $showsSettings) {
            SettingsScreen(settings: dependencies.settings, hingePresent: dependencies.doorSensor.hingePresent, onDemoBake: {
                showsSettings = false
                preheat(PendingPreheat(length: .quick, isDemo: true))
            }, onClose: { showsSettings = false })
        }
        .sheet(item: $pendingPreheat) { pending in
            NotificationPrePrompt(onAllow: {
                Task {
                    _ = await dependencies.notifications.requestPermission()
                    finishPreheat(pending)
                }
            }, onNotNow: {
                finishPreheat(pending)
            })
            .interactiveDismissDisabled()
        }
    }

    /// Asks about notifications once, in context, before the first bake (Guideline 4.5.4).
    private func preheat(_ request: PendingPreheat) {
        guard !dependencies.settings.hasAskedForNotifications else {
            session.preheat(StarterRecipes.recipe(for: request.length), length: request.length, isDemo: request.isDemo)
            return
        }
        Task {
            if await dependencies.notifications.permission() == .notDetermined {
                pendingPreheat = request
            } else {
                dependencies.settings.hasAskedForNotifications = true
                session.preheat(StarterRecipes.recipe(for: request.length), length: request.length, isDemo: request.isDemo)
            }
        }
    }

    private func finishPreheat(_ request: PendingPreheat) {
        dependencies.settings.hasAskedForNotifications = true
        pendingPreheat = nil
        session.preheat(StarterRecipes.recipe(for: request.length), length: request.length, isDemo: request.isDemo)
    }

    private func updateKeepAwake() {
        dependencies.screenAwake.keepsScreenAwake = KeepAwakePolicy.keepsAwake(session.phase, setting: dependencies.settings.keepsScreenAwake)
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

/// A Bake tap waiting on the notification pre-prompt.
private struct PendingPreheat: Identifiable {
    let id = UUID()
    let length: BakeLength
    let isDemo: Bool
}
