import Decorating
import Foundation
import RealityKit
import UIKit

/// The live viewer's bundled assets (`scripts/blender/export_assets.py` → `Resources/DecorRender`,
/// generated and gitignored). SwiftPM flattens resources, so every file name is prefixed with its
/// group, e.g. `cake_golden_top_albedo.png`. Anything missing falls back to code-drawn stand-ins.
enum ViewerAssets {
    enum DishKey: String, Sendable {
        case cake = "cake_golden"
        case cupcake = "cupcake_golden"
    }

    static func url(_ name: String, _ ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext)
    }

    static func profile(_ dish: DishKey) -> DishProfile? {
        guard let url = url("\(dish.rawValue)_profile", "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DishProfile.self, from: data)
    }

    @MainActor
    static func texture(_ name: String, color: Bool) async -> TextureResource? {
        for ext in ["heic", "jpg", "png"] {
            if let url = url(name, ext) {
                return try? await TextureResource(contentsOf: url, options: .init(semantic: color ? .color : .raw))
            }
        }
        return nil
    }

    /// PBR material from `<prefix>albedo/roughness/normal/ao`, or `fallback` colour.
    @MainActor
    /// `shade` darkens it (the dark bake state reuses the golden maps).
    static func material(_ prefix: String, fallback: UIColor, roughness: Float = 0.7, shade: CGFloat = 1) async -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        if let albedo = await texture(prefix + "albedo", color: true) {
            m.baseColor = .init(tint: UIColor(white: shade, alpha: 1), texture: .init(albedo))
        } else {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            fallback.getRed(&r, green: &g, blue: &b, alpha: &a)
            m.baseColor = .init(tint: UIColor(red: r * shade, green: g * shade, blue: b * shade, alpha: 1))
        }
        if let rough = await texture(prefix + "roughness", color: false) {
            m.roughness = .init(scale: 1, texture: .init(rough))
        } else {
            m.roughness = .init(floatLiteral: roughness)
        }
        if let normal = await texture(prefix + "normal", color: false) {
            m.normal = .init(texture: .init(normal))
        }
        if let ao = await texture(prefix + "ao", color: false) {
            m.ambientOcclusion = .init(texture: .init(ao))
        }
        return m
    }

    /// The icing palette (icing.py palette.json), in order; sRGB colours.
    static let palette: [IcingColour] = {
        struct File: Decodable {
            struct Row: Decodable { let name: String; let kind: String; let srgb: String; let roughness: Float }
            let colours: [Row]
        }
        if let url = url("palette", "json"), let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: data) {
            return file.colours.map { IcingColour(name: $0.name, isGanache: $0.kind == "ganache", hex: $0.srgb, roughness: $0.roughness) }
        }
        return IcingColour.defaults
    }()
}

/// One icing or ganache colour from the palette.
struct IcingColour: Sendable, Equatable {
    let name: String
    let isGanache: Bool
    let hex: String
    let roughness: Float

    var rgb: (UInt8, UInt8, UInt8) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0xFFFFFF
        return (UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF))
    }

    /// Same values as scripts/blender/icing.py, used when no palette is bundled.
    static let defaults: [IcingColour] = [
        .init(name: "ivory", isGanache: false, hex: "#EADBB8", roughness: 0.62),
        .init(name: "rose", isGanache: false, hex: "#E8908E", roughness: 0.6),
        .init(name: "pistachio", isGanache: false, hex: "#A6C47E", roughness: 0.6),
        .init(name: "chocolate", isGanache: false, hex: "#3F2318", roughness: 0.55),
        .init(name: "caramel", isGanache: false, hex: "#B06A2A", roughness: 0.55),
        .init(name: "white", isGanache: false, hex: "#F4F1EA", roughness: 0.64),
        .init(name: "raspberry", isGanache: false, hex: "#A8203E", roughness: 0.58),
        .init(name: "bluegrey", isGanache: false, hex: "#7F93A6", roughness: 0.6),
        .init(name: "ganache_dark", isGanache: true, hex: "#2E1A12", roughness: 0.14),
        .init(name: "ganache_milk", isGanache: true, hex: "#6A3F26", roughness: 0.16),
        .init(name: "ganache_white", isGanache: true, hex: "#EFE3C8", roughness: 0.2),
        .init(name: "ganache_caramel", isGanache: true, hex: "#A8652C", roughness: 0.15),
    ]
}
