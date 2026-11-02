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
    /// Called once the dish is on the stand.
    var onSettled: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hingeDoorAngle) private var hingeDoorAngle
    @State private var step: Step

    init(dish: Dish, progress: Double, browning: Browning, playsIntro: Bool, onSettled: @escaping () -> Void = {}) {
        self.dish = dish
        self.progress = progress
        self.browning = browning
        self.onSettled = onSettled
        _step = State(initialValue: playsIntro ? .atOven : .done)
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
                        doorOpen: 1
                    )
                    .frame(width: size.width, height: size.height)
                    PlatingStationView()
                        .frame(width: size.width, height: size.height)
                }

                let serving = servingFrame(in: size)
                if step >= .grip {
                    DishView(dish: dish, progress: progress, browning: browning)
                        .frame(width: serving.width, height: serving.height)
                        .position(x: serving.midX, y: serving.midY)
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
    }

    private var tongsAreAway: Bool { step == .atOven || step == .done }

    /// The serving's frame in the two-station strip (the station starts one width to the right).
    private func servingFrame(in size: CGSize) -> CGRect {
        let inOven = OvenFrame.servingFrame(dish: dish, in: size, alignsHingeToFold: hingeDoorAngle != nil)
        let side = PlatingStationView.servingSide(in: size)
        let onStand = PlatingStationView.servingFrame(side: side, in: size).offsetBy(dx: size.width, dy: 0)
        // Lifted clear of the oven and brought forward, so it grows toward the stand size.
        let liftedSide = (inOven.width + side) / 2
        let liftedTop = size.height * 0.1
        switch step {
        case .atOven, .reach, .grip:
            return inOven
        case .lift:
            return CGRect(x: inOven.midX - liftedSide / 2, y: liftedTop, width: liftedSide, height: liftedSide)
        case .carry:
            return CGRect(x: onStand.midX - side / 2, y: liftedTop, width: side, height: side)
        case .setDown, .release, .done:
            return onStand
        }
    }

    private func play() async {
        guard step == .atOven else { return }
        if reduceMotion {
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
            try? await Task.sleep(for: .seconds(duration))
        }
        guard !Task.isCancelled else { return }
        onSettled()
    }

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
