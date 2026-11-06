import DesignSystem
import Domain
import SwiftUI

/// The move from the oven to the turntable, drawn over the live scene. Both stand on one marble
/// slab: the live camera starts at the oven with the render's own lens, so the render sits exactly
/// on the live slab. Tongs lift the dish out, the camera slides along the slab (the oven slides
/// away with it), the real stand comes into view with its cloche lifting off, the dish is set
/// down and becomes the live cake, and the same camera climbs to the decorating view.
struct StationMoveView: View {
    let model: DecorStudioModel
    let dish: Dish
    let progress: Double
    let browning: Browning
    /// Called once the camera has reached the decorating view.
    var onSettled: () -> Void = {}

    @Environment(\.hingeDoorAngle) private var hingeDoorAngle
    @State private var step = Step.atOven

    enum Step: Int, Comparable {
        case atOven, reach, grip, lift, carry, setDown, release, done

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        GeometryReader { screen in
            let full = CGSize(width: screen.size.width, height: screen.size.height + screen.safeAreaInsets.top + screen.safeAreaInsets.bottom)
            let slot = CGSize(width: full.width, height: full.height / 2)
            let serving = servingFrame(slot: slot, viewerWidth: full.width)
            ZStack(alignment: .topLeading) {
                // Until the live slab exists, the render's own slab stands in on the app's ground.
                Palette.ground
                    .opacity(model.isSceneReady ? 0 : 1)
                    .animation(.easeOut(duration: 0.3), value: model.isSceneReady)
                SlidingOven(model: model, travel: travel(in: slot)) {
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
                    .frame(width: slot.width, height: slot.height)
                }
                if step >= .grip, step < .release {
                    servingArt(frame: serving, width: full.width)
                        .accessibilityHidden(true)
                }
                let side = TongsView.side(span: serving.width)
                let tipsY = serving.minY + serving.height * 0.55
                TongsView(span: serving.width, grip: (step >= .grip && step < .release) ? 1 : 0)
                    .frame(width: side, height: side)
                    .position(x: serving.midX, y: tipsY - side * (TongsView.tipShare - 0.5) - (tongsAreAway ? full.height : 0))
            }
            .frame(width: full.width, height: full.height, alignment: .topLeading)
            .environment(\.showsOvenSlab, !model.isSceneReady)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .task { await play(slot: slot, full: full) }
        }
        .accessibilityIdentifier("decorate.station")
    }

    private var tongsAreAway: Bool { step == .atOven || step == .done }

    private var aligns: Bool { hingeDoorAngle != nil }

    /// How the oven render sits in its slot: its scale, and where the counter line falls.
    private func ovenPlacement(in slot: CGSize) -> (scale: CGFloat, counterY: CGFloat)? {
        guard let layout = OvenRenderLayout.shared else { return nil }
        let (scale, origin) = RenderedOven.placement(layout: layout, in: slot, alignsHingeToFold: aligns)
        // The slab's front edge in the render: row 673 of the oven camera's picture, a little below
        // the layout's `counterY`, which is the line through the oven's footprint.
        return (scale, origin.y + 673 * scale)
    }

    /// How far the oven moves on screen as the camera slides the length of the slab between them.
    private func travel(in slot: CGSize) -> CGFloat {
        guard let placement = ovenPlacement(in: slot) else { return slot.width * 2.3 }
        // 3667 pixels of focal length, 2300 mm from the camera to the oven's front.
        return placement.scale * 3667 / 2300 * CGFloat(DecorStudioModel.ovenDistance)
    }

    @ViewBuilder
    private func servingArt(frame: CGRect, width: CGFloat) -> some View {
        if let serving = OvenDishesLayout.shared?.serving(for: dish) {
            ServingSprite(serving: serving, progress: progress, browning: browning, frame: frame)
                .frame(width: width, alignment: .topLeading)
        } else {
            DishView(dish: dish, progress: progress, browning: browning)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    /// Where the dish is, in screen points, at the current step.
    private func servingFrame(slot: CGSize, viewerWidth: CGFloat) -> CGRect {
        let rendered = RenderedOven.servingFrame(dish: dish, in: slot, alignsHingeToFold: aligns)
        let inOven = rendered ?? OvenFrame.servingFrame(dish: dish, in: slot, alignsHingeToFold: aligns)
        // Farther from the camera on the stand than in the oven's doorway, so slightly smaller.
        let size = CGSize(width: inOven.width * 0.94, height: inOven.height * 0.94)
        let stand = model.standPoint(viewerWidth: Float(viewerWidth))
        let centreX = CGFloat(stand?.x ?? Float(viewerWidth / 2))
        let plateY = CGFloat(stand?.y ?? Float(slot.height * 0.6))
        let onStand = CGRect(x: centreX - size.width / 2, y: plateY - size.height * 0.97, width: size.width, height: size.height)
        let liftedTop = slot.height * 0.1
        switch step {
        case .atOven, .reach, .grip:
            return inOven
        case .lift:
            return CGRect(origin: CGPoint(x: inOven.midX - inOven.width / 2, y: liftedTop), size: inOven.size)
        case .carry:
            return CGRect(origin: CGPoint(x: onStand.minX, y: liftedTop), size: size)
        case .setDown, .release, .done:
            return onStand
        }
    }

    private func play(slot: CGSize, full: CGSize) async {
        guard step == .atOven else { return }
        let placement = ovenPlacement(in: slot)
        model.beginIntro(pointsPerPixel: Float(placement?.scale ?? 0.42), counterY: Float(placement?.counterY ?? slot.height * 0.7),
                         viewerHeight: Float(DecorStudioView.stageHeight(screen: full)))
        // A beat on the open oven before the tongs come in.
        try? await Task.sleep(for: .seconds(0.25))
        await move(.reach, 0.7, .easeOut(duration: 0.7))
        await move(.grip, 0.25, .easeInOut(duration: 0.25))
        await move(.lift, 0.6, .easeInOut(duration: 0.6))
        // The live scene must be there before the camera can leave.
        while !model.isSceneReady, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-introHold") { try? await Task.sleep(for: .seconds(30)) }
        #endif
        model.startSlide()
        await move(.carry, Double(DecorStudioModel.slideDuration), .easeInOut(duration: Double(DecorStudioModel.slideDuration)))
        await move(.setDown, 0.5, .easeOut(duration: 0.5))
        model.placeDish()
        await move(.release, 0.25, .easeInOut(duration: 0.25))
        await move(.done, 0.45, .easeIn(duration: 0.45))
        guard !Task.isCancelled else { return }
        model.startRise()
        try? await Task.sleep(for: .seconds(Double(DecorStudioModel.riseDuration) * 0.55))
        onSettled()
    }

    private func move(_ next: Step, _ seconds: Double, _ animation: Animation) async {
        guard !Task.isCancelled else { return }
        withAnimation(animation) { step = next }
        try? await Task.sleep(for: .seconds(seconds))
    }
}

/// Moves the oven with the camera. Its own view, so only this redraws on each frame of the slide.
private struct SlidingOven<Content: View>: View {
    let model: DecorStudioModel
    let travel: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        let s = CGFloat(model.slide)
        content.offset(x: -s * s * (3 - 2 * s) * travel)
    }
}
