import DesignSystem
import Domain
import SwiftUI

/// The break, at the plating station (board "S2 1", shell only: the decorating tools, tabs and
/// tray arrive in Phase 2.3). The top half moves from the oven to the plating station and the
/// tongs set the dish on the cake stand; the bottom half holds the break clock.
struct DecorateScreen: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let breakEndsAt: Date
    /// True when arriving from Decorate; false when coming back to a break already running.
    let playsIntro: Bool
    let onServeNow: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettled: Bool
    /// Serve tapped: the cloche lowers over the dish, then the serve goes through.
    @State private var isServing = false

    init(recipe: Recipe, outcome: BakeOutcome, breakEndsAt: Date, playsIntro: Bool, onServeNow: @escaping () -> Void) {
        self.recipe = recipe
        self.outcome = outcome
        self.breakEndsAt = breakEndsAt
        self.playsIntro = playsIntro
        self.onServeNow = onServeNow
        _isSettled = State(initialValue: !playsIntro)
    }

    var body: some View {
        ZStack {
            stage
            if isSettled {
                DecorStudioView(recipe: recipe, outcome: outcome, breakEndsAt: breakEndsAt,
                                isServing: isServing, onServe: serve)
                    .transition(.opacity)
            }
        }
    }

    /// The stage: the oven-to-stand move, then the dish settled on the stand.
    private var stage: some View {
        let grade = GradeCalculator.grade(outcome, served: true)
        return OvenStage(isContentOnDoor: false) {
            header
        } oven: {
            StationMoveView(
                dish: Dish(recipeID: recipe.id),
                progress: grade.isHalfBaked ? max(outcome.doneness * 0.5, 0.3) : 1,
                browning: grade.browning,
                playsIntro: playsIntro,
                isServing: isServing
            ) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { isSettled = true }
            }
            .accessibilityIdentifier("decorate.station")
        } content: {
            breakClock
                .opacity(isSettled ? 1 : 0)
        }
        .pocketScreenBackground()
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                EyebrowLabel(Text(recipe.name))
                    .lineLimit(1)
                Text("Finishing table", bundle: .module)
                    .textStyle(.voice(22))
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: Spacing.s2)
            // Always visible, from the first frame: serving early loses nothing.
            Button(action: serve) {
                Text("Serve now", bundle: .module)
                    .textStyle(.control)
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Spacing.s4)
                    .frame(height: HitTarget.minimum)
                    .overlay(Capsule().strokeBorder(Palette.line3, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isServing)
            .accessibilityIdentifier("decorate.serveNow")
        }
    }

    private func serve() {
        guard !isServing else { return }
        isServing = true
        if reduceMotion {
            onServeNow()
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(StationMoveView.lowerDuration + 0.15))
            onServeNow()
        }
    }

    private var breakClock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(breakEndsAt.timeIntervalSince(context.date), 0)
            let isLast30 = remaining <= 30
            VStack(spacing: Spacing.s4) {
                Spacer(minLength: 0)
                EyebrowLabel(Text("Break", bundle: .module))
                RingClock(
                    remaining: remaining,
                    total: outcome.bake.breakDuration,
                    size: 168,
                    isAmber: isLast30,
                    label: isLast30
                        ? Text("\(CountdownFormat.clock(remaining)) left in the break, last 30 seconds", bundle: .module)
                        : Text("\(CountdownFormat.clock(remaining)) left in the break", bundle: .module)
                )
                .accessibilityIdentifier("decorate.ring")
                Text("Serve whenever you like. Nothing is lost.", bundle: .module)
                    .textStyle(.voice(16))
                    .foregroundStyle(Palette.sand)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
        }
    }
}
