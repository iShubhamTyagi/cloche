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
    @State private var length: BakeLength = .quick
    /// The current bake's door is worked by hand ("Start without turning over").
    @State private var usesManualDoor = false
    /// Set by the Decorate tap, so the move to the plating station plays only then, not when
    /// the app comes back to a break already running.
    @State private var decorateFromGrade = false
    #if DEBUG
    /// A dev bake is running itself: shut, 5 s, open, then straight into decorating.
    @State private var isDevBake = false
    #endif

    /// Set by `AppRootView` from the hinge and the window size (`FoldSignal`).
    @Environment(\.isOnCover) private var isPhysicallyFolded

    private var session: SessionController { dependencies.session }

    var body: some View {
        let copy = DoorCopy(source: session.doorSource)
        Group {
            if isPhysicallyFolded {
                // Folded shut, only the cover is visible: every phase gets its cover screen.
                CoverPhaseScreen(phase: session.phase, length: length)
                    .transition(.opacity)
            } else {
                phaseScreen(copy: copy)
            }
        }
        .onChange(of: isPhysicallyFolded) { _, folded in
            guard folded else { return }
            // Sheets can't be used on the cover: Settings closes, and folding at the
            // notification pre-prompt counts as "Not now" (the bake goes ahead).
            showsSettings = false
            if let pendingPreheat { finishPreheat(pendingPreheat) }
        }
        .animation(.easeInOut(duration: 0.25), value: phaseKey)
        .animation(.easeInOut(duration: 0.25), value: isPhysicallyFolded)
        .onChange(of: phaseKey, initial: true) {
            updateKeepAwake()
            releaseManualDoorIfDone()
            #if DEBUG
            advanceDevBake()
            #endif
        }
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

    /// The open screen (iPhone, or the Duo unfolded) for each phase.
    @ViewBuilder
    private func phaseScreen(copy: DoorCopy) -> some View {
        switch session.phase {
            case .idle:
                PrepScreen(doorCopy: copy, onSettings: { showsSettings = true }, length: $length, onBake: { length in
                    preheat(PendingPreheat(length: length, isDemo: false))
                }, onDevBake: devBakeAction)
                .transition(.opacity)
            case let .armed(bake):
                PreheatScreen(
                    recipe: StarterRecipes.recipe(id: bake.recipeID),
                    bake: bake,
                    doorCopy: DoorCopy(source: bake.source),
                    onStartWithoutTurning: bake.source == .hinge ? nil : { setManualDoor(.closed) }
                ) {
                    session.send(.cancelPreheat)
                }
                .transition(.opacity)
            case let .baking(bake):
                bakeScreen(bake, isReady: false)
            case let .ready(bake):
                bakeScreen(bake, isReady: true)
            case let .ajar(bake, _, graceEndsAt):
                AjarScreen(
                    bake: bake,
                    graceEndsAt: graceEndsAt,
                    door: DoorStyle(source: bake.source, hingeAngle: hingeAngle, restingLift: DoorGeometry.defaultAjarLift),
                    onClose: usesManualDoor ? { setManualDoor(.closed) } : nil
                )
                .transition(.opacity)
            case let .graded(outcome):
                GradeScreen(
                    recipe: StarterRecipes.recipe(id: outcome.bake.recipeID),
                    outcome: outcome,
                    door: DoorStyle(source: outcome.bake.source, hingeAngle: hingeAngle),
                    send: sendFromGrade
                )
                .transition(.opacity)
            case let .decorating(outcome, breakEndsAt):
                DecorateScreen(
                    recipe: StarterRecipes.recipe(id: outcome.bake.recipeID),
                    outcome: outcome,
                    breakEndsAt: breakEndsAt,
                    playsIntro: decorateFromGrade
                ) {
                    session.send(.serveNow)
                }
                .transition(.opacity)
            default:
                InterimPhaseView(phase: session.phase, send: session.send)
                    .transition(.opacity)
            }
    }

    private func sendFromGrade(_ event: SessionEvent) {
        decorateFromGrade = event == .decorate
        session.send(event)
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

    private func setManualDoor(_ state: DoorState) {
        usesManualDoor = true
        dependencies.doorSensor.manualOverride = state
    }

    /// Once the bake is out of the oven (or called off), the real sensors take over again.
    private func releaseManualDoorIfDone() {
        guard usesManualDoor else { return }
        switch session.phase {
        case .idle, .graded, .decorating, .served:
            usesManualDoor = false
            dependencies.doorSensor.manualOverride = nil
        default:
            break
        }
    }

    private func updateKeepAwake() {
        dependencies.screenAwake.keepsScreenAwake = KeepAwakePolicy.keepsAwake(session.phase, setting: dependencies.settings.keepsScreenAwake)
    }

    // MARK: Dev bake (development builds only)

    private var devBakeAction: (() -> Void)? {
        #if DEBUG
        return {
            isDevBake = true
            setManualDoor(.closed)
            // Skips the notification pre-prompt; a dev shortcut, not a first bake.
            session.preheat(StarterRecipes.recipe(for: length), length: length, durationOverride: Self.devBakeDuration)
        }
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static let devBakeDuration: TimeInterval = 5

    /// Works the door for the dev bake: open it once ready, then skip the grade card to decorate.
    private func advanceDevBake() {
        guard isDevBake else { return }
        switch session.phase {
        case .ready:
            setManualDoor(.open)
        case .graded:
            isDevBake = false
            sendFromGrade(.decorate)
        case .idle, .served, .decorating:
            isDevBake = false
        case .armed, .baking, .ajar:
            break
        }
    }
    #endif

    /// A Duo closed by its hinge shows the bake on its outer screen; everywhere else the
    /// screen is face down and goes black.
    @ViewBuilder
    private func bakeScreen(_ bake: Bake, isReady: Bool) -> some View {
        let recipe = StarterRecipes.recipe(id: bake.recipeID)
        if bake.source == .hinge {
            CoverBakeScreen(recipe: recipe, bake: bake, isReady: isReady)
                .transition(.opacity)
        } else {
            FaceDownBakeScreen(recipe: recipe, bake: bake, isReady: isReady, onOpen: usesManualDoor ? { setManualDoor(.open) } : nil)
                .transition(.opacity)
        }
    }

    /// The hinge angle, for the door panels. Whether the Duo is folded comes from `isOnCover`
    /// (the hinge itself plus the window size), not the door state: leaving the app counts as an
    /// open door even while folded.
    private var hingeAngle: Double? {
        dependencies.doorSensor.hingeReading?.angle
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
