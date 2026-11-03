import Decorating
import DesignSystem
import Domain
import SwiftUI

/// The decorating studio. Once the dish has settled on the stand, the camera flies from the
/// stage view to straight above the cake (the focus move: pre-rendered background, live cake),
/// then the station slides into place around it. The live viewer fills the screen; the station's
/// panel frames it. The break clock and Serve stay in the header throughout.
struct DecorStudioView: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let breakEndsAt: Date
    let isServing: Bool
    /// False while the stage's tongs move plays on top: load, but don't start the focus move.
    var isActive = true
    let onServe: () -> Void

    @State private var model: DecorStudioModel
    @State private var isRevealed = false
    @State private var hasPlayedFocus = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(recipe: Recipe, outcome: BakeOutcome, breakEndsAt: Date, isServing: Bool, isActive: Bool = true,
         onServe: @escaping () -> Void) {
        self.recipe = recipe
        self.outcome = outcome
        self.breakEndsAt = breakEndsAt
        self.isServing = isServing
        self.isActive = isActive
        self.onServe = onServe
        let key: ViewerAssets.DishKey = Dish(recipeID: recipe.id) == .cupcakes ? .cupcake : .cake
        let geometry = ViewerAssets.profile(key)?.geometry ?? (key == .cupcake ? .cupcake : .cake)
        _model = State(initialValue: DecorStudioModel(geometry: geometry, aspect: 0.46, store: .standard,
                                                      draftKey: DecorDraftStore.key(for: outcome)))
    }

    private var dishKey: ViewerAssets.DishKey { Dish(recipeID: recipe.id) == .cupcakes ? .cupcake : .cake }
    private var browning: Float { GradeCalculator.grade(outcome, served: true).browning == .dark ? 1 : 0 }

    var body: some View {
        GeometryReader { geo in
            let layout = StationLayout.load(for: geo.size) ?? StationLayout.fallback(for: geo.size)
            ZStack(alignment: .top) {
                Palette.ground.ignoresSafeArea()
                if let background = model.focusBackground {
                    Image(uiImage: background)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
                CakeViewerView(model: model, dish: dishKey, browning: browning)
                    .ignoresSafeArea()
                StationView(model: model, layout: layout, isRevealed: isRevealed)
                if isRevealed {
                    ToolCursor(model: model, size: geo.size)
                    snapButtons(layout: layout, size: geo.size)
                }
                header
                    .padding(.horizontal, Spacing.s4)
            }
            .task(id: isActive && geo.size.width > 0) {
                guard isActive, geo.size.width > 0, !hasPlayedFocus else { return }
                hasPlayedFocus = true
                await playFocus(shape: FocusPath.shape(for: geo.size))
            }
        }
        .accessibilityIdentifier("decorate.studio")
        .accessibilityHidden(!isActive)
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            while !isRevealed { try? await Task.sleep(for: .milliseconds(200)) }
            if args.contains("-decorDemo") || args.contains("-decorDemoServe") { model.applyDemo() }
            if args.contains("-decorDemoServe") {
                try? await Task.sleep(for: .seconds(4))
                onServe()
            }
        }
        #endif
    }

    private func playFocus(shape: String) async {
        if !reduceMotion, FocusPath.shared != nil {
            await FocusMovePlayer.play(model: model, shape: shape) { _ in }
        }
        model.focusCamera = nil
        withAnimation(.easeOut(duration: 0.3)) { model.focusBackground = nil }
        isRevealed = true
    }

    /// Top, Angle and Side, down the right edge of the cake window.
    private func snapButtons(layout: StationLayout, size: CGSize) -> some View {
        let (scale, origin) = layout.transform(for: size)
        let window = layout.cakeWindowPx
        return VStack(spacing: Spacing.s2) {
            ForEach(CameraRig.Snap.allCases, id: \.self) { snap in
                Button { model.snap(snap, animated: !reduceMotion) } label: {
                    Text(snapLabel(snap), bundle: .module)
                        .textStyle(.control)
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, Spacing.s3)
                        .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                        .background(Capsule().fill(Palette.ground.opacity(0.7)))
                        .overlay(Capsule().strokeBorder(Palette.line3, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("decorate.view.\(snap.rawValue)")
            }
        }
        .position(x: origin.x + window[2] * scale - HitTarget.minimum, y: origin.y + (window[1] + window[3]) / 2 * scale)
    }

    private func snapLabel(_ snap: CameraRig.Snap) -> LocalizedStringKey {
        switch snap {
        case .top: "Top"
        case .angle: "Angle"
        case .side: "Side"
        }
    }

    private var header: some View {
        HStack {
            BreakClockBadge(breakEndsAt: breakEndsAt, total: outcome.bake.breakDuration)
                .padding(Spacing.s1)
                .background(Circle().fill(Palette.ground.opacity(0.75)))
            Spacer()
            Button(action: onServe) {
                Text("Serve now", bundle: .module)
                    .textStyle(.control)
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Spacing.s4)
                    .frame(height: HitTarget.minimum)
                    .background(Capsule().fill(Palette.ground.opacity(0.7)))
                    .overlay(Capsule().strokeBorder(Palette.line3, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isServing)
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
