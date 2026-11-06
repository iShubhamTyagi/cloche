import Decorating
import Foundation
import RealityKit
import UIKit

/// The live viewer's entities. RealityKit frame: metres, +Y up, the viewer at +Z; the origin is
/// the centre of the plate's top. `spinner` turns on the served screen and carries the plate, the
/// cake and everything on it.
///
/// What keeps a drag smooth: cream updates only the rows the blade touched (`CreamLayer`), and a
/// bead or topping is one more copy of a shared mesh.
@MainActor
final class ViewerScene {
    let root = Entity()
    let spinner = Entity()
    let camera = PerspectiveCamera()
    let profile: DishProfile
    let geometry: CakeGeometry
    /// New beads and toppings pop into place (off on the first fill and for Reduce Motion).
    var popsNew = false

    private let cream: CreamLayer
    private let beadMeshes: [MeshResource]
    private var beadShade: ModelEntity?
    private let beads = Entity()
    private let toppings = Entity()
    private let cloche = Entity()
    private let tableware = ViewerTableware()
    private var keyLight: DirectionalLight?
    private var hasCloseShadows = false
    /// Everything that is the dish rather than the stand: hidden until it is set down.
    private let dishGroup = Entity()
    private var slab: Entity?
    private var slabMaterial: PhysicallyBasedMaterial?
    private var backdrop: ModelEntity?
    private var shownWarmth: Float = -1
    private var shownClocheLift: Float = -1
    private let pipeGuides = Entity()
    private let toppingGuides = Entity()
    private var beadEntities: [CakeDressing.BeadKey: (entity: ModelEntity, colour: Int)] = [:]
    private var beadMaterials: [Int: PhysicallyBasedMaterial] = [:]
    private var toppingModels: [String: Entity] = [:]
    private var shownPlacements: [CakeDressing.Placement] = []
    private var shownRevision = -1
    private var guideOnDark = false
    private var shownStep: DecorStep?

    private init(profile: DishProfile, geometry: CakeGeometry, cream: CreamLayer, beadMeshes: [MeshResource]) {
        self.profile = profile
        self.geometry = geometry
        self.cream = cream
        self.beadMeshes = beadMeshes
    }

    static func make(dish: ViewerAssets.DishKey, dressing: CakeDressing, field: CreamField, browning: Float) async -> ViewerScene? {
        let profile = ViewerAssets.profile(dish) ?? DishProfile.placeholder(dressing.geometry)
        let geometry = dressing.geometry
        // The vertex work runs off the main actor, so the tongs move keeps playing.
        #if DEBUG
        var mark = Date()
        func lap(_ name: String) { FrameProbe.note("load \(name) \(Int(Date().timeIntervalSince(mark) * 1000)) ms"); mark = Date() }
        #else
        func lap(_ name: String) {}
        #endif
        let meshes = await Task.detached(priority: .userInitiated) {
            (beads: (1...6).map { ViewerMesh.bead(diameter: geometry.beadDiameter, seed: UInt64($0)) }, cakeTop: ViewerMesh.cakeTop(profile), cakeSide: ViewerMesh.cakeSide(profile))
        }.value
        lap("meshes")
        var beadResources: [MeshResource] = []
        for bead in meshes.beads {
            if let made = await resource(bead) { beadResources.append(made) }
        }
        guard let cream = await CreamLayer(line: field.line), !beadResources.isEmpty else { return nil }
        let scene = ViewerScene(profile: profile, geometry: geometry, cream: cream, beadMeshes: beadResources)
        scene.beadShade = await ViewerSetting.contactShadow(radius: geometry.beadDiameter / 1000 * 0.72, strength: 0.34)
        lap("cream")
        await scene.build(dish: dish, browning: browning, cakeTop: meshes.cakeTop, cakeSide: meshes.cakeSide)
        lap("build")
        await scene.preloadToppings()
        var models = scene.toppingModels
        await scene.tableware.addBowls(to: scene.root, slabTop: -geometry.standHeight / 1000, models: &models)
        scene.toppingModels = models
        await scene.tableware.addTools(to: scene.root)
        lap("toppings")
        scene.update(dressing, field: field)
        lap("first update")
        return scene
    }

    private static func resource(_ data: MeshData, lathe: Lathe? = nil) async -> MeshResource? {
        guard let mesh = try? lowLevelMesh(data, lathe: lathe) else { return nil }
        return try? await MeshResource(from: mesh)
    }

    /// Which way a turned surface's texture runs, for its normal map: +v outward or upward.
    enum Lathe { case top, side }

    /// Only what the four toppings on offer need.
    private func preloadToppings() async {
        for kind in DecorCatalog.toppings.flatMap(DecorCatalog.models(for:)) where kind != "sprinkle" {
            for v in 0..<3 {
                if let url = Bundle.module.url(forResource: "topping_\(kind)_\(v)", withExtension: "usdz"),
                   let entity = try? await Entity(contentsOf: url) {
                    toppingModels["\(kind)_\(v)"] = ToppingFactory.polished(entity, kind: kind)
                }
            }
        }
        if let url = Bundle.module.url(forResource: "topping_sprinkle_0", withExtension: "usdz"),
           let rod = try? await Entity(contentsOf: url) {
            for i in 0..<ToppingFactory.sprinkleColours.count {
                toppingModels["sprinkle_\(i)"] = ToppingFactory.tinted(rod.clone(recursive: true), colour: i)
            }
        }
    }

    private func build(dish: ViewerAssets.DishKey, browning: Float, cakeTop: MeshData, cakeSide: MeshData) async {
        root.addChild(spinner)
        root.addChild(camera)
        camera.camera.near = 0.01
        camera.camera.far = 20

        // The marble stand: the base and its bearing stay still; the plate turns with the cake, and
        // the brass marker in its edge shows it turning.
        let scale: Float = 1
        var marbleStand = await ViewerAssets.material("marble_", fallback: UIColor(white: 0.9, alpha: 1), roughness: 0.3)
        marbleStand.roughness = .init(floatLiteral: 0.5)
        marbleStand.specular = 0.3
        var brass = PhysicallyBasedMaterial()
        brass.baseColor = .init(tint: UIColor(red: 0.78, green: 0.6, blue: 0.33, alpha: 1))
        brass.metallic = .init(floatLiteral: 1)
        brass.roughness = .init(floatLiteral: 0.32)
        await addPart("stand_base", marbleStand, to: root, scale: scale)
        await addPart("stand_brass", brass, to: root, scale: scale)
        await addPart("stand_plate", marbleStand, to: spinner, scale: scale)
        await addPart("stand_marker", brass, to: spinner, scale: scale)
        await buildCloche(brass: brass, scale: scale)
        // Where the dish meets the plate.
        let seat = await ViewerSetting.contactShadow(radius: geometry.radius / 1000 * 1.2, strength: 0.6)
        seat.position.y = 0.0002
        dishGroup.addChild(seat)

        // The cake: baked maps on the exported profile; the dark state tints the golden maps.
        let shade = CGFloat(1 - 0.38 * browning)
        let top = await ViewerAssets.material("\(dish.rawValue)_top_", fallback: UIColor(red: 0.8, green: 0.55, blue: 0.27, alpha: 1), shade: shade)
        let side = await ViewerAssets.material("\(dish.rawValue)_side_", fallback: UIColor(red: 0.72, green: 0.45, blue: 0.2, alpha: 1), shade: shade)
        if let r = await Self.resource(cakeTop, lathe: .top) { dishGroup.addChild(ModelEntity(mesh: r, materials: [top])) }
        if let r = await Self.resource(cakeSide, lathe: .side) { dishGroup.addChild(ModelEntity(mesh: r, materials: [side])) }
        if !geometry.hasSide, let r = await Self.resource(ViewerMesh.crownUnderside(profile)) {
            var crumb = PhysicallyBasedMaterial()
            crumb.baseColor = .init(tint: UIColor(red: 0.76, green: 0.58, blue: 0.36, alpha: 1))
            crumb.roughness = .init(floatLiteral: 0.8)
            dishGroup.addChild(ModelEntity(mesh: r, materials: [crumb]))
        }
        dishGroup.addChild(cream.entity)
        dishGroup.addChild(beads)
        dishGroup.addChild(toppings)
        spinner.addChild(dishGroup)
        await buildGuides()

        // The stage slab, the real one: the oven stands on it 1.4 m to the left of the plate.
        let foot = geometry.standHeight / 1000
        var marble = await ViewerAssets.material("marble_", fallback: UIColor(white: 0.85, alpha: 1), roughness: 0.28)
        marble.roughness = .init(floatLiteral: 0.46)
        marble.clearcoat = .init(floatLiteral: 0.1)
        marble.clearcoatRoughness = .init(floatLiteral: 0.4)
        slabMaterial = marble
        slab = await addPart("stage_slab", marble, to: root, scale: 1)
        let rest = await ViewerSetting.contactShadow(radius: 0.13, strength: 0.5)
        rest.position.y = -foot + 0.0003
        root.addChild(rest)
        let backdrop = await ViewerSetting.backdrop(radius: 9)
        backdrop.position.y = -foot - 0.3
        root.addChild(backdrop)
        self.backdrop = backdrop
        setWarmth(0)

        keyLight = ViewerSetting.addLights(to: root)
        if let url = ViewerAssets.url("env", "png") ?? ViewerAssets.url("env", "hdr"),
           let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
           let env = await Self.environment(image) {
            let ibl = Entity()
            ibl.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: 1.5))
            root.addChild(ibl)
            for child in [root, spinner] as [Entity] {
                child.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
            }
        }
    }

    @discardableResult
    private func addPart(_ name: String, _ material: PhysicallyBasedMaterial, to parent: Entity, scale: Float) async -> Entity? {
        guard let url = ViewerAssets.url(name, "usdz"), let part = try? await Entity(contentsOf: url) else { return nil }
        ToppingFactory.paint(part, with: material)
        part.scale = SIMD3(repeating: scale)
        parent.addChild(part)
        return part
    }

    /// Glass, and a brass finial. It stays still while the plate turns under it.
    private func buildCloche(brass: PhysicallyBasedMaterial, scale: Float) async {
        var glass = PhysicallyBasedMaterial()
        glass.baseColor = .init(tint: UIColor(red: 0.93, green: 0.96, blue: 0.97, alpha: 1))
        glass.roughness = .init(floatLiteral: 0.04)
        glass.specular = 0.9
        glass.clearcoat = .init(floatLiteral: 1)
        glass.clearcoatRoughness = .init(floatLiteral: 0.03)
        glass.blending = .transparent(opacity: .init(floatLiteral: 0.07))
        glass.faceCulling = .none
        if let mesh = await Self.resource(ViewerMesh.clocheGlass()) {
            let dome = ModelEntity(mesh: mesh, materials: [glass])
            dome.scale = SIMD3(repeating: scale)
            cloche.addChild(dome)
        }
        await addPart("cloche_finial", brass, to: cloche, scale: scale)
        cloche.isEnabled = false
        root.addChild(cloche)
    }

    func showTool(_ pose: ToolPose?) { tableware.show(pose) }

    func showAllTools() { tableware.showAll() }

    func useCloseShadows() {
        guard !hasCloseShadows else { return }
        hasCloseShadows = true
        keyLight?.shadow = DirectionalLightComponent.Shadow(maximumDistance: ViewerSetting.closeShadows, depthBias: 2)
    }

    func showsDish(_ shown: Bool) {
        if dishGroup.isEnabled != shown { dishGroup.isEnabled = shown }
    }

    /// 0 is the oven's room: white marble in the dark. 1 is the decorating room: warm and lit.
    func setWarmth(_ warmth: Float) {
        guard warmth != shownWarmth else { return }
        // The backdrop fades by a component: changing its material every frame would be costly.
        backdrop?.components.set(OpacityComponent(opacity: (warmth * 20).rounded() / 20))
        // The slab's tint is a material, so it moves in a few steps too small to see.
        let step = (warmth * 10).rounded() / 10
        if step != shownWarmth {
            shownWarmth = step
            let t = CGFloat(step)
            if var marble = slabMaterial, let slab {
                marble.baseColor.tint = UIColor(red: 1 - 0.14 * t, green: 1 - 0.19 * t, blue: 1 - 0.26 * t, alpha: 1)
                ToppingFactory.paint(slab, with: marble)
            }
        }
    }

    /// 0 seats the cloche on the plate; 1 has it lifted right out of the picture.
    func setCloche(lift: Float) {
        guard lift != shownClocheLift else { return }
        shownClocheLift = lift
        cloche.isEnabled = lift < 1
        cloche.position.y = lift * lift * (3 - 2 * lift) * geometry.clocheHeight * 2.4 / 1000
    }

    /// The studio's light as an environment: iOS 27's options initializer, else the iOS 18 one.
    private static func environment(_ image: CGImage) async -> EnvironmentResource? {
        if #available(iOS 27.0, *) {
            return try? await EnvironmentResource(equirectangular: image, options: .init(samplingQuality: .normal))
        }
        return try? await EnvironmentResource(equirectangular: image, withName: "studio")
    }

    /// Faint rings showing where the piping and the toppings will land.
    private func buildGuides() async {
        let width = geometry.radius / 1000 * 0.007
        for ring in geometry.pipeRings {
            let r = geometry.radius(of: ring) / 1000
            let height = ring == .base ? 0.0006 : (surfaceHeight(atRadius: r * 1000) + geometry.coatThickness + 1.2) / 1000
            await addGuide(radius: r, height: height, width: width, to: pipeGuides)
        }
        for ring in geometry.toppingRings where ring.radius > 0 {
            let r = ring.radius / 1000
            await addGuide(radius: r, height: (surfaceHeight(atRadius: ring.radius) + geometry.coatThickness + 1.2) / 1000, width: width, to: toppingGuides)
        }
        for group in [pipeGuides, toppingGuides] {
            group.isEnabled = false
            spinner.addChild(group)
        }
    }

    private func addGuide(radius: Float, height: Float, width: Float, to parent: Entity) async {
        guard let mesh = await Self.resource(ViewerMesh.guide(radius: radius, height: height, width: width)) else { return }
        parent.addChild(ModelEntity(mesh: mesh, materials: [guideMaterial(onDark: false)]))
    }

    private func guideMaterial(onDark: Bool) -> UnlitMaterial {
        var m = UnlitMaterial(color: onDark ? UIColor(white: 1, alpha: 1) : UIColor(white: 0.08, alpha: 1))
        m.blending = .transparent(opacity: .init(floatLiteral: 0.42))
        return m
    }

    func setCamera(_ rig: CameraRig) {
        // CameraRig is plate-local millimetres, Z up; convert to metres, Y up.
        func rk(_ p: SIMD3<Float>) -> SIMD3<Float> { SIMD3(p.x, p.z, -p.y) / 1000 }
        camera.camera.fieldOfViewInDegrees = rig.fov
        camera.look(at: rk(rig.target), from: rk(rig.position), relativeTo: root)
    }

    /// An explicit pose, in plate-local millimetres, Z up (the opening move along the slab).
    func setCamera(_ pose: CameraPose) {
        func rk(_ p: SIMD3<Float>) -> SIMD3<Float> { SIMD3(p.x, p.z, -p.y) / 1000 }
        camera.camera.fieldOfViewInDegrees = pose.fov
        camera.look(at: rk(pose.target), from: rk(pose.position), relativeTo: root)
    }

    func setTurntable(angle: Float) {
        spinner.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
    }

    func showGuides(for step: DecorStep?) {
        guard step != shownStep else { return }
        shownStep = step
        pipeGuides.isEnabled = step == .pipe
        toppingGuides.isEnabled = step == .top
    }

    /// Brings the scene up to date. Free when nothing changed, which is nearly every frame.
    func update(_ dressing: CakeDressing, field: CreamField) {
        cream.update(from: field)
        guard dressing.revision != shownRevision else { return }
        shownRevision = dressing.revision
        syncBeads(dressing, field: field)
        syncToppings(dressing, field: field)
    }

    /// Guides stay readable over whatever cream is in use.
    func setGuides(onDark dark: Bool) {
        guard dark != guideOnDark else { return }
        guideOnDark = dark
        for group in [pipeGuides, toppingGuides] {
            for case let guide as ModelEntity in group.children { guide.model?.materials = [guideMaterial(onDark: dark)] }
        }
    }

    private func syncBeads(_ dressing: CakeDressing, field: CreamField) {
        for (key, value) in beadEntities where dressing.beads[key] == nil {
            value.entity.removeFromParent()
            beadEntities[key] = nil
        }
        for (key, colour) in dressing.beads {
            if let shown = beadEntities[key] {
                if shown.colour != colour {
                    shown.entity.model?.materials = [beadMaterial(colour)]
                    beadEntities[key] = (shown.entity, colour)
                }
                continue
            }
            // Every bead is its own: the same slot always gets the same variation, so a replay
            // matches, but no two neighbours do.
            var rng = SplitMix64(seed: UInt64(key.slot) &* 2_654_435_761 &+ UInt64(key.ring.rawValue.count) &* 97 &+ 13)
            func pick(_ lo: Float, _ hi: Float) -> Float { lo + (hi - lo) * Float(rng.unit()) }
            let entity = ModelEntity(mesh: beadMeshes[Int(rng.next() % UInt64(beadMeshes.count))], materials: [beadMaterial(colour)])
            let (position, normal) = frame(of: key, field: field, jitter: pick(-0.09, 0.09))
            let size = pick(0.92, 1.08)
            entity.position = position
            entity.scale = SIMD3(size, size * pick(0.94, 1.06), size)
            let lean = simd_quatf(angle: pick(-0.09, 0.09), axis: SIMD3(1, 0, 0)) * simd_quatf(angle: pick(-0.09, 0.09), axis: SIMD3(0, 0, 1))
            entity.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: normal) * lean * simd_quatf(angle: pick(0, 2 * .pi), axis: SIMD3(0, 1, 0))
            if let shade = beadShade?.clone(recursive: false) {
                shade.position.y = 0.0004
                entity.addChild(shade)
            }
            beads.addChild(entity)
            beadEntities[key] = (entity, colour)
            pop(entity)
        }
    }

    private func beadMaterial(_ colour: Int) -> PhysicallyBasedMaterial {
        if let made = beadMaterials[colour] { return made }
        let made = Self.icing(colour: colour)
        beadMaterials[colour] = made
        return made
    }

    private func syncToppings(_ dressing: CakeDressing, field: CreamField) {
        if !dressing.placements.starts(with: shownPlacements) {
            toppings.children.removeAll()
            shownPlacements = []
        }
        guard dressing.placements.count > shownPlacements.count else { return }
        let scale: Float = geometry.hasSide ? 1 : 0.62
        for placement in dressing.placements[shownPlacements.count...] {
            let entity = ToppingFactory.entity(kind: placement.kind, variant: placement.variant, cache: &toppingModels)
            let (position, normal) = surfaceFrame(radius: placement.at.a, angle: placement.at.b, field: field)
            entity.position = position
            entity.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: normal) * simd_quatf(angle: placement.spin, axis: SIMD3(0, 1, 0))
            // Interim until the new models arrive: sprinkles at true size vanish on screen.
            entity.scale = SIMD3(repeating: scale * (placement.kind == "sprinkle" ? 2 : 1))
            toppings.addChild(entity)
            pop(entity)
        }
        shownPlacements = dressing.placements
    }

    private func pop(_ entity: Entity) {
        guard popsNew else { return }
        let settled = entity.transform
        var start = settled
        start.scale = settled.scale * 0.2
        entity.transform = start
        entity.move(to: settled, relativeTo: entity.parent, duration: 0.14, timingFunction: .easeOut)
    }

    // MARK: Where things sit

    /// The bare top's height in millimetres.
    private func surfaceHeight(atRadius r: Float) -> Float {
        profile.topHeight(atRadius: r / 1000) * 1000
    }

    /// `jitter` nudges the bead along its ring, as a share of the gap between slots.
    private func frame(of key: CakeDressing.BeadKey, field: CreamField, jitter: Float) -> (position: SIMD3<Float>, normal: SIMD3<Float>) {
        let r = geometry.radius(of: key.ring)
        let a = geometry.angle(of: key.slot, on: key.ring) + jitter * 2 * .pi / Float(geometry.slots(on: key.ring))
        if key.ring == .base {
            return (SIMD3(r * cos(a), 0, -r * sin(a)) / 1000, SIMD3(0, 1, 0))
        }
        return surfaceFrame(radius: r, angle: a, field: field)
    }

    /// A point on the top, sitting on whatever cream is there, with the slope's normal.
    private func surfaceFrame(radius r: Float, angle a: Float, field: CreamField) -> (position: SIMD3<Float>, normal: SIMD3<Float>) {
        let z = surfaceHeight(atRadius: r) + field.height(radius: r, angle: a) * 0.8
        let step = geometry.radius * 0.03
        let slope = (surfaceHeight(atRadius: r + step) - surfaceHeight(atRadius: max(r - step, 0))) / (step * 2)
        // Lean with the surface, but only partly: piping stands up even on a curve.
        let lean = atan(slope) * 0.6
        let out = SIMD3(cos(a), 0, -sin(a))
        let normal = simd_normalize(SIMD3<Float>(0, 1, 0) * cos(lean) - out * sin(lean))
        return (SIMD3(r * cos(a), z, -r * sin(a)) / 1000, normal)
    }

    // MARK: Meshes and materials

    static func lowLevelMesh(_ data: MeshData, lathe: Lathe? = nil) throws -> LowLevelMesh {
        var desc = LowLevelMesh.Descriptor()
        var attributes: [LowLevelMesh.Attribute] = [
            .init(semantic: .position, format: .float3, offset: 0),
            .init(semantic: .normal, format: .float3, offset: 12),
            .init(semantic: .uv0, format: .float2, offset: 24),
        ]
        var stride = 8
        if lathe != nil {
            attributes += [.init(semantic: .tangent, format: .float3, offset: 32), .init(semantic: .bitangent, format: .float3, offset: 44)]
            stride = 14
        }
        desc.vertexAttributes = attributes
        desc.vertexLayouts = [.init(bufferIndex: 0, bufferStride: stride * 4)]
        desc.vertexCapacity = data.vertexCount
        desc.indexCapacity = data.indices.count
        desc.indexType = .uint32
        let mesh = try LowLevelMesh(descriptor: desc)
        mesh.withUnsafeMutableIndices { raw in
            let dst = raw.bindMemory(to: UInt32.self)
            for (i, v) in data.indices.enumerated() { dst[i] = v }
        }
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            guard let lathe else {
                data.vertices.withUnsafeBytes { src in raw.copyMemory(from: src) }
                return
            }
            let out = raw.bindMemory(to: Float.self)
            data.vertices.withUnsafeBufferPointer { v in
                for i in 0..<data.vertexCount {
                    let from = i * 8, to = i * 14
                    for k in 0..<8 { out[to + k] = v[from + k] }
                    let x = v[from], z = v[from + 2]
                    let length = max((x * x + z * z).squareRoot(), 1e-6)
                    let t = SIMD3(z / length, 0, -x / length)
                    let n = SIMD3(v[from + 3], v[from + 4], v[from + 5])
                    let b = simd_normalize(simd_cross(n, t)) * (lathe == .top ? -1 : 1)
                    out[to + 8] = t.x; out[to + 9] = t.y; out[to + 10] = t.z
                    out[to + 11] = b.x; out[to + 12] = b.y; out[to + 13] = b.z
                }
            }
        }
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: data.indices.count, topology: .triangle,
                                                 bounds: BoundingBox(min: data.boundsMin, max: data.boundsMax))])
        return mesh
    }

    /// Buttercream: soft and slightly sheened, in a palette colour.
    static func icing(colour: Int) -> PhysicallyBasedMaterial {
        let entry = ViewerAssets.palette[min(max(colour, 0), ViewerAssets.palette.count - 1)]
        let (r, g, b) = entry.rgb
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1))
        let colour = UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        m.roughness = .init(floatLiteral: entry.roughness)
        m.specular = entry.isGanache ? 0.7 : 0.38
        if entry.isGanache {
            // Glossy, with a sharp highlight.
            m.clearcoat = .init(floatLiteral: 0.8)
            m.clearcoatRoughness = .init(floatLiteral: 0.08)
        } else {
            // Satin, and a little of the light carried through: the shadow side never goes dead.
            m.sheen = .init(tint: UIColor(white: 0.3, alpha: 1))
            m.emissiveColor = .init(color: colour)
            m.emissiveIntensity = 0.12
        }
        return m
    }
}
