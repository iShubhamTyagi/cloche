import Decorating
import RealityKit
import SwiftUI
import UIKit

/// The live 3D cake on the turntable. One finger decorates with the tool in hand; two fingers
/// tilt the camera between top and side; a pinch zooms. Every frame it turns the plate to the
/// turntable's angle, follows the camera rig, extends a held stroke and shows new icing.
struct CakeViewerView: View {
    let model: DecorStudioModel
    let dish: ViewerAssets.DishKey
    let browning: Float
    var showsSurface = true

    @State private var scene: ViewerScene?
    @State private var subscription: EventSubscription?
    @State private var touch = TouchState()

    var body: some View {
        GeometryReader { geo in
            let aspect = Float(geo.size.width / max(geo.size.height, 1))
            RealityView { content in
                content.camera = .virtual
                guard let made = await ViewerScene.make(dish: dish, surfaces: model.surfaces, browning: browning) else { return }
                content.add(made.root)
                made.setCamera(model.rig)
                made.showsSurface(showsSurface)
                scene = made
                let model = model, touch = touch
                #if DEBUG
                let spike = ProcessInfo.processInfo.arguments.contains("-viewerSpike")
                #endif
                subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    MainActor.assumeIsolated {
                        made.setTurntable(angle: model.plateAngle(at: model.now))
                        model.stepCamera(dt: Float(event.deltaTime))
                        if let focus = model.focusCamera {
                            made.setCamera(position: focus.position, target: focus.target, fov: focus.fov)
                            made.showsSurface(false)
                        } else {
                            made.setCamera(model.rig)
                            made.showsSurface(showsSurface)
                        }
                        if let p = touch.location { model.touchHeld(x: p.x, y: p.y, aspect: touch.aspect) }
                        #if DEBUG
                        if spike {
                            let t0 = CACurrentMediaTime()
                            made.remeshForSpike(surfaces: model.surfaces)
                            SpikeLog.record(frame: event.deltaTime, update: CACurrentMediaTime() - t0, label: "realitykit")
                        }
                        #endif
                        made.update(surfaces: model.surfaces)
                    }
                }
            }
            .overlay {
                ViewerGestures(touch: touch, aspect: aspect, model: model)
            }
            .onChange(of: aspect, initial: true) { model.setAspect(aspect) }
            .accessibilityElement()
            .accessibilityLabel(Text("Cake on the turntable", bundle: .module))
            .accessibilityHint(Text("Drag to decorate with the tool in hand. Two fingers tilt the view.", bundle: .module))
        }
    }
}

/// The finger currently on the cake, shared between the gestures and the frame tick.
@MainActor
final class TouchState {
    var location: SIMD2<Float>?
    var aspect: Float = 1
}

/// UIKit gestures over the viewer: a 1-finger press-and-drag (it starts on touch-down so a
/// resting finger lays a ring while the plate turns), a 2-finger pan to tilt, and a pinch.
struct ViewerGestures: UIViewRepresentable {
    let touch: TouchState
    let aspect: Float
    let model: DecorStudioModel

    func makeCoordinator() -> Coordinator { Coordinator(touch: touch, model: model) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.press(_:)))
        press.minimumPressDuration = 0
        press.numberOfTouchesRequired = 1
        press.allowableMovement = .greatestFiniteMagnitude
        let tilt = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tilt(_:)))
        tilt.minimumNumberOfTouches = 2
        tilt.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        for g in [press, tilt, pinch] as [UIGestureRecognizer] {
            g.delegate = context.coordinator
            view.addGestureRecognizer(g)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        touch.aspect = aspect
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let touch: TouchState
        let model: DecorStudioModel
        private var lastTilt: CGFloat = 0

        init(touch: TouchState, model: DecorStudioModel) {
            self.touch = touch
            self.model = model
        }

        private func normalized(_ g: UIGestureRecognizer) -> SIMD2<Float>? {
            guard let view = g.view, view.bounds.width > 0 else { return nil }
            let p = g.location(in: view)
            return SIMD2(Float(p.x / view.bounds.width), Float(p.y / view.bounds.height))
        }

        @objc func press(_ g: UILongPressGestureRecognizer) {
            guard let p = normalized(g) else { return }
            switch g.state {
            case .began:
                touch.location = p
                model.cursor = p
                model.touchBegan(x: p.x, y: p.y, aspect: touch.aspect)
            case .changed:
                touch.location = p
                model.cursor = p
                model.touchMoved(x: p.x, y: p.y, aspect: touch.aspect)
            default:
                touch.location = nil
                model.cursor = nil
                model.touchEnded()
            }
        }

        @objc func tilt(_ g: UIPanGestureRecognizer) {
            guard let view = g.view else { return }
            if g.state == .began {
                lastTilt = 0
                touch.location = nil
                model.touchCancelled()
            }
            let dy = g.translation(in: view).y
            model.rig.tilt(by: Float((dy - lastTilt) / view.bounds.height * 120))
            lastTilt = dy
        }

        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            if g.state == .began {
                touch.location = nil
                model.touchCancelled()
            }
            model.rig.pinch(scale: Float(g.scale))
            g.scale = 1
        }

        nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            !(g is UILongPressGestureRecognizer || other is UILongPressGestureRecognizer)
        }
    }
}
