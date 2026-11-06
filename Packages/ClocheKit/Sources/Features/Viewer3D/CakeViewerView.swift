import Combine
import Decorating
import RealityKit
import SwiftUI
import UIKit

/// The live 3D cake on its turntable. One finger decorates. Every frame it turns the plate, carries
/// on a stroke if the cake is turning under a resting finger, and brings the scene up to date,
/// which costs nothing unless something changed.
struct CakeViewerView: View {
    let model: DecorStudioModel
    let dish: ViewerAssets.DishKey
    let browning: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let aspect = Float(geo.size.width / max(geo.size.height, 1))
            CakeRenderView(model: model, dish: dish, browning: browning, reduceMotion: reduceMotion)
                .overlay {
                    if !model.isServing, model.introPose == nil { ViewerGestures(model: model) }
                }
                .onChange(of: aspect, initial: true) { model.setAspect(aspect) }
                .accessibilityElement()
                .accessibilityLabel(Text("Your cake", bundle: .module))
        }
    }
}

/// The renderer. An `ARView` with no camera feed rather than a `RealityView`, because it is the
/// one that offers a post-processing pass.
struct CakeRenderView: UIViewRepresentable {
    let model: DecorStudioModel
    let dish: ViewerAssets.DishKey
    let browning: Float
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(ViewerSetting.ovenRoom)
        let post = context.coordinator.post
        view.renderCallbacks.postProcess = { context in
            #if DEBUG
            FrameProbe.notePost(context.targetColorTexture.pixelFormat.rawValue)
            #endif
            post.render(context)
        }
        context.coordinator.load(into: view, model: model, dish: dish, browning: browning, reduceMotion: reduceMotion)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    @MainActor
    final class Coordinator {
        private var subscription: Cancellable?
        let post = ViewerPost()

        func load(into view: ARView, model: DecorStudioModel, dish: ViewerAssets.DishKey, browning: Float, reduceMotion: Bool) {
            Task { @MainActor in
                #if DEBUG
                let loadStart = Date()
                #endif
                guard let made = await ViewerScene.make(dish: dish, dressing: model.dressing, field: model.cream, browning: browning) else { return }
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(made.root)
                view.scene.addAnchor(anchor)
                #if DEBUG
                FrameProbe.note("scene ready in \(Int(Date().timeIntervalSince(loadStart) * 1000)) ms")
                #endif
                made.popsNew = !reduceMotion
                model.sceneDidLoad()
                subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [self] event in
                    MainActor.assumeIsolated {
                        model.frameTick(dt: Float(event.deltaTime))
                        made.setTurntable(angle: model.plateAngle(at: model.now))
                        if let pose = model.introPose ?? model.bowlPose { made.setCamera(pose) } else { made.setCamera(model.rig) }
                        made.showTool(model.tool)
                        if model.introPose == nil { made.useCloseShadows() }
                        made.setCloche(lift: model.clocheLift)
                        made.showsDish(model.isDishOnStand)
                        if model.warmupFrames > 0 {
                            made.setCamera(DecorStudioModel.warmupPose)
                            made.showsDish(true)
                            made.showAllTools()
                            model.stepWarmup()
                        }
                        made.setWarmth(model.warmth)
                        let off = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
                        self.post.configure(off: off, focusDistance: model.focusDistance / 1000, plateRadius: model.geometry.plateRadius / 1000,
                                            depthOfField: model.warmth)
                        made.showGuides(for: model.isServing ? nil : model.step)
                        made.setGuides(onDark: model.isCreamDark)
                        made.update(model.dressing, field: model.cream)
                        #if DEBUG
                        FrameProbe.record(event.deltaTime)
                        #endif
                    }
                }
            }
        }
    }
}

/// One finger, from the moment it lands: a press-and-drag recogniser, so a bead appears under the
/// finger at once and not after a gesture has been decided.
struct ViewerGestures: UIViewRepresentable {
    let model: DecorStudioModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.press(_:)))
        press.minimumPressDuration = 0
        press.allowableMovement = .greatestFiniteMagnitude
        view.addGestureRecognizer(press)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject {
        let model: DecorStudioModel

        init(model: DecorStudioModel) {
            self.model = model
        }

        @objc func press(_ g: UILongPressGestureRecognizer) {
            guard let view = g.view, view.bounds.width > 0 else { return }
            let p = g.location(in: view)
            let x = Float(p.x / view.bounds.width), y = Float(p.y / view.bounds.height)
            switch g.state {
            case .began: model.touchBegan(x: x, y: y)
            case .changed: model.touchMoved(x: x, y: y)
            default: model.touchEnded()
            }
        }
    }
}
