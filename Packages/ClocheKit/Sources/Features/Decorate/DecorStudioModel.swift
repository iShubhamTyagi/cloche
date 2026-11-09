import Decorating
import Foundation
import Observation
import os
import simd

/// The three things a player does, one at a time.
enum DecorStep: String, CaseIterable, Sendable {
    case cream, pipe, top
}

/// Names shared by the tray, the model and the scene.
enum DecorCatalog {
    static let colours = ["ivory", "rose", "pistachio", "chocolate"]
    static let toppings = ["raspberries", "blueberries", "sprinkles"]
    /// Where each bowl stands on the slab, beyond the turntable (mm from the plate's centre).
    static let bowlSpots: [SIMD2<Float>] = [SIMD2(335, 150), SIMD2(475, 150), SIMD2(405, 10)]

    static func paletteIndex(_ name: String) -> Int {
        ViewerAssets.palette.firstIndex { $0.name == name } ?? 0
    }

    /// The 3D model(s) a tray topping places.
    static func models(for topping: String) -> [String] {
        switch topping {
        case "raspberries": ["raspberry"]
        case "blueberries": ["blueberry"]
        default: ["sprinkle"]
        }
    }
}

/// A tool in the hand, in world millimetres, Z up. Its handle is along local +X.
struct ToolPose: Equatable, Sendable {
    enum Kind: Sendable { case spatula, bag }
    var kind: Kind
    var position: SIMD3<Float>
    var heading: Float
    var pitch: Float
    var roll: Float
}

/// A camera placed directly, in plate-local millimetres, Z up.
struct CameraPose: Equatable, Sendable {
    var position: SIMD3<Float>
    var target: SIMD3<Float>
    var fov: Float
}

/// The decorating studio's state: the ordered ops (the cake), the cream and dressing derived from
/// them, the step in hand, the turntable and the camera. Cream goes wherever the spatula is
/// rubbed. Beads and toppings are helped: a drag lays beads on the even slots of the ring it
/// started on, and a tap settles a topping in the nearest tidy position.
@MainActor @Observable
final class DecorStudioModel {
    static let studioElevation: Float = 52
    static let servedElevation: Float = 34

    let geometry: CakeGeometry
    private let profile: DishProfile
    private(set) var document: DecorDocument
    private(set) var dressing: CakeDressing
    let cream: CreamField
    var rig: CameraRig
    private(set) var turntable = Turntable()

    var step: DecorStep = .cream {
        didSet {
            if step == .top { showBowls() } else { leaveBowls() }
        }
    }
    var creamColour = DecorCatalog.paletteIndex("ivory")
    var pipeColour = DecorCatalog.paletteIndex("rose")
    var topping = "raspberries"
    private(set) var isSpinning = false
    /// The tool in the hand this moment (nil: nothing).
    private(set) var tool: ToolPose?
    private var toolHeading: Float = -1.2
    private var lastToolPoint: SIMD2<Float>?
    /// The camera's view of the bowls: 0 on the cake, 1 on the bowls.
    private var bowlBlend: Float = 0
    private var bowlTarget: Float = 0
    private(set) var isAtBowls = false
    private(set) var bowlPose: CameraPose?
    /// Serve has begun: the tools are gone and the cloche is in charge.
    private(set) var isServing = false
    /// False while the dish is still in the tongs.
    private(set) var isDishOnStand = true
    /// True once the scene has finished loading.
    private(set) var isSceneReady = false
    /// 0 is the oven's dark room, 1 the warm decorating room.
    private(set) var warmth: Float = 1
    /// The opening move, while it lasts (nil: the camera is the rig's).
    private(set) var introPose: CameraPose?
    /// How far the camera has slid along the slab, 0 at the oven and 1 at the stand.
    private(set) var slide: Float = 0
    private var slideTarget: Float = 0
    private var rise: Float = 0
    private var riseTarget: Float = 0
    private var introLens: (focal: Float, counterY: Float)?
    /// 0 is the cloche seated on the plate, 1 is out of the picture.
    private(set) var clocheLift: Float = 1
    private var clocheTarget: Float = 1
    private var serveCamera: Float = 0
    /// Turned by hand: the angle, and how fast it is still coasting (radians per second).
    private var handAngle: Float = 0
    private var handSpeed: Float = 0
    private var lastRimAngle: Float?
    /// How far the rim moved since the last frame, for the speed it is let go at.
    private var handFlick: Float = 0
    /// The finger on the cake (0...1 of the viewer), for the spatula that follows it.
    private(set) var cursor: SIMD2<Float>?
    private(set) var canUndo = false
    /// Bumped for each bead or topping laid (the tray plays a haptic tick).
    private(set) var tick = 0

    /// Seconds since the studio opened (the served turn).
    let opened = Date()
    private var viewAspect: Float = 1
    private var viewHeight: Float = 600
    private var activeRing: PipeRing?
    private var lastSlot: Int?
    private var strokeSlots: [Int] = []
    private var creamStroke: [CreamPoint] = []
    private var creamSeed: UInt64 = 0
    private var isRubbing = false

    /// Where the cake is saved after every change (nil: not saved).
    private let store: DecorDraftStore?
    private let draftKey: String

    init(geometry: CakeGeometry, profile: DishProfile? = nil, store: DecorDraftStore? = nil, draftKey: String = "") {
        self.geometry = geometry
        self.profile = profile ?? .placeholder(geometry)
        self.store = store
        self.draftKey = draftKey
        let restored = store?.loadDraft(key: draftKey) ?? store?.served(key: draftKey)
        let document = restored ?? DecorDocument(dish: geometry)
        self.document = document
        dressing = CakeDressing(document: document)
        let resolved = profile ?? .placeholder(geometry)
        cream = CreamField(line: DishLine(resolved, hasSide: geometry.hasSide), bladeWidth: geometry.bladeWidth,
                           palette: ViewerAssets.palette.map { let c = $0.rgb; return SIMD3(c.0, c.1, c.2) })
        rig = CameraRig(elevation: Self.studioElevation, target: SIMD3(0, 0, (profile ?? .placeholder(geometry)).height * 500),
                        cakeRadius: geometry.radius, aspect: 0.46)
        rig.fov = 26
        for op in document.ops { applyCream(op) }
        refreshUndo()
    }

    var now: Double { Date().timeIntervalSince(opened) }
    func plateAngle(at time: Double) -> Float { Float(turntable.angle(at: time)) + handAngle }

    // MARK: The bowls

    /// The topping step starts at the bowls: the camera travels along the slab to them.
    func showBowls() {
        guard !isServing else { return }
        bowlTarget = 1
        isAtBowls = true
    }

    /// Back to the cake, with a topping in hand.
    func leaveBowls() {
        bowlTarget = 0
        isAtBowls = false
    }

    func pick(topping name: String) {
        topping = name
        tick += 1
        leaveBowls()
    }

    private func stepBowls(dt: Float) {
        guard bowlBlend != bowlTarget || bowlPose != nil else { return }
        let move = dt / 0.95
        bowlBlend = bowlTarget > bowlBlend ? min(bowlBlend + move, bowlTarget) : max(bowlBlend - move, bowlTarget)
        guard bowlBlend > 0 else {
            bowlPose = nil
            return
        }
        let t = bowlBlend * bowlBlend * (3 - 2 * bowlBlend)
        let centre = SIMD3<Float>(405, 78, -geometry.standHeight + 30)
        let elevation: Float = 50 * .pi / 180, swing: Float = -0.18
        let reach: Float = 1250
        let look = SIMD3(sin(swing) * cos(elevation), -cos(swing) * cos(elevation), sin(elevation))
        let bowls = centre + look * reach
        // An arc rather than a straight line: the camera lifts away a little as it crosses.
        let lift = SIMD3<Float>(0, 0, 160 * sin(t * .pi))
        bowlPose = CameraPose(position: rig.position + (bowls - rig.position) * t + lift,
                              target: rig.target + (centre - rig.target) * t,
                              fov: rig.fov)
    }

    /// What the depth of field focuses on, in millimetres from the camera.
    var focusDistance: Float {
        guard let pose = bowlPose else { return rig.distance }
        return simd_length(pose.target - pose.position)
    }

    /// The bowl under a tap, while the camera is on them.
    private func bowl(atX x: Float, y: Float) -> String? {
        guard let pose = bowlPose else { return nil }
        let forward = simd_normalize(pose.target - pose.position)
        let right = simd_normalize(SIMD3(forward.y, -forward.x, 0))
        let up = simd_cross(right, forward)
        let half = tan(pose.fov * .pi / 360)
        let direction = simd_normalize(forward + right * ((x * 2 - 1) * half * viewAspect) + up * ((1 - y * 2) * half))
        guard abs(direction.z) > 1e-4 else { return nil }
        let rimHeight = -geometry.standHeight + 50
        let p = pose.position + direction * ((rimHeight - pose.position.z) / direction.z)
        let hit = SIMD2(p.x, p.y)
        for (index, spot) in DecorCatalog.bowlSpots.enumerated() where simd_length(hit - spot) < 66 {
            return DecorCatalog.toppings[index]
        }
        return nil
    }

    // MARK: The tool in the hand

    /// Places the tool at the contact point. A blade lies across its travel: across the stroke
    /// when the hand is moving, and along the radius when the cake is turning under it, its
    /// leading edge lifted so the surface runs under it.
    private func updateTool(kind: ToolPose.Kind, world p: SIMD3<Float>, side: Float) {
        let flat = SIMD2(p.x, p.y)
        let moving = isSpinning || handSpeed != 0
        var target = toolHeading
        if moving {
            target = atan2(p.y, p.x)
        } else if let last = lastToolPoint, simd_length(flat - last) > 1.2 {
            let v = flat - last
            // Across the stroke, with the handle toward the person holding it.
            target = atan2(v.x, -v.y)
            if sin(target) > 0 { target += .pi }
        }
        var gap = target - toolHeading
        while gap > .pi { gap -= 2 * .pi }
        while gap < -.pi { gap += 2 * .pi }
        toolHeading += gap * 0.22
        if lastToolPoint == nil || simd_length(flat - (lastToolPoint ?? flat)) > 1.2 { lastToolPoint = flat }
        // A bag is held at a slant, away from the camera so it never hides the cake.
        let pitch: Float = kind == .spatula ? 0.2 + side * 1.1 : 0.62
        tool = ToolPose(kind: kind, position: p, heading: kind == .spatula ? toolHeading : 0.25, pitch: pitch, roll: kind == .spatula ? 0.3 : 0)
    }

    /// Where a point on the plate is now, with the turntable's angle.
    private func worldPoint(radius r: Float, angle a: Float, height z: Float) -> SIMD3<Float> {
        let turned = a + plateAngle(at: now)
        return SIMD3(r * cos(turned), r * sin(turned), z)
    }

    // MARK: The opening move

    /// The oven stands this far along the slab from the plate, in millimetres.
    static let ovenDistance: Float = 1400
    static let slideDuration: Float = 1.7
    static let riseDuration: Float = 1.5
    /// From camera.json: the oven's camera, relative to the plate (mm), and the slab's front edge.
    private static let cameraBack: Float = 2450, cameraUp: Float = 154.5, slabFront: Float = -172

    /// Sets up the camera at the oven. `pointsPerPixel` is how the oven render is drawn on screen;
    /// `counterY` is where its counter line falls, in the viewer's points. The live slab then sits
    /// exactly under the render.
    func beginIntro(pointsPerPixel: Float, counterY: Float, viewerHeight: Float) {
        // 110 mm on a 36 mm sensor across 1200 pixels, at the render's scale on screen.
        let focal = 110 / 36 * 1200 * pointsPerPixel
        introLens = (focal, counterY - viewerHeight / 2)
        viewHeight = viewerHeight
        isDishOnStand = false
        clocheLift = 0
        clocheTarget = 0
        warmth = 0
        slide = 0
        slideTarget = 0
        rise = 0
        riseTarget = 0
        updateIntroPose()
    }

    /// Everything is drawn once under the cover before the shot starts: the GPU builds each
    /// material the first time it is seen, and that must not happen mid-move.
    func sceneDidLoad() {
        if introLens != nil { warmupFrames = 24 } else { isSceneReady = true }
    }

    /// Frames of warm-up left. Counts down, then the scene is ready.
    private(set) var warmupFrames = 0

    func stepWarmup() {
        guard warmupFrames > 0 else { return }
        warmupFrames -= 1
        if warmupFrames == 0 { isSceneReady = true }
    }

    /// A wide view that takes in the stand, the bowls and the tools.
    static let warmupPose = CameraPose(position: SIMD3(260, -1500, 700), target: SIMD3(260, 0, -80), fov: 42)

    /// The dish is on its way: the camera follows along the slab and the cloche lifts off the stand.
    func startSlide() {
        slideTarget = 1
        clocheTarget = 1
        #if DEBUG
        FrameProbe.start()
        #endif
    }

    func placeDish() { isDishOnStand = true }

    /// The dish is down: the camera climbs to the decorating view and the room warms up.
    func startRise() { riseTarget = 1 }

    var isIntroRunning: Bool { introPose != nil }

    /// Jumps to the end (Serve tapped during the move).
    func finishIntro() {
        isDishOnStand = true
        clocheLift = 1
        clocheTarget = 1
        slide = 1
        slideTarget = 1
        warmth = 1
        introPose = nil
        introLens = nil
    }

    /// Where the plate's centre falls in the viewer once the camera has reached the stand (points).
    func standPoint(viewerWidth: Float) -> (x: Float, y: Float, pointsPerMillimetre: Float)? {
        guard let lens = introLens else { return nil }
        let pose = pose(slide: 1, rise: 0, lens: lens)
        let depth = Self.cameraBack
        let forward = simd_normalize(pose.target - pose.position)
        let down = -asin(forward.z)
        let angle = atan((Self.cameraUp) / depth)
        return (viewerWidth / 2, viewHeight / 2 + tan(angle - down) * lens.focal, lens.focal / depth)
    }

    private func pose(slide: Float, rise: Float, lens: (focal: Float, counterY: Float)) -> CameraPose {
        let x = -Self.ovenDistance * (1 - slide)
        let position = SIMD3(x, -Self.cameraBack, Self.cameraUp)
        // Pitch so the slab's front edge lands on the render's counter line.
        let toEdge = Self.cameraBack + Self.slabFront
        let edgeDown = atan((Self.cameraUp + geometry.standHeight) / toEdge)
        let pitch = edgeDown - atan(lens.counterY / lens.focal)
        let start = CameraPose(position: position,
                               target: position + SIMD3(0, cos(pitch), -sin(pitch)) * 1000,
                               fov: 2 * atan(viewHeight / 2 / lens.focal) * 180 / .pi)
        guard rise > 0 else { return start }
        let t = rise * rise * (3 - 2 * rise)
        let startFocus = start.position + simd_normalize(start.target - start.position) * Self.cameraBack
        return CameraPose(position: start.position + (rig.position - start.position) * t,
                          target: startFocus + (rig.target - startFocus) * t,
                          fov: start.fov + (rig.fov - start.fov) * t)
    }

    private func updateIntroPose() {
        guard let lens = introLens else { return }
        let s = slide * slide * (3 - 2 * slide)
        introPose = pose(slide: s, rise: rise, lens: lens)
    }

    private func stepIntro(dt raw: Float) {
        guard introLens != nil else { return }
        // A long frame pauses the move for a moment; it never jumps it forward.
        let dt = min(raw, 1.0 / 24)
        if slide < slideTarget { slide = min(slide + dt / Self.slideDuration, slideTarget) }
        if rise < riseTarget {
            rise = min(rise + dt / Self.riseDuration, riseTarget)
            warmth = rise * rise * (3 - 2 * rise)
        }
        updateIntroPose()
        if rise >= 1 {
            introPose = nil
            introLens = nil
            #if DEBUG
            FrameProbe.finish(label: "move")
            #endif
        }
    }

    /// How long the cloche takes to come down or lift, in seconds.
    static let clocheDuration: Float = 1.1

    /// Serve: everything stops, the camera comes down and the cloche seats over the cake.
    func lowerCloche(instantly: Bool) {
        isServing = true
        cursor = nil
        tool = nil
        leaveBowls()
        handSpeed = 0
        if isSpinning { toggleSpin() }
        clocheTarget = 0
        if instantly {
            clocheLift = 0
            serveCamera = 1
            applyServeCamera()
        }
    }

    /// The reveal: the cloche lifts away and the cake turns slowly to show itself.
    func raiseCloche(instantly: Bool) {
        isServing = true
        clocheTarget = 1
        serveCamera = 1
        applyServeCamera()
        if instantly { clocheLift = 1 }
        if !isSpinning {
            turntable.toggle(at: now, speed: Turntable.speeds[0])
            isSpinning = true
        }
    }

    /// Decorating: the cloche starts out of the picture.
    func settleCloche() {
        clocheLift = 1
        clocheTarget = 1
    }

    /// Starts a served cake with the cloche already over it (a relaunch, or the break running out).
    func seatCloche() {
        isServing = true
        clocheLift = 0
        clocheTarget = 0
        serveCamera = 1
        applyServeCamera()
    }

    private func applyServeCamera() {
        let t = serveCamera * serveCamera * (3 - 2 * serveCamera)
        rig.elevation = Self.studioElevation + (Self.servedElevation - Self.studioElevation) * t
        // Frames the dome while the cloche is down, and settles back on the dish once it lifts.
        let covered = 1 - clocheLift * clocheLift * (3 - 2 * clocheLift)
        let cake = profile.height * 500, dome = geometry.clocheHeight * 0.34
        rig.target.z = cake + (dome - cake) * t * covered
        setAspect(viewAspect)
    }

    /// Time-lapse: rebuilds the cake op by op.
    func replay(step: Duration = .milliseconds(240)) async {
        dressing = CakeDressing(geometry: geometry)
        cream.reset()
        for op in document.ops {
            try? await Task.sleep(for: step)
            if Task.isCancelled { break }
            dressing.apply(op)
            applyCream(op)
        }
        rebuild()
    }

    private func applyCream(_ op: DecorOp) {
        if case let .cream(colour, seed, points) = op { cream.apply(colour: colour, seed: seed, points: points) }
    }

    private func rebuild() {
        dressing = CakeDressing(document: document)
        cream.reset()
        for op in document.ops { applyCream(op) }
    }

    var isCreamDark: Bool {
        let (r, g, b) = ViewerAssets.palette[creamColour].rgb
        return Int(r) + Int(g) + Int(b) < 300
    }

    /// Fits the plate into the viewer, whichever of its sides is tighter.
    func setAspect(_ aspect: Float) {
        guard aspect > 0 else { return }
        viewAspect = aspect
        let e = rig.elevation * .pi / 180
        let halfV = tan(rig.fov * .pi / 360)
        let covered = isServing ? 1 - clocheLift * clocheLift * (3 - 2 * clocheLift) : 0
        let plate = geometry.viewRadius + (geometry.plateRadius - geometry.viewRadius) * covered
        let wide = plate / 0.97 / (halfV * aspect)
        let height = profile.height * 1000 + (geometry.clocheHeight - profile.height * 1000) * covered
        let tall = (plate * sin(e) + height * cos(e) * 0.6) / 0.82 / halfV
        rig.baseDistance = max(wide, tall)
    }

    // MARK: Actions

    /// Starts or stops the turntable.
    func toggleSpin() {
        turntable.toggle(at: now, speed: Turntable.speeds[1])
        isSpinning = turntable.isSpinning
    }

    /// Spreads the top and side evenly in one go (the VoiceOver route: no rubbing needed).
    func creamWholeCake() {
        let band = geometry.bladeWidth * 0.7
        var s: Float = 0
        var points: [CreamPoint] = []
        while s < cream.line.length {
            let r = max(cream.line.at(s).point.x, 1)
            let steps = max(Int(2 * .pi * r / 8), 8)
            points += (0...steps).map { CreamPoint(s: s + band * Float($0) / Float(steps), a: 2 * .pi * Float($0) / Float(steps)) }
            s += band
        }
        commit(.cream(colour: creamColour, seed: UInt64(document.ops.count + 1), points: points))
        tick += 1
    }

    /// Pipes a whole ring at once (the VoiceOver route: no drag needed).
    func pipeWholeRing(_ ring: PipeRing) {
        commit(.beads(colour: pipeColour, ring: ring, slots: Array(0..<geometry.slots(on: ring))))
        tick += 1
    }

    /// Adds the topping in hand at the next free tidy position (the VoiceOver route).
    func placeNextTopping() {
        for ring in geometry.toppingRings {
            for k in 0..<ring.count {
                let point = SurfacePoint.top(radius: ring.radius, angle: Float(k) * 2 * .pi / Float(ring.count))
                if !isTaken(point) {
                    place(at: point)
                    return
                }
            }
        }
    }

    func undo() {
        guard let index = document.ops.lastIndex(where: Self.isDecoration) else { return }
        document.ops.remove(at: index)
        rebuild()
        refreshUndo()
        save()
    }

    // MARK: Input

    /// The ray through a screen point, in the plate's frame (the turntable taken out).
    private func plateRay(x: Float, y: Float) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        let ray = rig.ray(x: x, y: y, aspect: viewAspect)
        let a = -plateAngle(at: now)
        func toPlate(_ p: SIMD3<Float>) -> SIMD3<Float> {
            SIMD3(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a), p.z)
        }
        let origin = toPlate(ray.origin)
        return (origin, toPlate(ray.origin + ray.direction) - origin)
    }

    /// Where the ray through a screen point meets the level plane at `z` millimetres.
    private func hit(x: Float, y: Float, z: Float) -> SIMD2<Float>? {
        let ray = plateRay(x: x, y: y)
        guard abs(ray.direction.z) > 1e-4 else { return nil }
        let t = (z - ray.origin.z) / ray.direction.z
        guard t > 0 else { return nil }
        let p = ray.origin + ray.direction * t
        return SIMD2(p.x, p.y)
    }

    private func height(of ring: PipeRing) -> Float {
        ring == .base ? 0 : profile.topHeight(atRadius: geometry.radius(of: ring) / 1000) * 1000
    }

    /// The angle of a touch on the plate's bare rim, seen from above (nil: not on the rim).
    private func rimAngle(x: Float, y: Float, anywhere: Bool) -> Float? {
        let ray = rig.ray(x: x, y: y, aspect: viewAspect)
        guard abs(ray.direction.z) > 1e-4 else { return nil }
        let p = ray.origin + ray.direction * (-ray.origin.z / ray.direction.z)
        let r = (p.x * p.x + p.y * p.y).squareRoot()
        let start = geometry.hasSide ? geometry.radius(of: .base) + geometry.beadDiameter * 0.55 : geometry.radius * 1.3
        guard anywhere || (r > start && r < geometry.plateRadius * 1.2) else { return nil }
        return atan2(p.y, p.x)
    }

    func touchBegan(x: Float, y: Float) {
        if isAtBowls {
            if let name = bowl(atX: x, y: y) { pick(topping: name) }
            return
        }
        // The camera is still travelling back from the bowls: the cake isn't where the rig says.
        guard bowlPose == nil else { return }
        // The rim belongs to the turntable: drag it round by hand, flick it and it coasts. A touch
        // on the cake itself never counts, even where the plate's plane lies behind it (the far
        // half of a tall cake's top projects onto the plane well past the rim).
        let ray = plateRay(x: x, y: y)
        let onCake = cream.line.hit(origin: ray.origin, direction: ray.direction)
        if onCake == nil, let angle = rimAngle(x: x, y: y, anywhere: false) {
            lastRimAngle = angle
            handSpeed = 0
            return
        }
        cursor = SIMD2(x, y)
        let top = profile.height * 1000
        guard let p = hit(x: x, y: y, z: top) else { return }
        let r = (p.x * p.x + p.y * p.y).squareRoot()
        switch step {
        case .cream:
            creamSeed = UInt64(document.ops.count &* 2_654_435_761 &+ 97)
            creamStroke = []
            cream.begin(colour: creamColour, seed: creamSeed)
            isRubbing = true
            touchMoved(x: x, y: y)
        case .pipe:
            if r <= geometry.radius {
                activeRing = geometry.nearestTopRing(to: r)
            } else if geometry.hasSide, r < geometry.radius * 1.75 {
                activeRing = .base
            } else if r < geometry.radius * 1.2 {
                activeRing = .edge
            } else {
                return
            }
            lastSlot = nil
            strokeSlots = []
            touchMoved(x: x, y: y)
        case .top:
            // Where the finger meets the real surface (a domed top or the side), not a flat plane
            // at the highest point, which misses the shoulder and lands past the edge.
            guard let touch = onCake else { return }
            let tr = min(cream.line.at(touch.s).point.x, geometry.radius * 0.97)
            if topping == "sprinkles" {
                let seed = UInt64(document.ops.count * 7919 + 17)
                commit(.sprinkles(seed: seed, at: .top(radius: tr, angle: touch.a), radius: geometry.radius * 0.16))
                tick += 1
            } else {
                place(at: freePlacement(radius: tr, angle: touch.a))
            }
        }
    }

    func touchMoved(x: Float, y: Float) {
        if let last = lastRimAngle {
            guard let angle = rimAngle(x: x, y: y, anywhere: true) else { return }
            var delta = angle - last
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            handAngle += delta
            handFlick += delta
            lastRimAngle = angle
            return
        }
        cursor = SIMD2(x, y)
        if isRubbing {
            let ray = plateRay(x: x, y: y)
            guard let point = cream.line.hit(origin: ray.origin, direction: ray.direction) else { return }
            creamStroke.append(point)
            cream.extend(to: point)
            let (at, normal) = cream.line.at(point.s)
            let lift = cream.height(s: point.s, a: point.a) + 1
            updateTool(kind: .spatula, world: worldPoint(radius: at.x + normal.x * lift, angle: point.a, height: at.y + normal.y * lift),
                       side: min(max((normal.x - 0.3) / 0.6, 0), 1))
            return
        }
        guard let ring = activeRing, let p = hit(x: x, y: y, z: height(of: ring)) else { return }
        let angle = atan2(p.y, p.x)
        updateTool(kind: .bag, world: worldPoint(radius: geometry.radius(of: ring), angle: angle, height: height(of: ring) + geometry.beadDiameter * 0.9), side: 0)
        let slot = geometry.slot(at: angle, on: ring)
        guard slot != lastSlot else { return }
        var fresh = [slot]
        if let last = lastSlot {
            // A fast finger leaves no gaps: fill the short way round from the last slot.
            let n = geometry.slots(on: ring)
            var delta = (slot - last + n) % n
            if delta > n / 2 { delta -= n }
            let direction = delta > 0 ? 1 : -1
            fresh = (1...abs(delta)).map { (last + $0 * direction + n) % n }
        }
        lastSlot = slot
        strokeSlots += fresh
        dressing.apply(.beads(colour: pipeColour, ring: ring, slots: fresh))
        tick += 1
    }

    /// Called every frame: the cloche and camera move, a flicked plate coasts, and a resting finger
    /// keeps working as the cake turns under it, which is how a real turntable gives a smooth band
    /// or a closed ring.
    func frameTick(dt: Float) {
        if clocheLift != clocheTarget {
            let step = dt / Self.clocheDuration
            clocheLift = clocheTarget > clocheLift ? min(clocheLift + step, clocheTarget) : max(clocheLift - step, clocheTarget)
            if isServing {
                if clocheTarget == 0 { serveCamera = min(serveCamera + step, 1) }
                applyServeCamera()
            }
        }
        stepIntro(dt: dt)
        stepBowls(dt: dt)
        if lastRimAngle != nil {
            if dt > 0 { handSpeed = handSpeed * 0.6 + handFlick / dt * 0.4 }
            handFlick = 0
        } else if handSpeed != 0 {
            handAngle += handSpeed * dt
            handSpeed *= exp(-1.1 * dt)
            if abs(handSpeed) < 0.02 { handSpeed = 0 }
        }
        if isSpinning || handSpeed != 0, let cursor, !isServing { touchMoved(x: cursor.x, y: cursor.y) }
    }

    func touchEnded() {
        if lastRimAngle != nil {
            lastRimAngle = nil
            return
        }
        defer {
            activeRing = nil
            lastSlot = nil
            strokeSlots = []
            isRubbing = false
            creamStroke = []
            cursor = nil
            tool = nil
            lastToolPoint = nil
        }
        if isRubbing, !creamStroke.isEmpty {
            document.ops.append(.cream(colour: creamColour, seed: creamSeed, points: creamStroke))
            refreshUndo()
            save()
            return
        }
        guard let ring = activeRing, !strokeSlots.isEmpty else { return }
        document.ops.append(.beads(colour: pipeColour, ring: ring, slots: strokeSlots))
        refreshUndo()
        save()
    }

    /// Where a topping tapped at a point on the top goes: exactly there, anywhere on the top.
    /// Close to a free tidy position it snaps onto it, a little, so a careful ring still comes out
    /// even. It never sits inside another piece: it is nudged out until the two just touch.
    private func freePlacement(radius r: Float, angle a: Float) -> SurfacePoint {
        let kind = DecorCatalog.models(for: topping)[0]
        let mine = Self.pieceSize(kind) * pieceScale
        let limit = geometry.radius * 0.95 - mine / 2
        var p = SIMD2(r * cos(a), r * sin(a))
        var snapped = false
        for ring in geometry.toppingRings {
            for k in 0..<ring.count {
                let angle = ring.radius > 0 ? Float(k) * 2 * .pi / Float(ring.count) : 0
                guard !isTaken(.top(radius: ring.radius, angle: angle)) else { continue }
                let spot = SIMD2(ring.radius * cos(angle), ring.radius * sin(angle))
                if !snapped, simd_length(spot - p) < mine * 0.6 {
                    p = spot
                    snapped = true
                }
            }
        }
        let others = dressing.placements.filter { $0.kind != "sprinkle" }
        for _ in 0..<4 {
            var moved = false
            for other in others {
                let q = SIMD2(other.at.a * cos(other.at.b), other.at.a * sin(other.at.b))
                let gap = (mine + Self.pieceSize(other.kind) * pieceScale) / 2 * 0.9
                let d = simd_length(p - q)
                guard d < gap else { continue }
                // Straight away from it; a tap dead on its centre goes outward.
                let away = d > 0.01 ? (p - q) / d : (simd_length(q) > 0.01 ? simd_normalize(q) : SIMD2(1, 0))
                p = q + away * gap
                moved = true
            }
            let length = simd_length(p)
            if length > limit { p *= limit / length }
            if !moved { break }
        }
        return .top(radius: simd_length(p), angle: atan2(p.y, p.x))
    }

    /// A piece's width on the cake, in millimetres at full size.
    private static func pieceSize(_ kind: String) -> Float {
        switch kind {
        case "raspberry": 18
        case "blueberry": 11
        default: 12
        }
    }

    /// Toppings are drawn smaller on a cupcake (ViewerScene's scale).
    private var pieceScale: Float { geometry.hasSide ? 1 : 0.62 }

    private func isTaken(_ point: SurfacePoint) -> Bool {
        dressing.placements.contains { $0.at == point }
    }

    private func place(at point: SurfacePoint) {
        let kinds = DecorCatalog.models(for: topping)
        let n = document.ops.count
        commit(.topping(kind: kinds[n % kinds.count], variant: n % 3, at: point, spin: Float(n) * 2.39))
        tick += 1
    }

    private func commit(_ op: DecorOp) {
        document.ops.append(op)
        dressing.apply(op)
        applyCream(op)
        refreshUndo()
        save()
    }

    private func refreshUndo() {
        let can = document.ops.contains(where: Self.isDecoration)
        if can != canUndo { canUndo = can }
    }

    private static func isDecoration(_ op: DecorOp) -> Bool {
        switch op {
        case .cream, .beads, .topping, .sprinkles: true
        default: false
        }
    }

    private func save() { store?.saveDraft(document, key: draftKey) }

    #if DEBUG
    /// A sample cake for screenshots (`-decorDemo`).
    func applyDemo() {
        document.ops.removeAll()
        rebuild()
        creamColour = DecorCatalog.paletteIndex("ivory")
        creamWholeCake()
        pipeColour = DecorCatalog.paletteIndex("rose")
        for ring in geometry.pipeRings where ring != .middle { pipeWholeRing(ring) }
        topping = "raspberries"
        for _ in 0..<(geometry.hasSide ? 12 : 6) { placeNextTopping() }
        topping = "blueberries"
        placeNextTopping()
        step = .top
        leaveBowls()
    }

    /// `-decorHold spatula|bag`: rests the tool on the cake with the turntable going, for a look at it.
    func applyHold(_ name: String) {
        step = name == "bag" ? .pipe : .cream
        toggleSpin()
        let r = name == "bag" ? geometry.radius(of: .edge) : geometry.radius * 0.62
        let z = profile.topHeight(atRadius: r / 1000) * 1000
        if let p = rig.project(SIMD3(r * cos(-1.2), r * sin(-1.2), z), aspect: viewAspect) { touchBegan(x: p.x, y: p.y) }
    }

    /// `-decorHandSpin`: a flick of the rim, so the coast can be checked.
    func applyHandSpin() { handSpeed = 3 }

    /// `-decorCamera top|angle|side`: the review cameras, for captures only.
    func applyReviewCamera(_ name: String) {
        switch name {
        case "top": rig.elevation = 88
        case "side": rig.elevation = 12
        default: rig.elevation = Self.studioElevation
        }
        setAspect(viewAspect)
    }

    /// `-decorRub`: a few hand strokes, in two colours, so the cream's marks can be looked at.
    func applyRub() {
        document.ops.removeAll()
        rebuild()
        step = .cream
        let line = cream.line.length
        func stroke(_ colour: Int, _ seed: UInt64, _ points: [CreamPoint]) { commit(.cream(colour: colour, seed: seed, points: points)) }
        let ivory = DecorCatalog.paletteIndex("ivory"), rose = DecorCatalog.paletteIndex("rose")
        stroke(ivory, 1, (0...70).map { CreamPoint(s: line * 0.3, a: Float($0) / 70 * 3.6 + 2.6) })
        stroke(ivory, 2, (0...70).map { CreamPoint(s: line * 0.5, a: Float($0) / 70 * 2.2 + 3.4) })
        stroke(ivory, 3, (0...50).map { CreamPoint(s: line * (0.1 + 0.7 * Float($0) / 50), a: -1.57 + sin(Float($0) * 0.2) * 0.3) })
        stroke(rose, 4, (0...60).map { CreamPoint(s: line * 0.42, a: Float($0) / 60 * 1.8 + 3.8) })
    }

    /// `-decorProbe`: rubs cream round the cake through the real input path for three seconds,
    /// then pipes a ring, and logs the frame times, so smoothness is a number and not an impression.
    func runDragProbe() async {
        document.ops.removeAll()
        rebuild()
        step = .cream
        FrameProbe.start()
        let topLevel = profile.height * 1000
        let r = geometry.radius * 0.6
        finishIntro()
        func screen(_ a: Float, _ r: Float, _ z: Float) -> SIMD2<Float>? { rig.project(SIMD3(r * cos(a), r * sin(a), z), aspect: viewAspect) }
        if let p = screen(0, r, topLevel) { touchBegan(x: p.x, y: p.y) }
        for i in 1...180 {
            try? await Task.sleep(for: .milliseconds(16))
            if let p = screen(Float(i) / 180 * 4 * .pi, r * (1 - Float(i) / 400), topLevel) { touchMoved(x: p.x, y: p.y) }
        }
        touchEnded()
        FrameProbe.finish(label: "cream")
        // A blade held still while the cake turns under it.
        FrameProbe.start()
        toggleSpin()
        if let p = screen(-1.57, geometry.radius * 0.75, topLevel) { touchBegan(x: p.x, y: p.y) }
        try? await Task.sleep(for: .seconds(4))
        touchEnded()
        toggleSpin()
        FrameProbe.finish(label: "spin")
        FrameProbe.note("spin stroke kept: \(document.ops.count) ops")
        step = .pipe
        FrameProbe.start()
        let ring = PipeRing.edge
        let z = height(of: ring), edge = geometry.radius(of: ring)
        if let p = screen(0, edge, z) { touchBegan(x: p.x, y: p.y) }
        for i in 1...120 {
            try? await Task.sleep(for: .milliseconds(16))
            if let p = screen(Float(i) / 120 * 2 * .pi, edge, z) { touchMoved(x: p.x, y: p.y) }
        }
        touchEnded()
        FrameProbe.finish(label: "pipe")
        // A real drag on the rim, through the same input path: it must turn the plate, and lay nothing.
        let opsBefore = document.ops.count, angleBefore = plateAngle(at: now)
        let rim = geometry.plateRadius * 0.97
        if let p = screen(-1.2, rim, 0) { touchBegan(x: p.x, y: p.y) }
        for i in 1...30 {
            try? await Task.sleep(for: .milliseconds(16))
            if let p = screen(-1.2 + Float(i) / 30 * 0.9, rim, 0) { touchMoved(x: p.x, y: p.y) }
        }
        touchEnded()
        let turned = plateAngle(at: now) - angleBefore
        FrameProbe.note("rim drag turned \(turned) rad, ops added \(document.ops.count - opsBefore)")
        try? await Task.sleep(for: .seconds(1))
        FrameProbe.note("coasted to \(plateAngle(at: now) - angleBefore) rad")
        // The bowls, through the same taps a finger makes.
        step = .top
        try? await Task.sleep(for: .seconds(1.3))
        let atBowls = isAtBowls && bowlPose != nil
        if let pose = bowlPose {
            let spot = DecorCatalog.bowlSpots[1]
            let forward = simd_normalize(pose.target - pose.position)
            let right = simd_normalize(SIMD3(forward.y, -forward.x, 0))
            let up = simd_cross(right, forward)
            let half = tan(pose.fov * .pi / 360)
            let d = SIMD3(spot.x, spot.y, -geometry.standHeight + 50) - pose.position
            let depth = simd_dot(d, forward)
            let tapX = (simd_dot(d, right) / depth / (half * viewAspect) + 1) / 2
            let tapY = (1 - simd_dot(d, up) / depth / half) / 2
            touchBegan(x: tapX, y: tapY)
            touchEnded()
        }
        let picked = topping
        try? await Task.sleep(for: .seconds(1.3))
        let backAtCake = bowlPose == nil
        let placedBefore = dressing.placements.count
        // The same spot four times (each lands in the nearest gap), then the far half of the top,
        // which used to read as the plate's rim and turn the cake instead.
        for angle: Float in [0, 0, 0, 0, 1.57, 1.2] {
            let z = profile.topHeight(atRadius: geometry.radius * 0.5 / 1000) * 1000
            if let p = rig.project(SIMD3(geometry.radius * 0.5 * cos(angle - plateAngle(at: now)), geometry.radius * 0.5 * sin(angle - plateAngle(at: now)), z), aspect: viewAspect) {
                touchBegan(x: p.x, y: p.y)
                touchEnded()
            }
        }
        FrameProbe.note("bowls: reached \(atBowls), picked \(picked), back at cake \(backAtCake), placed \(dressing.placements.count - placedBefore)")
        let start = Date()
        undo()
        FrameProbe.note("undo \(Int(Date().timeIntervalSince(start) * 1000)) ms")
    }
    #endif
}

#if DEBUG
/// Frame times during `-decorProbe`.
@MainActor
enum FrameProbe {
    private static var frames: [Double]?
    private nonisolated static let logger = Logger(subsystem: "com.shubhamtyagi.cloche", category: "Probe")

    nonisolated(unsafe) private static var postLogged = false
    nonisolated static func notePost(_ format: UInt) {
        guard !postLogged else { return }
        postLogged = true
        logger.notice("post-process running, format \(format, privacy: .public)")
    }
    static func note(_ text: String) { logger.notice("\(text, privacy: .public)") }
    private static var started = Date()
    static func start() {
        frames = []
        started = Date()
    }
    static func record(_ dt: Double) { frames?.append(dt) }

    static func finish(label: String) {
        let slow = frames?.filter { $0 > 0.05 }.count ?? 0
        logger.notice("\(label, privacy: .public): \(slow, privacy: .public) frames over 50 ms")
        guard let sorted = frames?.sorted(), !sorted.isEmpty else { return }
        frames = nil
        let median = sorted[sorted.count / 2] * 1000, p95 = sorted[sorted.count * 95 / 100] * 1000
        let worst = (sorted.last ?? 0) * 1000
        let fps = Double(sorted.count) / Date().timeIntervalSince(started)
        logger.notice("probe \(label, privacy: .public) \(fps, format: .fixed(precision: 1), privacy: .public) fps: median \(median, format: .fixed(precision: 1), privacy: .public) ms, p95 \(p95, format: .fixed(precision: 1), privacy: .public) ms, worst \(worst, format: .fixed(precision: 1), privacy: .public) ms")
    }
}
#endif
