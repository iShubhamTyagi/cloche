import Decorating
import DesignSystem
import Domain
import SwiftUI

/// The decorating studio (decorating plan, Phase D0 placeholder): the cake seen from straight
/// above on the turntable, the ingredient shelf above it, the toppings and tools below, the
/// break clock and Serve. Code-drawn until the live viewer and the station panels land.
struct DecorStudioView: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let breakEndsAt: Date
    let isServing: Bool
    let onServe: () -> Void
    @State private var model: DecorStudioModel

    init(recipe: Recipe, outcome: BakeOutcome, breakEndsAt: Date, isServing: Bool, onServe: @escaping () -> Void) {
        self.recipe = recipe
        self.outcome = outcome
        self.breakEndsAt = breakEndsAt
        self.isServing = isServing
        self.onServe = onServe
        let dish = Dish(recipeID: recipe.id)
        let key: ViewerAssets.DishKey = dish == .cupcakes ? .cupcake : .cake
        let geometry = ViewerAssets.profile(key)?.geometry ?? (dish == .cupcakes ? .cupcake : .cake)
        _model = State(initialValue: DecorStudioModel(geometry: geometry, aspect: 0.6))
    }

    private var dishKey: ViewerAssets.DishKey { Dish(recipeID: recipe.id) == .cupcakes ? .cupcake : .cake }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height * 0.5)
            VStack(spacing: Spacing.s3) {
                header
                shelf(count: 12)
                    .frame(height: HitTarget.minimum + Spacing.s3)
                Spacer(minLength: 0)
                CakeViewerView(model: model, dish: dishKey, browning: GradeCalculator.grade(outcome, served: true).browning == .dark ? 1 : 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: side * 1.25)
                Spacer(minLength: 0)
                shelf(count: 8)
                    .frame(height: HitTarget.minimum + Spacing.s3)
                shelf(count: 5)
                    .frame(height: HitTarget.minimum + Spacing.s3)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s2)
        }
        .pocketScreenBackground()
        .accessibilityIdentifier("decorate.studio")
        #if DEBUG
        .task {
            if ProcessInfo.processInfo.arguments.contains("-decorDemo") { model.applyDemo() }
        }
        #endif
    }

    private var header: some View {
        HStack {
            BreakClockBadge(breakEndsAt: breakEndsAt, total: outcome.bake.breakDuration)
            Spacer()
            Button(action: onServe) {
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

    private func shelf(count: Int) -> some View {
        HStack(spacing: Spacing.s2) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.chip)
                    .fill(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: Radius.chip).strokeBorder(Palette.line1))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The break clock, small, for the studio's header.
struct BreakClockBadge: View {
    let breakEndsAt: Date
    let total: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(breakEndsAt.timeIntervalSince(context.date), 0)
            RingClock(
                remaining: remaining,
                total: total,
                size: HitTarget.minimum + Spacing.s2,
                isAmber: remaining <= 30,
                label: Text("\(CountdownFormat.clock(remaining)) left in the break", bundle: .module)
            )
        }
        .accessibilityIdentifier("decorate.ring")
    }
}

/// A flat top-down cake on a marble-grey plate: the stand-in until the live viewer.
struct PlaceholderCake: View {
    let dish: Dish

    var body: some View {
        let fraction: CGFloat = dish == .cupcakes ? 0.3 : 0.65
        ZStack {
            Circle().fill(Palette.muted.opacity(0.35))
            Circle().strokeBorder(Palette.sand, lineWidth: 3)
            Circle()
                .fill(FoodPalette.bakeGolden)
                .scaleEffect(fraction)
        }
    }
}
