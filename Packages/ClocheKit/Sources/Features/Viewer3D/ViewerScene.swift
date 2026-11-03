import Decorating
import Foundation
import RealityKit
import UIKit

/// The live viewer's entities. RealityKit frame: metres, +Y up, the viewer at +Z; the origin is
/// the centre of the plate's top. `spinner` turns with the turntable and carries the plate, the
/// cake, its icing and the toppings; the collar, the marble and the backdrop stay put.
@MainActor
final class ViewerScene {
    let root = Entity()
    let spinner = Entity()
    let camera = PerspectiveCamera()
    let profile: DishProfile
    private let icingTop: ModelEntity
    private let icingSide: ModelEntity?
    private var icingTopMesh: LowLevelMesh
    private var icingSideMesh: LowLevelMesh?
    private var topTexture: TextureResource?
    private var sideTexture: TextureResource?
    private var topRoughness: TextureResource?
    private var sideRoughness: TextureResource?
    private var shownRevision = (-1, -1)
    private let toppings = Entity()
    private var shownPlacements = 0
    private var toppingModels: [String: Entity] = [:]
    private var surface: Entity?
    private var plate: ModelEntity?
    private var shownLook: (plate: String?, backdrop: String?) = (nil, nil)
    /// Fixed for the scene's life: the meshes' vertex counts depend on it.
    private var detail: Float = 1

    /// The marble under the stand: hidden while the focus move's background frames show through.
    func showsSurface(_ shown: Bool) { surface?.isEnabled = shown }

    /// Places the camera from the focus move's path (plate-local metres, Z up).
    func setCamera(position p: SIMD3<Float>, target t: SIMD3<Float>, fov: Float) {
        camera.camera.fieldOfViewInDegrees = fov
        camera.look(at: SIMD3(t.x, t.z, -t.y), from: SIMD3(p.x, p.z, -p.y), relativeTo: root)
    }

    private init(profile: DishProfile, icingTop: ModelEntity, icingSide: ModelEntity?,
                 topMesh: LowLevelMesh, sideMesh: LowLevelMesh?) {
        self.profile = profile
        self.icingTop = icingTop
        self.icingSide = icingSide
        icingTopMesh = topMesh
        icingSideMesh = sideMesh
    }

    /// Full icing detail, or half when the device is already hot (the lower-resolution fallback).
    static var detail: Float {
        ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue ? 0.5 : 1
    }

    static func make(dish: ViewerAssets.DishKey, surfaces: CakeSurfaces, browning: Float) async -> ViewerScene? {
        let profile = ViewerAssets.profile(dish) ?? DishProfile.placeholder(surfaces.geometry)
        let geometry = surfaces.geometry
        let detail = Self.detail
        // The heavy vertex work runs off the main actor, so the tongs move keeps playing.
        let meshes = await Task.detached(priority: .userInitiated) {
            (top: ViewerMesh.icingTop(profile, field: surfaces.top, detail: detail),
             side: surfaces.side.map { ViewerMesh.icingSide(profile, field: $0, geometry: geometry, detail: detail) },
             cakeTop: ViewerMesh.cakeTop(profile), cakeSide: ViewerMesh.cakeSide(profile))
        }.value
        guard let topMesh = try? lowLevelMesh(meshes.top) else { return nil }
        let sideMesh = meshes.side.flatMap { try? lowLevelMesh($0) }
        let icingMaterial = icingMaterial()
        guard let topResource = try? await MeshResource(from: topMesh) else { return nil }
        let icingTop = ModelEntity(mesh: topResource, materials: [icingMaterial])
        var icingSide: ModelEntity?
        if let sideMesh, let resource = try? await MeshResource(from: sideMesh) {
            icingSide = ModelEntity(mesh: resource, materials: [icingMaterial])
        }
        let scene = ViewerScene(profile: profile, icingTop: icingTop, icingSide: icingSide, topMesh: topMesh, sideMesh: sideMesh)
        scene.detail = detail
        await scene.build(dish: dish, browning: browning, cakeTop: meshes.cakeTop, cakeSide: meshes.cakeSide)
        await scene.preloadToppings()
        scene.update(surfaces: surfaces)
        return scene
    }

    /// Loads every bundled topping model once, asynchronously; placing them later is instant.
    private func preloadToppings() async {
        for kind in ["raspberry", "blueberry", "strawberry_slice", "cherry", "mint_leaf", "chocolate_shard", "chocolate_curl",
                     "gold_flake", "sugar_pearl", "pistachio_crumb", "almond_flake", "flower_petal"] {
            for v in 0..<3 {
                let name = "topping_\(kind)_\(v)"
                if let url = Bundle.module.url(forResource: name, withExtension: "usdz"),
                   let entity = try? await Entity(contentsOf: url) {
                    toppingModels["\(kind)_\(v)"] = entity
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
        camera.camera.fieldOfViewInDegrees = 30
        camera.camera.near = 0.01
        camera.camera.far = 20

        // Plate: the baked marble top, and its edge.
        let plateRadius: Float = 0.15
        var plateMaterial = await ViewerAssets.material("plate_", fallback: UIColor(white: 0.9, alpha: 1), roughness: 0.15)
        plateMaterial.clearcoat = .init(floatLiteral: 0.6)
        let plate = ModelEntity(mesh: .generateCylinder(height: 0.02, radius: plateRadius), materials: [plateMaterial])
        self.plate = plate
        plate.position.y = -0.01
        spinner.addChild(plate)

        // The cake: baked maps on the exported profile; half and dark states tint the golden maps.
        let shade = CGFloat(1 - 0.38 * browning)
        let top = await ViewerAssets.material("\(dish.rawValue)_top_", fallback: UIColor(red: 0.8, green: 0.55, blue: 0.27, alpha: 1), shade: shade)
        let side = await ViewerAssets.material("\(dish.rawValue)_side_", fallback: UIColor(red: 0.72, green: 0.45, blue: 0.2, alpha: 1), shade: shade)
        if let mesh = try? Self.lowLevelMesh(cakeTop), let r = try? await MeshResource(from: mesh) {
            spinner.addChild(ModelEntity(mesh: r, materials: [top]))
        }
        if let mesh = try? Self.lowLevelMesh(cakeSide), let r = try? await MeshResource(from: mesh) {
            spinner.addChild(ModelEntity(mesh: r, materials: [side]))
        }
        spinner.addChild(icingTop)
        if let icingSide { spinner.addChild(icingSide) }
        spinner.addChild(toppings)

        // The brass collar: the turntable's start/stop ring, below the plate's rim.
        var brass = PhysicallyBasedMaterial()
        brass.baseColor = .init(tint: UIColor(red: 0.78, green: 0.56, blue: 0.26, alpha: 1))
        brass.metallic = .init(floatLiteral: 1)
        brass.roughness = .init(floatLiteral: 0.3)
        let collar = ModelEntity(mesh: .generateCylinder(height: 0.009, radius: 0.158), materials: [brass])
        collar.position.y = -0.026
        collar.name = "collar"
        root.addChild(collar)

        // The honed marble surface under it all.
        var marble = await ViewerAssets.material("marble_", fallback: UIColor(white: 0.85, alpha: 1), roughness: 0.32)
        marble.textureCoordinateTransform = .init(scale: SIMD2(4, 4))
        let surface = ModelEntity(mesh: .generatePlane(width: 2.4, depth: 2.4), materials: [marble])
        surface.position.y = -0.2055
        surface.name = "surface"
        root.addChild(surface)
        self.surface = surface

        // Light: the station key from the front-left above, plus image-based light.
        let key = DirectionalLight()
        key.light.intensity = 4000
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 1.2, depthBias: 2)
        key.look(at: .zero, from: SIMD3(-0.9, 1.2, 1.1), relativeTo: nil)
        root.addChild(key)
        if let url = ViewerAssets.url("env", "png") ?? ViewerAssets.url("env", "hdr"),
           let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
           let env = await Self.environment(image) {
            let ibl = Entity()
            ibl.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: 0.5))
            root.addChild(ibl)
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
            for child in [spinner, surface, collar] as [Entity] {
                child.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
            }
        }
    }

    /// The studio's light as an environment: iOS 27's options initializer, else the iOS 18 one.
    private static func environment(_ image: CGImage) async -> EnvironmentResource? {
        if #available(iOS 27.0, *) {
            return try? await EnvironmentResource(equirectangular: image, options: .init(samplingQuality: .normal))
        }
        return try? await EnvironmentResource(equirectangular: image, withName: "studio")
    }

    /// The cake's top in RealityKit's frame (the camera target).
    var target: SIMD3<Float> { SIMD3(0, profile.topHeight(atRadius: 0), 0) }

    func setCamera(_ rig: CameraRig) {
        // CameraRig is plate-local millimetres, Z up; convert to metres, Y up.
        func rk(_ p: SIMD3<Float>) -> SIMD3<Float> { SIMD3(p.x, p.z, -p.y) / 1000 }
        camera.camera.fieldOfViewInDegrees = rig.fov
        camera.look(at: rk(rig.target), from: rk(rig.position), relativeTo: root)
    }

    func setTurntable(angle: Float) {
        spinner.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
    }

    /// Re-uploads the icing meshes and textures when the fields changed, and adds new toppings.
    func update(surfaces: CakeSurfaces) {
        let revision = (surfaces.top.revision, surfaces.side?.revision ?? 0)
        if revision != shownRevision {
            if revision.0 != shownRevision.0 {
                write(ViewerMesh.icingTop(profile, field: surfaces.top, detail: detail), into: icingTopMesh)
                (topTexture, topRoughness) = upload(surfaces.top, into: (topTexture, topRoughness), entity: icingTop)
            }
            if let side = surfaces.side, let mesh = icingSideMesh, let entity = icingSide, revision.1 != shownRevision.1 {
                write(ViewerMesh.icingSide(profile, field: side, geometry: surfaces.geometry, detail: detail), into: mesh)
                (sideTexture, sideRoughness) = upload(side, into: (sideTexture, sideRoughness), entity: entity)
            }
            shownRevision = revision
        }
        syncToppings(surfaces)
        syncLook(plate: surfaces.plate, backdrop: surfaces.backdrop)
    }

    /// Plate: Carrara (as rendered) or Emperador (the same marble, tinted deep brown).
    /// Backdrop: the night marble, or a warm linen tone.
    private func syncLook(plate name: String?, backdrop: String?) {
        guard shownLook.plate != name || shownLook.backdrop != backdrop else { return }
        shownLook = (name, backdrop)
        if let plate, var m = plate.model?.materials.first as? PhysicallyBasedMaterial {
            m.baseColor.tint = name == "emperador" ? UIColor(red: 0.45, green: 0.3, blue: 0.22, alpha: 1) : .white
            plate.model?.materials = [m]
        }
        if let surface = surface as? ModelEntity, var m = surface.model?.materials.first as? PhysicallyBasedMaterial {
            m.baseColor.tint = backdrop == "linen" ? UIColor(red: 0.93, green: 0.88, blue: 0.78, alpha: 1) : .white
            surface.model?.materials = [m]
        }
    }

    #if DEBUG
    /// The spike re-meshes every frame to measure the update path.
    func remeshForSpike(surfaces: CakeSurfaces) {
        write(ViewerMesh.icingTop(profile, field: surfaces.top, detail: detail), into: icingTopMesh)
    }
    #endif

    private func syncToppings(_ surfaces: CakeSurfaces) {
        if surfaces.placements.count < shownPlacements {
            toppings.children.removeAll()
            shownPlacements = 0
        }
        guard surfaces.placements.count > shownPlacements else { return }
        let mapper = SurfaceMapper(geometry: surfaces.geometry)
        for placement in surfaces.placements[shownPlacements...] {
            let entity = ToppingFactory.entity(kind: placement.kind, variant: placement.variant, cache: &toppingModels)
            let (p, n) = mapper.position(of: placement.at)
            let lift = surfaces.icingHeight(at: placement.at)
            var pos = p + n * lift
            if placement.at.surface == .top {
                pos.z = profile.topHeight(atRadius: placement.at.a) * 1000 + lift
            }
            entity.position = SIMD3(pos.x, pos.z, -pos.y) / 1000
            let normal = SIMD3(n.x, n.z, -n.y)
            let up = simd_quatf(from: SIMD3(0, 1, 0), to: normal)
            entity.orientation = up * simd_quatf(angle: placement.spin, axis: SIMD3(0, 1, 0))
            toppings.addChild(entity)
        }
        shownPlacements = surfaces.placements.count
    }

    // MARK: Meshes and textures

    static func lowLevelMesh(_ data: MeshData) throws -> LowLevelMesh {
        var desc = LowLevelMesh.Descriptor()
        desc.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: 0),
            .init(semantic: .normal, format: .float3, offset: 12),
            .init(semantic: .uv0, format: .float2, offset: 24),
        ]
        desc.vertexLayouts = [.init(bufferIndex: 0, bufferStride: 32)]
        desc.vertexCapacity = data.vertexCount
        desc.indexCapacity = data.indices.count
        desc.indexType = .uint32
        let mesh = try LowLevelMesh(descriptor: desc)
        mesh.withUnsafeMutableIndices { raw in
            let dst = raw.bindMemory(to: UInt32.self)
            for (i, v) in data.indices.enumerated() { dst[i] = v }
        }
        write(data, into: mesh)
        return mesh
    }

    @discardableResult
    static func write(_ data: MeshData, into mesh: LowLevelMesh) -> LowLevelMesh {
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            data.vertices.withUnsafeBytes { src in raw.copyMemory(from: src) }
        }
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: data.indices.count, topology: .triangle,
                                                 bounds: BoundingBox(min: data.boundsMin, max: data.boundsMax))])
        return mesh
    }

    private func write(_ data: MeshData, into mesh: LowLevelMesh) { Self.write(data, into: mesh) }

    /// Buttercream look; the colour, coverage and powder come from the field texture.
    private static func icingMaterial() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .white)
        m.roughness = 0.55
        m.specular = 0.4
        m.sheen = .init(tint: UIColor(white: 0.25, alpha: 1))
        m.opacityThreshold = 0.5
        return m
    }

    private func upload(_ field: HeightField, into textures: (TextureResource?, TextureResource?),
                        entity: ModelEntity) -> (TextureResource?, TextureResource?) {
        guard let images = IcingImage.make(field) else { return textures }
        let colourOptions = TextureResource.CreateOptions(semantic: .color)
        let rawOptions = TextureResource.CreateOptions(semantic: .raw)
        if let colour = textures.0, let rough = textures.1 {
            try? colour.replace(withImage: images.colour, options: colourOptions)
            try? rough.replace(withImage: images.roughness, options: rawOptions)
            return textures
        }
        guard let colour = try? TextureResource(image: images.colour, options: colourOptions),
              let rough = try? TextureResource(image: images.roughness, options: rawOptions) else { return textures }
        if var m = entity.model?.materials.first as? PhysicallyBasedMaterial {
            m.baseColor = .init(tint: .white, texture: .init(colour))
            m.roughness = .init(scale: 1, texture: .init(rough))
            entity.model?.materials = [m]
        }
        return (colour, rough)
    }
}

/// The icing texture: palette colour where there is icing, powder mixed over it, alpha =
/// covered (the material cuts out the rest).
enum IcingImage {
    static func make(_ field: HeightField) -> (colour: CGImage, roughness: CGImage)? {
        let palette = ViewerAssets.palette.map(\.rgb)
        let roughnessByColour = ViewerAssets.palette.map { UInt8(min(max($0.roughness, 0), 1) * 255) }
        let count = field.width * field.height
        var pixels = [UInt8](repeating: 0, count: count * 4)
        var rough = [UInt8](repeating: 160, count: count * 4)
        for i in 0..<count {
            let colour = Int(field.colours[i])
            let dust = field.dust[i]
            let covered = field.heights[i] > 0.02 || dust > 0.05
            guard covered else { continue }
            var (r, g, b) = colour > 0 && colour <= palette.count ? palette[colour - 1] : (230, 205, 160)
            if dust > 0, field.dustColours[i] > 0, Int(field.dustColours[i]) <= palette.count {
                let d = palette[Int(field.dustColours[i]) - 1]
                let t = min(dust, 1)
                r = UInt8(Float(r) * (1 - t) + Float(d.0) * t)
                g = UInt8(Float(g) * (1 - t) + Float(d.1) * t)
                b = UInt8(Float(b) * (1 - t) + Float(d.2) * t)
            }
            pixels[i * 4] = r
            pixels[i * 4 + 1] = g
            pixels[i * 4 + 2] = b
            pixels[i * 4 + 3] = 255
            // Powder is matte whatever it lies on.
            let base = colour > 0 && colour <= roughnessByColour.count ? roughnessByColour[colour - 1] : 160
            let value = dust > 0.3 ? 235 : base
            rough[i * 4] = value
            rough[i * 4 + 1] = value
            rough[i * 4 + 2] = value
            rough[i * 4 + 3] = 255
        }
        guard let colourImage = image(pixels, field), let roughImage = image(rough, field) else { return nil }
        return (colourImage, roughImage)
    }

    private static func image(_ pixels: [UInt8], _ field: HeightField) -> CGImage? {
        // Row 0 of the field (y = 0 mm) is the image's first row; the mesh UVs match (v = 1 - y/D
        // with RealityKit's bottom-left origin puts y = 0 at the top row).
        let row = field.width * 4
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: field.width, height: field.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: row,
                       space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
