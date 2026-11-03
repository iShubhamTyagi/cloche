import Foundation
import RealityKit
import UIKit

/// Topping entities: the low-poly models from toppings3d.py (`topping_<kind>_<variant>.usdz`,
/// pivot at the contact point, +Y = surface normal), cloned so copies share their mesh. Sprinkles
/// are one rod tinted per colour. A code-drawn stand-in when a model isn't bundled.
@MainActor
enum ToppingFactory {
    static let sprinkleColours: [UIColor] = [
        UIColor(red: 0.88, green: 0.29, blue: 0.51, alpha: 1), UIColor(red: 0.18, green: 0.69, blue: 0.56, alpha: 1),
        UIColor(red: 0.94, green: 0.72, blue: 0.13, alpha: 1), UIColor(red: 0.35, green: 0.42, blue: 0.85, alpha: 1),
        UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1),
    ]

    static func entity(kind: String, variant: Int, cache: inout [String: Entity]) -> Entity {
        let key = kind == "sprinkle" ? "sprinkle_\(variant % sprinkleColours.count)" : "\(kind)_\(variant % 3)"
        if let cached = cache[key] { return cached.clone(recursive: true) }
        // Bundled models are preloaded by ViewerScene; anything missing gets the stand-in.
        let made = standIn(kind: kind, variant: variant)
        cache[key] = made
        return made.clone(recursive: true)
    }

    static func tinted(_ entity: Entity, colour: Int) -> Entity {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: sprinkleColours[colour % sprinkleColours.count])
        m.roughness = 0.35
        entity.visit { ($0 as? ModelEntity)?.model?.materials = [m] }
        return entity
    }

    /// Simple shapes at the real size, so the app works before the models are exported.
    private static func standIn(kind: String, variant: Int) -> Entity {
        var m = PhysicallyBasedMaterial()
        m.roughness = 0.4
        let mesh: MeshResource
        switch kind {
        case "raspberry":
            m.baseColor = .init(tint: UIColor(red: 0.56, green: 0.06, blue: 0.16, alpha: 1)); mesh = .generateSphere(radius: 0.009)
        case "blueberry":
            m.baseColor = .init(tint: UIColor(red: 0.11, green: 0.13, blue: 0.25, alpha: 1)); mesh = .generateSphere(radius: 0.0055)
        case "cherry":
            m.baseColor = .init(tint: UIColor(red: 0.43, green: 0.04, blue: 0.09, alpha: 1)); mesh = .generateSphere(radius: 0.011)
        case "sugar_pearl":
            m.baseColor = .init(tint: UIColor(white: 0.95, alpha: 1)); m.metallic = .init(floatLiteral: 0.35); mesh = .generateSphere(radius: 0.002)
        case "sprinkle":
            m.baseColor = .init(tint: sprinkleColours[variant % sprinkleColours.count])
            mesh = .generateBox(width: 0.006, height: 0.0012, depth: 0.0012, cornerRadius: 0.0006)
        case "gold_flake":
            m.baseColor = .init(tint: UIColor(red: 0.91, green: 0.76, blue: 0.42, alpha: 1)); m.metallic = .init(floatLiteral: 1)
            mesh = .generateBox(width: 0.006, height: 0.0002, depth: 0.005)
        case "mint_leaf", "flower_petal", "almond_flake", "strawberry_slice", "chocolate_shard":
            let tint: UIColor = switch kind {
            case "mint_leaf": UIColor(red: 0.16, green: 0.37, blue: 0.14, alpha: 1)
            case "flower_petal": UIColor(red: 0.85, green: 0.44, blue: 0.56, alpha: 1)
            case "almond_flake": UIColor(red: 0.92, green: 0.85, blue: 0.71, alpha: 1)
            case "strawberry_slice": UIColor(red: 0.85, green: 0.16, blue: 0.23, alpha: 1)
            default: UIColor(red: 0.18, green: 0.1, blue: 0.07, alpha: 1)
            }
            m.baseColor = .init(tint: tint); mesh = .generateBox(width: 0.018, height: 0.0015, depth: 0.012, cornerRadius: 0.0007)
        default:
            m.baseColor = .init(tint: UIColor(red: 0.42, green: 0.54, blue: 0.16, alpha: 1)); mesh = .generateBox(size: 0.004, cornerRadius: 0.001)
        }
        let model = ModelEntity(mesh: mesh, materials: [m])
        model.position.y = mesh.bounds.extents.y / 2
        let pivot = Entity()
        pivot.addChild(model)
        return pivot
    }
}

private extension Entity {
    func visit(_ body: (Entity) -> Void) {
        body(self)
        for child in children { child.visit(body) }
    }
}
