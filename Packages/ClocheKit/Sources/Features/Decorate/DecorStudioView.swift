import Decorating
import DesignSystem
import Domain
import SwiftUI

/// Decorating and serving, in one continuous scene: the cake never leaves the turntable. The cake
/// is above and the tray or the served panel below. One view for both devices: the cake takes the
/// upper two thirds of a phone, and on the open Duo the split moves to the fold so nothing crosses
/// the hinge.
struct DecorStudioView: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let breakEndsAt: Date
    /// Set once the cake has been served: the cloche lifts and the served panel takes over.
    let served: Grade?
    /// False while the stage's tongs move plays on top: load, but stay out of the way.
    var isActive = true
    let onServeNow: () -> Void
    let onDone: () -> Void

    let model: DecorStudioModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Keeps the tray's first row off the fold band (it reaches 3 % below the middle on the Duo).
    private static let foldClearance: CGFloat = 0.03

    private static func isFolding(_ size: CGSize) -> Bool { size.width / max(size.height, 1) > 0.6 }

    /// The height of the cake's part of the screen, given the full screen.
    static func stageHeight(screen: CGSize) -> CGFloat { screen.height * (isFolding(screen) ? 0.5 : 2.0 / 3) }

    init(model: DecorStudioModel, recipe: Recipe, outcome: BakeOutcome, breakEndsAt: Date, served: Grade?, isActive: Bool = true,
         onServeNow: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.model = model
        self.recipe = recipe
        self.outcome = outcome
        self.breakEndsAt = breakEndsAt
        self.served = served
        self.isActive = isActive
        self.onServeNow = onServeNow
        self.onDone = onDone
    }

    /// The model for a dish; created by the screen, so the opening move can drive it too.
    static func makeModel(recipe: Recipe, outcome: BakeOutcome, served: Grade?) -> DecorStudioModel {
        let key: ViewerAssets.DishKey = Dish(recipeID: recipe.id) == .cupcakes ? .cupcake : .cake
        let profile = ViewerAssets.profile(key)
        let geometry = profile?.geometry ?? (key == .cupcake ? .cupcake : .cake)
        let model = DecorStudioModel(geometry: geometry, profile: profile, store: .standard,
                                     draftKey: DecorDraftStore.key(for: outcome))
        if served != nil { model.seatCloche() } else { model.settleCloche() }
        return model
    }

    private var dishKey: ViewerAssets.DishKey { Dish(recipeID: recipe.id) == .cupcakes ? .cupcake : .cake }
    private var browning: Float { GradeCalculator.grade(outcome, served: true).browning == .dark ? 1 : 0 }

    var body: some View {
        GeometryReader { screen in
            let safeTop = screen.safeAreaInsets.top
            let fullHeight = screen.size.height + safeTop + screen.safeAreaInsets.bottom
            let folding = Self.isFolding(screen.size)
            let stage = Self.stageHeight(screen: CGSize(width: screen.size.width, height: fullHeight))
            VStack(spacing: 0) {
                CakeViewerView(model: model, dish: dishKey, browning: browning)
                    .frame(height: stage)
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, isActive ? Palette.espresso : Palette.ground], startPoint: .top, endPoint: .bottom)
                            .frame(height: Spacing.margin)
                            .allowsHitTesting(false)
                    }
                    .overlay(alignment: .top) {
                        if !model.isServing {
                        // Keeps the header readable whatever the cake is sitting on.
                        LinearGradient(colors: [Palette.espresso.opacity(0.82), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: safeTop + HitTarget.minimum + Spacing.margin)
                            .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .top) {
                        if !model.isServing {
                            header
                                .frame(maxWidth: OvenStage<EmptyView, EmptyView, EmptyView>.maxWidth)
                                .padding(.horizontal, Spacing.margin)
                                .padding(.top, max(safeTop / 2 - HitTarget.minimum / 2, Spacing.s2))
                        }
                    }
                bottomPanel
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: isActive)
                    .frame(maxWidth: OvenStage<EmptyView, EmptyView, EmptyView>.maxWidth)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, folding ? fullHeight * Self.foldClearance : Spacing.s2)
                    .padding(.bottom, screen.safeAreaInsets.bottom + Spacing.s2)
                    .frame(height: fullHeight - stage)
            }
            .frame(maxWidth: .infinity)
            .background(isActive ? Palette.espresso : Palette.ground)
            .animation(.easeInOut(duration: 1.2), value: isActive)
            .ignoresSafeArea()
        }
        .accessibilityIdentifier("decorate.studio")
        .accessibilityHidden(!isActive)
        .task(id: served != nil) { await reveal() }
        #if DEBUG
        .task(id: isActive) {
            guard isActive else { return }
            let args = ProcessInfo.processInfo.arguments
            try? await Task.sleep(for: .seconds(1))
            if args.contains("-decorProbe") {
                // After a relaunch the scene may still be loading: frames only count once it exists.
                try? await Task.sleep(for: .seconds(5))
                await model.runDragProbe()
            }
            if args.contains("-decorRub") { model.applyRub() }
            // `-decorBowls`: the topping step, with the camera on the bowls.
            if args.contains("-decorBowls") {
                try? await Task.sleep(for: .seconds(4))
                model.step = .top
            }
            if args.contains("-decorHandSpin") { model.applyHandSpin() }
            if let i = args.firstIndex(of: "-decorHold"), i + 1 < args.count {
                try? await Task.sleep(for: .seconds(4))
                model.applyHold(args[i + 1])
            }
            if args.contains("-decorDemo") || args.contains("-decorDemoServe") { model.applyDemo() }
            if let i = args.firstIndex(of: "-decorCamera"), i + 1 < args.count { model.applyReviewCamera(args[i + 1]) }
            if let i = args.firstIndex(of: "-decorStep"), i + 1 < args.count, let step = DecorStep(rawValue: args[i + 1]) {
                model.step = step
            }
            if args.contains("-decorDemoServe") {
                try? await Task.sleep(for: .seconds(2))
                serve()
            }
        }
        #endif
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if let served {
            ServedPanel(model: model, grade: served, onDone: onDone)
                .transition(.opacity)
        } else {
            DecorTray(model: model)
                .opacity(model.isServing ? 0 : 1)
                .allowsHitTesting(!model.isServing)
                .animation(.easeOut(duration: 0.25), value: model.isServing)
        }
    }

    /// Serve now: the cloche comes down over the real cake, then the session moves on.
    private func serve() {
        guard !model.isServing else { return }
        if model.isIntroRunning { model.finishIntro() }
        model.lowerCloche(instantly: reduceMotion)
        DecorDraftStore.standard.serve(key: DecorDraftStore.key(for: outcome))
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : Double(DecorStudioModel.clocheDuration) + 0.45))
            onServeNow()
        }
    }

    /// Once served, by the button or by the break running out: the cloche lifts to show the cake.
    private func reveal() async {
        guard served != nil else { return }
        let key = DecorDraftStore.key(for: outcome)
        if DecorDraftStore.standard.served(key: key) == nil { DecorDraftStore.standard.serve(key: key) }
        if model.clocheLift > 0 {
            // The break ran out with the cake on show: it still gets its cloche.
            model.lowerCloche(instantly: reduceMotion)
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : Double(DecorStudioModel.clocheDuration) + 0.45))
        } else {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.5))
        }
        model.raiseCloche(instantly: reduceMotion)
    }

    private var header: some View {
        HStack {
            BreakClockBadge(breakEndsAt: breakEndsAt, total: outcome.bake.breakDuration)
            Spacer()
            Button(action: serve) {
                Text("Serve now", bundle: .module)
                    .textStyle(.control)
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Spacing.s4)
                    .frame(height: HitTarget.minimum)
                    .overlay(Capsule().strokeBorder(Palette.brass, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(model.isServing)
            .accessibilityIdentifier("decorate.serveNow")
        }
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
