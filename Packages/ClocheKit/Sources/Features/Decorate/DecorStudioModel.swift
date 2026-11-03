import Decorating
import Foundation
import Observation
import UIKit

/// What the player holds.
enum DecorTool: String, CaseIterable, Sendable {
    case cone, spatula, pour, drizzle, dust, topping
}

/// The decorating studio's state: the ordered ops (the cake), the live surfaces rebuilt from
/// them, the tool in hand, the turntable and the camera. Strokes are captured in plate-local
/// coordinates through `CameraRig` → `Turntable` → `SurfaceMapper`.
@MainActor @Observable
final class DecorStudioModel {
    let geometry: CakeGeometry
    private(set) var document: DecorDocument
    private(set) var surfaces: CakeSurfaces
    var rig: CameraRig
    private(set) var turntable = Turntable()
    var speedIndex = 1

    var tool: DecorTool = .cone
    var nozzle: Nozzle = .round
    var beadSize: BeadSize = .medium
    /// Index into the palette (0–7 icing, 8–11 ganache).
    var colour = 1
    var topping = "berries"
    var plate = "carrara"
    var backdrop = "night"
    /// Where the camera is heading after a snap (animated in `stepCamera`); nil when settled.
    private(set) var snapTarget: Float?
    /// The finger on the cake (0...1 from the top-left) for the tool cursor.
    var cursor: SIMD2<Float>?
    /// During the focus move: the camera pose from the exported path, and the background frame.
    var focusCamera: FocusCamera?
    /// Set by the studio from the station layout; the viewer refits with it.
    var windowShare: Float = 1
    var focusBackground: UIImage?

    /// Seconds since the studio opened (turntable and op timing).
    let opened = Date()
    private var stroke: [SurfacePoint] = []
    private var preStroke: CakeSurfaces?
    private var lastStrokeUpdate = Date.distantPast

    /// Where the cake is saved after every change (nil: not saved, e.g. the spike).
    private let store: DecorDraftStore?
    private let draftKey: String

    init(geometry: CakeGeometry, aspect: Float, store: DecorDraftStore? = nil, draftKey: String = "") {
        self.geometry = geometry
        self.store = store
        self.draftKey = draftKey
        let restored = store?.loadDraft(key: draftKey)
        document = restored ?? DecorDocument(dish: geometry)
        surfaces = restored.map { CakeSurfaces(document: $0) } ?? CakeSurfaces(geometry: geometry)
        rig = CameraRig(elevation: 90, target: SIMD3(0, 0, geometry.height), cakeRadius: geometry.radius, aspect: aspect)
    }

    var now: Double { Date().timeIntervalSince(opened) }

    /// Refit the framing distance when the viewer's shape is known.
    /// `windowShare`: the cake window's share of the screen width (the Duo's is narrower).
    func setAspect(_ aspect: Float, windowShare: Float = 1) {
        guard aspect > 0 else { return }
        let fitted = CameraRig(elevation: rig.elevation, target: rig.target, cakeRadius: geometry.radius, aspect: aspect,
                               fill: 0.78 * windowShare)
        rig.baseDistance = fitted.baseDistance
    }
    var canUndo: Bool { document.ops.contains { if case .turntable = $0 { false } else { true } } }

    /// A served cake for display: replayed from its ops, seen at an angle, slowly turning.
    convenience init(served document: DecorDocument, aspect: Float) {
        self.init(geometry: document.dish, aspect: aspect)
        self.document = document
        surfaces = CakeSurfaces(document: document)
        rig.snap(.angle)
        turntable.toggle(at: 0, speed: Turntable.speeds[0])
    }

    /// Time-lapse: rebuilds the cake op by op (turntable ops skipped).
    func replay(step: Duration = .milliseconds(160)) async {
        let ops = document.ops.filter { if case .turntable = $0 { false } else { true } }
        surfaces = CakeSurfaces(geometry: geometry)
        for op in ops {
            try? await Task.sleep(for: step)
            if Task.isCancelled { break }
            surfaces.apply(op)
        }
        surfaces = CakeSurfaces(document: document)
    }

    // MARK: Camera

    /// Top, Angle or Side. Reduce Motion jumps straight there.
    func snap(_ snap: CameraRig.Snap, animated: Bool) {
        if animated { snapTarget = snap.elevation } else { rig.snap(snap); snapTarget = nil }
    }

    /// Called every frame: eases the camera toward a snap target.
    func stepCamera(dt: Float) {
        guard let target = snapTarget else { return }
        let gap = target - rig.elevation
        if abs(gap) < 0.3 {
            rig.elevation = target
            snapTarget = nil
        } else {
            rig.elevation += gap * min(dt * 7, 1)
        }
    }

    // MARK: Turntable

    func toggleTurntable() {
        let speed = Turntable.speeds[speedIndex]
        turntable.toggle(at: now, speed: speed)
        document.ops.append(.turntable(spinning: turntable.isSpinning, speed: Float(speed), time: now))
        save()
    }

    func cycleSpeed() {
        speedIndex = (speedIndex + 1) % Turntable.speeds.count
        turntable.setSpeed(Turntable.speeds[speedIndex], at: now)
    }

    func plateAngle(at time: Double) -> Float { Float(turntable.angle(at: time)) }

    // MARK: Input

    /// The surface point under a screen point (0...1 from the top-left), taking out the turntable.
    func surfacePoint(x: Float, y: Float, aspect: Float) -> SurfacePoint? {
        let ray = rig.ray(x: x, y: y, aspect: aspect)
        let t = now
        let origin = turntable.toPlate(ray.origin, at: t)
        let direction = turntable.toPlate(ray.origin + ray.direction, at: t) - origin
        return SurfaceMapper(geometry: geometry).hit(origin: origin, direction: direction)?.point
    }

    func touchBegan(x: Float, y: Float, aspect: Float) {
        guard let point = surfacePoint(x: x, y: y, aspect: aspect) else {
            if hitsCollar(x: x, y: y, aspect: aspect) { toggleTurntable() }
            return
        }
        switch tool {
        case .topping:
            place(at: point)
        case .pour:
            commit(.pour(colour: max(colour, 8), at: point, scale: 1))
        default:
            preStroke = surfaces
            stroke = [point]
            refreshStroke(force: true)
        }
    }

    /// The brass collar starts and stops the turntable: any tap on the plate's rim band, outside
    /// the cake (the ring itself is a few millimetres wide; the band makes it a fair target).
    func hitsCollar(x: Float, y: Float, aspect: Float) -> Bool {
        let ray = rig.ray(x: x, y: y, aspect: aspect)
        guard abs(ray.direction.z) > 1e-4 else { return false }
        let t = -ray.origin.z / ray.direction.z
        guard t > 0 else { return false }
        let p = ray.origin + ray.direction * t
        let r = (p.x * p.x + p.y * p.y).squareRoot()
        return r > max(geometry.radius + 12, 120) && r < 175
    }

    func touchMoved(x: Float, y: Float, aspect: Float) {
        guard preStroke != nil, let point = surfacePoint(x: x, y: y, aspect: aspect) else { return }
        if let last = stroke.last, last.surface != point.surface {
            touchEnded()
            touchBegan(x: x, y: y, aspect: aspect)
            return
        }
        stroke.append(point)
        refreshStroke(force: false)
    }

    /// Called each frame while a finger rests (the turntable may be carrying the cake under it).
    func touchHeld(x: Float, y: Float, aspect: Float) {
        guard turntable.isSpinning else { return }
        touchMoved(x: x, y: y, aspect: aspect)
    }

    func touchEnded() {
        guard let op = currentStrokeOp, preStroke != nil else { return }
        surfaces = preStroke ?? surfaces
        preStroke = nil
        stroke = []
        commit(op)
    }

    /// A second finger arrived: drop the stroke in progress.
    func touchCancelled() {
        if let preStroke { surfaces = preStroke }
        preStroke = nil
        stroke = []
    }

    private var currentStrokeOp: DecorOp? {
        guard !stroke.isEmpty else { return nil }
        switch tool {
        case .cone: return .pipe(nozzle: nozzle, size: beadSize, colour: colour, points: stroke)
        case .spatula: return .spread(colour: colour, points: stroke)
        case .drizzle: return .drizzle(colour: colour, points: stroke)
        case .dust: return .dust(colour: colour == 3 || colour == 8 ? 3 : 5, points: stroke)
        case .pour, .topping: return nil
        }
    }

    /// Live preview: the whole stroke so far over the field from before it began, at most ~20 Hz.
    private func refreshStroke(force: Bool) {
        guard force || Date().timeIntervalSince(lastStrokeUpdate) > 0.05,
              var preview = preStroke, let op = currentStrokeOp else { return }
        preview.apply(op)
        surfaces = preview
        lastStrokeUpdate = Date()
    }

    private func place(at point: SurfacePoint) {
        if topping == "sprinkles" {
            commit(.sprinkles(seed: UInt64(document.ops.count * 7919 + 17), at: point, radius: 14))
        } else {
            let kinds = DecorCatalog.models(for: topping)
            let n = document.ops.count
            commit(.topping(kind: kinds[n % kinds.count], variant: n % 3, at: point, spin: Float(n) * 2.39))
        }
    }

    private func commit(_ op: DecorOp) {
        document.ops.append(op)
        surfaces.apply(op)
        save()
    }

    private func save() { store?.saveDraft(document, key: draftKey) }

    // MARK: Undo, clear, plate, backdrop

    func undo() {
        guard let index = document.ops.lastIndex(where: { if case .turntable = $0 { false } else { true } }) else { return }
        document.ops.remove(at: index)
        surfaces = CakeSurfaces(document: document)
        save()
    }

    func clear() {
        document.ops.removeAll { if case .turntable = $0 { false } else { true } }
        surfaces = CakeSurfaces(geometry: geometry)
        save()
    }

    func setPlate(_ name: String) {
        plate = name
        commit(.plate(name))
    }

    func setBackdrop(_ name: String) {
        backdrop = name
        commit(.backdrop(name))
    }

    #if DEBUG
    /// A sample cake for screenshots (`-decorDemo`).
    func applyDemo() {
        let r = geometry.radius
        let ring: (Float) -> [SurfacePoint] = { radius in (0...72).map { .top(radius: radius, angle: Float($0) / 72 * 2 * .pi) } }
        var ops: [DecorOp] = [
            .spread(colour: 0, points: (0...12).flatMap { k in ring(r * Float(k) / 12) }),
            .pipe(nozzle: .star, size: .medium, colour: 1, points: ring(r * 0.9)),
            .pipe(nozzle: .round, size: .small, colour: 6, points: ring(r * 0.55)),
            .drizzle(colour: 8, points: (0...40).map { .top(radius: r * 0.4 * Float($0) / 40, angle: Float($0) * 0.5) }),
        ]
        if geometry.hasSide {
            ops.append(.pipe(nozzle: .round, size: .medium, colour: 1, points: (0...72).map { .side(angle: Float($0) / 72 * 2 * .pi, height: 4) }))
        }
        for k in 0..<6 {
            ops.append(.topping(kind: k % 2 == 0 ? "raspberry" : "blueberry", variant: k, at: .top(radius: r * 0.72, angle: Float(k) * 1.047), spin: 0))
        }
        ops.append(.sprinkles(seed: 7, at: .top(radius: 0, angle: 0), radius: r * 0.25))
        for op in ops { commit(op) }
    }
    #endif
}
