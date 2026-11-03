import DesignSystem
import Domain
import SwiftUI

/// The move from the baking station to the plating station. The oven and the plating station
/// sit side by side; tongs reach into the open oven, lift the serving out, and the view pans
/// across to the station while the tongs carry it over and set it on the cake stand.
///
/// Without `playsIntro` (back in the app mid-break) it starts at the station with the dish on the
/// stand. Reduce Motion: a cross-fade straight to that.
struct StationMoveView: View {
    let dish: Dish
    let progress: Double
    let browning: Browning
    /// Serving: the cloche lowers back over the dish.
    var isServing = false
    /// Called once the dish is on the stand.
    var onSettled: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hingeDoorAngle) private var hingeDoorAngle
    @State private var step: Step
    /// 0 the cloche seated on the plate, 1 lifted out of frame. It waits seated over the empty
    /// stand, lifts away while the dish is carried over, and lowers again on the serve.
    @State private var clocheLift: Double

    init(dish: Dish, progress: Double, browning: Browning, playsIntro: Bool, isServing: Bool = false,
         onSettled: @escaping () -> Void = {}) {
        self.isServing = isServing
        self.dish = dish
        self.progress = progress
        self.browning = browning
        self.onSettled = onSettled
        _step = State(initialValue: playsIntro ? .atOven : .done)
        _clocheLift = State(initialValue: playsIntro ? 0 : 1)
    }

    enum Step: Int, Comparable {
        case atOven, reach, grip, lift, carry, setDown, release, done

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        GeometryReader { slot in
            let size = slot.size
            let pan: CGFloat = step >= .carry ? 1 : 0
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    OvenFrame(
                        plate: Text("Prêt.", bundle: .module),
                        isPlateItalic: true,
                        heat: 0.6,
                        dish: dish,
                        dishProgress: progress,
                        browning: browning,
                        doorOpen: 1,
                        isServingTaken: step >= .grip
                    )
                    .frame(width: size.width, height: size.height)
                    station
                        .frame(width: size.width, height: size.height)
                }

                let serving = servingFrame(in: size)
                if step >= .grip {
                    servingArt(frame: serving, slotWidth: size.width)
                        .accessibilityHidden(true)
                }

                let tongsHeight = size.height * 0.75
                // The tips close around the dish a little above its middle.
                let tipsY = serving.minY + serving.height * 0.5
                TongsView(span: serving.width * 0.78, grip: (step >= .grip && step < .release) ? 1 : 0)
                    .frame(width: serving.width * 1.6, height: tongsHeight)
                    .position(x: serving.midX, y: tipsY - tongsHeight / 2 - (tongsAreAway ? size.height : 0))
            }
            .frame(width: size.width * 2, height: size.height, alignment: .topLeading)
            .offset(x: -pan * size.width)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .clipped()
        }
        .task { await play() }
        .onChange(of: isServing) { _, serving in
            guard serving else { return }
            withAnimation(reduceMotion ? nil : .easeIn(duration: Self.lowerDuration)) { clocheLift = 0 }
        }
    }

    private var tongsAreAway: Bool { step == .atOven || step == .done }

    /// The rendered marble stand, cloche lifted away (decorating happens with it off).
    @ViewBuilder
    private var station: some View {
        if let layout = StationRenderLayout.shared {
            RenderedStation(layout: layout, clocheLift: clocheLift, alignsHingeToFold: hingeDoorAngle != nil)
        } else {
            Color.clear
        }
    }

    /// The rendered serving when bundled (servings.py), else the drawn one.
    @ViewBuilder
    private func servingArt(frame: CGRect, slotWidth: CGFloat) -> some View {
        if let serving = OvenDishesLayout.shared?.serving(for: dish) {
            ServingSprite(serving: serving, progress: progress, browning: browning, frame: frame)
                .frame(width: slotWidth * 2, alignment: .topLeading)
        } else {
            DishView(dish: dish, progress: progress, browning: browning)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    /// The rendered serving's frame on the plate: its real size, centred, its base on the plate.
    private func renderedStandFrame(in size: CGSize, oven: CGRect) -> CGRect? {
        guard let layout = StationRenderLayout.shared else { return nil }
        let (scale, origin) = RenderedStation.placement(layout: layout, in: size, alignsHingeToFold: hingeDoorAngle != nil)
        let centreX = origin.x + layout.plateTop.centre[0] * scale
        let topY = origin.y + layout.plateTop.centre[1] * scale
        return CGRect(x: centreX - oven.width / 2, y: topY - oven.height * 0.97, width: oven.width, height: oven.height)
    }

    /// Where the serving stands on the plate (a cupcake, or a cake nearly the plate's width).
    private func standServingFrame(in size: CGSize) -> CGRect {
        guard let layout = StationRenderLayout.shared else { return .zero }
        let fraction: CGFloat = switch dish {
        case .cupcakes: 0.32
        case .smallCake: 0.6
        case .largeCake: 0.72
        }
        return RenderedStation.servingFrame(layout: layout, fraction: fraction, in: size, alignsHingeToFold: hingeDoorAngle != nil)
    }

    /// The serving's frame in the two-station strip (the station starts one width to the right).
    private func servingFrame(in size: CGSize) -> CGRect {
        let rendered = RenderedOven.servingFrame(dish: dish, in: size, alignsHingeToFold: hingeDoorAngle != nil)
        let inOven = rendered ?? OvenFrame.servingFrame(dish: dish, in: size, alignsHingeToFold: hingeDoorAngle != nil)
        let onStand = (rendered.flatMap { renderedStandFrame(in: size, oven: $0) } ?? standServingFrame(in: size))
            .offsetBy(dx: size.width, dy: 0)
        // Lifted clear of the oven and carried at its own size (the rendered serving is to scale
        // in both views; the drawn one grows toward the stand size).
        let liftedSize = rendered != nil ? inOven.size
            : CGSize(width: (inOven.width + onStand.width) / 2, height: (inOven.width + onStand.width) / 2)
        let liftedTop = size.height * 0.1
        switch step {
        case .atOven, .reach, .grip:
            return inOven
        case .lift:
            return CGRect(origin: CGPoint(x: inOven.midX - liftedSize.width / 2, y: liftedTop), size: liftedSize)
        case .carry:
            return CGRect(origin: CGPoint(x: onStand.midX - onStand.width / 2, y: liftedTop), size: onStand.size)
        case .setDown, .release, .done:
            return onStand
        }
    }

    private func play() async {
        guard step == .atOven else { return }
        if reduceMotion {
            clocheLift = 1
            withAnimation(.easeInOut(duration: 0.35)) { step = .done }
            onSettled()
            return
        }
        // Each move: the step, how long it animates, and its curve.
        let moves: [(Step, Double, Curve)] = [
            (.reach, 0.7, .easeOut),
            (.grip, 0.25, .easeInOut),
            (.lift, 0.6, .easeInOut),
            (.carry, 1.3, .easeInOut),
            (.setDown, 0.5, .easeOut),
            (.release, 0.25, .easeInOut),
            (.done, 0.5, .easeIn),
        ]
        // A beat on the open oven before the tongs come in.
        try? await Task.sleep(for: .seconds(0.25))
        for (next, duration, curve) in moves {
            guard !Task.isCancelled else { return }
            withAnimation(curve.animation(duration)) { step = next }
            if next == .carry {
                // The cloche lifts away as the dish comes across, clear before it is set down.
                withAnimation(.easeOut(duration: duration * 0.8)) { clocheLift = 1 }
            }
            try? await Task.sleep(for: .seconds(duration))
        }
        guard !Task.isCancelled else { return }
        onSettled()
    }

    /// How long the cloche takes to lower on the serve.
    static let lowerDuration = 0.8

    private enum Curve {
        case easeIn, easeOut, easeInOut

        func animation(_ duration: Double) -> Animation {
            switch self {
            case .easeIn: .easeIn(duration: duration)
            case .easeOut: .easeOut(duration: duration)
            case .easeInOut: .easeInOut(duration: duration)
            }
        }
    }
}

#Preview("Intro") {
    StationMoveView(dish: .cupcakes, progress: 1, browning: .golden, playsIntro: true)
        .frame(width: 402, height: 437)
}
