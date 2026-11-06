import Decorating
import RealityKit
import UIKit

/// The set the cake stands on: a marble slab on a warm gradient, soft contact shadows and the
/// three lights. Everything here is made once when the scene loads.
@MainActor
enum ViewerSetting {
    /// The far end of the backdrop.
    static let backdropEdge = UIColor(red: 0.27, green: 0.19, blue: 0.14, alpha: 1)
    /// The app's near-black, where the oven stands: the renderer's clear colour. It must never be
    /// changed while running: touching the environment costs about a second a frame.
    static let ovenRoom = UIColor(red: 0.055, green: 0.055, blue: 0.05, alpha: 1)

    /// A radial picture from `inner` at the middle to `outer` at the edge.
    private static func radial(_ inner: UIColor, _ outer: UIColor, size: Int = 512) -> CGImage? {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: [inner.cgColor, outer.cgColor] as CFArray, locations: [0, 1]) else { return nil }
        let centre = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: CGFloat(size) / 2,
                                   options: .drawsAfterEndLocation)
        return context.makeImage()
    }

    /// The backdrop: warm cream under the cake, falling away to dark espresso.
    static func backdrop(radius: Float) async -> ModelEntity {
        var material = UnlitMaterial(color: backdropEdge)
        let cream = UIColor(red: 0.62, green: 0.5, blue: 0.38, alpha: 1)
        if let image = radial(cream, backdropEdge), let texture = try? await TextureResource(image: image, options: .init(semantic: .color)) {
            material.color = .init(tint: .white, texture: .init(texture))
        }
        return ModelEntity(mesh: .generatePlane(width: radius * 2, depth: radius * 2), materials: [material])
    }

    /// A soft dark pool, for where one thing rests on another.
    static func contactShadow(radius: Float, strength: CGFloat) async -> ModelEntity {
        var material = UnlitMaterial(color: UIColor(red: 0.09, green: 0.05, blue: 0.03, alpha: 1))
        let inner = UIColor(white: strength, alpha: 1), outer = UIColor(white: 0, alpha: 1)
        // Flat under the object, then a quick fall: a plain radial would be too faint at its rim.
        if let image = shadowImage(inner, outer), let texture = try? await TextureResource(image: image, options: .init(semantic: .raw)) {
            material.blending = .transparent(opacity: .init(scale: 1, texture: .init(texture)))
        }
        return ModelEntity(mesh: .generatePlane(width: radius * 2, depth: radius * 2), materials: [material])
    }

    private static func shadowImage(_ inner: UIColor, _ outer: UIColor) -> CGImage? {
        let size = 256
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: [inner.cgColor, inner.cgColor, outer.cgColor] as CFArray,
                                        locations: [0, 0.72, 1]) else { return nil }
        let centre = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: CGFloat(size) / 2,
                                   options: .drawsAfterEndLocation)
        return context.makeImage()
    }

    /// Soft key from the front left, a cool-free fill from the right, a faint warm rim behind.
    @discardableResult
    static func addLights(to root: Entity) -> DirectionalLight {
        let key = DirectionalLight()
        key.light.intensity = 3000
        key.light.color = UIColor(red: 1, green: 0.96, blue: 0.9, alpha: 1)
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: wideShadows, depthBias: 2)
        key.look(at: .zero, from: SIMD3(-0.7, 1.4, 0.9), relativeTo: nil)
        root.addChild(key)
        let fill = DirectionalLight()
        fill.light.intensity = 650
        fill.light.color = UIColor(red: 1, green: 0.95, blue: 0.9, alpha: 1)
        fill.look(at: .zero, from: SIMD3(1.1, 0.6, 0.8), relativeTo: nil)
        root.addChild(fill)
        let rim = DirectionalLight()
        rim.light.intensity = 800
        rim.light.color = UIColor(red: 1, green: 0.84, blue: 0.64, alpha: 1)
        rim.look(at: .zero, from: SIMD3(0.2, 0.5, -1.2), relativeTo: nil)
        root.addChild(rim)
        return key
    }

    /// The opening shot is far from the stand; everywhere else a tight range keeps shadows clean.
    static let wideShadows: Float = 3.2
    static let closeShadows: Float = 1.9
}
