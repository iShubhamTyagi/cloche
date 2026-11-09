import Decorating
import RealityKit
import UIKit

/// What stands on the slab beyond the turntable, and what is held in the hand: gilded china bowls
/// of toppings, the spatula and the piping bag. Models from `scripts/blender/tableware.py`.
@MainActor
final class ViewerTableware {
    private let spatula = Entity()
    private let bag = Entity()

    /// A bowl of each topping on the slab, heaped with the real toppings.
    func addBowls(to root: Entity, slabTop: Float, models: inout [String: Entity]) async {
        guard let url = ViewerAssets.url("bowl_china", "usdz"), let bowl = try? await Entity(contentsOf: url) else { return }
        var china = PhysicallyBasedMaterial()
        china.baseColor = .init(tint: .white, texture: await Self.texture("china_albedo", semantic: .color))
        // Part metal only: this room is dim, and full metal would mirror the dark and read black.
        china.metallic = .init(scale: 0.5, texture: await Self.texture("china_metal", semantic: .raw))
        china.roughness = .init(scale: 1, texture: await Self.texture("china_rough", semantic: .raw))
        china.clearcoat = .init(floatLiteral: 0.7)
        china.clearcoatRoughness = .init(floatLiteral: 0.06)
        china.faceCulling = .none
        ToppingFactory.paint(bowl, with: china)
        let shadow = await ViewerSetting.contactShadow(radius: 0.075, strength: 0.5)
        for (index, name) in DecorCatalog.toppings.enumerated() {
            let spot = DecorCatalog.bowlSpots[index]
            let holder = Entity()
            holder.position = SIMD3(spot.x / 1000, slabTop, -spot.y / 1000)
            holder.addChild(bowl.clone(recursive: true))
            let under = shadow.clone(recursive: false)
            under.position.y = 0.0004
            holder.addChild(under)
            heap(name, in: holder, index: index, models: &models)
            root.addChild(holder)
        }
    }

    /// Fills a bowl: pieces piled in a mound, each one turned its own way.
    private func heap(_ name: String, in holder: Entity, index: Int, models: inout [String: Entity]) {
        let kinds = DecorCatalog.models(for: name)
        let (count, size, under): (Int, Float, UIColor) = switch name {
        case "raspberries": (30, 1, UIColor(red: 0.36, green: 0.05, blue: 0.1, alpha: 1))
        case "blueberries": (52, 1, UIColor(red: 0.1, green: 0.11, blue: 0.22, alpha: 1))
        default: (170, 2, UIColor(red: 0.75, green: 0.55, blue: 0.5, alpha: 1))
        }
        // A full bowl: a mound the pieces sit on, so no bare china shows between them.
        var mass = PhysicallyBasedMaterial()
        mass.baseColor = .init(tint: under)
        mass.roughness = .init(floatLiteral: 0.7)
        let mound = ModelEntity(mesh: .generateSphere(radius: 0.046), materials: [mass])
        mound.position.y = 0.03
        mound.scale = SIMD3(1, 0.44, 1)
        holder.addChild(mound)
        var rng = SplitMix64(seed: UInt64(index + 1) &* 7919)
        func pick(_ lo: Float, _ hi: Float) -> Float { lo + (hi - lo) * Float(rng.unit()) }
        for n in 0..<count {
            let entity = ToppingFactory.entity(kind: kinds[n % kinds.count], variant: Int(rng.next() % 5), cache: &models)
            let r = 0.044 * Float(rng.unit()).squareRoot(), a = pick(0, 2 * .pi)
            // On the mound's surface.
            let share = min(r / 0.046, 1)
            let top = 0.03 + 0.046 * 0.44 * (1 - share * share).squareRoot()
            entity.position = SIMD3(r * cos(a), top + pick(0, 0.003), r * sin(a))
            entity.orientation = simd_quatf(angle: pick(0, 2 * .pi), axis: simd_normalize(SIMD3(pick(-1, 1), pick(0.2, 1), pick(-1, 1))))
            entity.scale = SIMD3(repeating: size)
            // Hundreds of tiny pieces: their shadows can't be seen in a bowl, and they cost a lot.
            entity.components.set(DynamicLightShadowComponent(castsShadow: false))
            holder.addChild(entity)
        }
    }

    /// Loads the hand tools, hidden until a finger is down.
    func addTools(to root: Entity) async {
        var steel = PhysicallyBasedMaterial()
        // Partly metal: the room is too dim for a pure mirror to read as bright steel.
        steel.baseColor = .init(tint: UIColor(white: 0.9, alpha: 1))
        steel.metallic = .init(floatLiteral: 0.55)
        steel.roughness = .init(floatLiteral: 0.3)
        var brass = PhysicallyBasedMaterial()
        brass.baseColor = .init(tint: UIColor(red: 0.8, green: 0.61, blue: 0.33, alpha: 1))
        brass.metallic = .init(floatLiteral: 1)
        brass.roughness = .init(floatLiteral: 0.28)
        var walnut = PhysicallyBasedMaterial()
        walnut.baseColor = .init(tint: .white, texture: await Self.texture("walnut_albedo", semantic: .color))
        walnut.roughness = .init(floatLiteral: 0.42)
        walnut.clearcoat = .init(floatLiteral: 0.4)
        var linen = PhysicallyBasedMaterial()
        linen.baseColor = .init(tint: UIColor(red: 0.93, green: 0.9, blue: 0.83, alpha: 1))
        linen.roughness = .init(floatLiteral: 0.72)
        for (name, material, parent) in [("spatula_blade", steel, spatula), ("spatula_ferrule", brass, spatula),
                                         ("spatula_handle", walnut, spatula), ("bag_cloth", linen, bag), ("bag_tip", steel, bag)] {
            guard let url = ViewerAssets.url(name, "usdz"), let part = try? await Entity(contentsOf: url) else { continue }
            ToppingFactory.paint(part, with: material)
            parent.addChild(part)
        }
        bag.scale = SIMD3(repeating: 0.62)
        for tool in [spatula, bag] {
            tool.isEnabled = false
            root.addChild(tool)
        }
    }

    /// Both tools at once, on the plate: only for the warm-up, under the cover.
    func showAll() {
        for tool in [spatula, bag] {
            tool.isEnabled = true
            tool.position = SIMD3(0, 0.08, 0)
        }
    }

    /// Puts the tool in hand at its contact point (nil: nothing in hand).
    func show(_ pose: ToolPose?) {
        let held = pose?.kind
        if spatula.isEnabled != (held == .spatula) { spatula.isEnabled = held == .spatula }
        if bag.isEnabled != (held == .bag) { bag.isEnabled = held == .bag }
        guard let pose else { return }
        let tool = pose.kind == .spatula ? spatula : bag
        tool.position = SIMD3(pose.position.x, pose.position.z, -pose.position.y) / 1000
        // Handle along local +X: swing it round, tip it up, then roll the blade on its long axis.
        tool.orientation = simd_quatf(angle: pose.heading, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: pose.pitch, axis: SIMD3(0, 0, 1))
            * simd_quatf(angle: pose.roll, axis: SIMD3(1, 0, 0))
    }

    private static func texture(_ name: String, semantic: TextureResource.Semantic) async -> MaterialParameters.Texture? {
        guard let url = ViewerAssets.url(name, "png"),
              let resource = try? await TextureResource(contentsOf: url, options: .init(semantic: semantic)) else { return nil }
        return .init(resource)
    }
}
