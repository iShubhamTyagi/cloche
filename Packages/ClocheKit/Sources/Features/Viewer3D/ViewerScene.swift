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
    private var shownRevision = (-1, -1)
    private let toppings = Entity()
    private var shownPlacements = 0
    private var toppingModels: [String: Entity] = [:]

    private init(profile: DishProfile, icingTop: ModelEntity, icingSide: ModelEntity?,
                 topMesh: LowLevelMesh, sideMesh: LowLevelMesh?) {
        self.profile = profile
        self.icingTop = icingTop
        self.icingSide = icingSide
        icingTopMesh = topMesh
        icingSideMesh = sideMesh
    }

    static func make(dish: ViewerAssets.DishKey, surfaces: CakeSurfaces, browning: Float) async -> ViewerScene? {
        let profile = ViewerAssets.profile(dish) ?? DishProfile.placeholder(surfaces.geometry)
        let geometry = surfaces.geometry
        guard let topMesh = try? lowLevelMesh(ViewerMesh.icingTop(profile, field: surfaces.top)) else { return nil }
        let sideMesh = surfaces.side.flatMap { try? lowLevelMesh(ViewerMesh.icingSide(profile, field: $0, geometry: geometry)) }
        let icingMaterial = icingMaterial()
        guard let topResource = try? await MeshResource(from: topMesh) else { return nil }
        let icingTop = ModelEntity(mesh: topResource, materials: [icingMaterial])
        var icingSide: ModelEntity?
        if let sideMesh, let resource = try? await MeshResource(from: sideMesh) {
            icingSide = ModelEntity(mesh: resource, materials: [icingMaterial])
        }
        let scene = ViewerScene(profile: profile, icingTop: icingTop, icingSide: icingSide, topMesh: topMesh, sideMesh: sideMesh)
        await scene.build(dish: dish, browning: browning)
        scene.update(surfaces: surfaces)
        return scene
    }

    private func build(dish: ViewerAssets.DishKey, browning: Float) async {
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
        plate.position.y = -0.01
        spinner.addChild(plate)

        // The cake: baked maps on the exported profile; half and dark states tint the golden maps.
        let tint = UIColor(white: CGFloat(1 - 0.38 * browning), alpha: 1)
        var top = await ViewerAssets.material("\(dish.rawValue)_top_", fallback: UIColor(red: 0.8, green: 0.55, blue: 0.27, alpha: 1))
        var side = await ViewerAssets.material("\(dish.rawValue)_side_", fallback: UIColor(red: 0.72, green: 0.45, blue: 0.2, alpha: 1))
        top.baseColor.tint = tint
        side.baseColor.tint = tint
        if let mesh = try? Self.lowLevelMesh(ViewerMesh.cakeTop(profile)), let r = try? await MeshResource(from: mesh) {
            spinner.addChild(ModelEntity(mesh: r, materials: [top]))
        }
        if let mesh = try? Self.lowLevelMesh(ViewerMesh.cakeSide(profile)), let r = try? await MeshResource(from: mesh) {
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
        surface.position.y = -0.2
        root.addChild(surface)

        // Light: the station key from the front-left above, plus image-based light.
        let key = DirectionalLight()
        key.light.intensity = 4000
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 1.2, depthBias: 2)
        key.look(at: .zero, from: SIMD3(-0.9, 1.2, 1.1), relativeTo: nil)
        root.addChild(key)
        if let url = ViewerAssets.url("env", "hdr") ?? ViewerAssets.url("env", "exr"),
           let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
           let env = try? await EnvironmentResource(equirectangular: image, withName: "studio") {
            let ibl = Entity()
            ibl.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: 0.5))
            root.addChild(ibl)
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
            for child in [spinner, surface, collar] as [Entity] {
                child.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
            }
        }
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
                write(ViewerMesh.icingTop(profile, field: surfaces.top), into: icingTopMesh)
                topTexture = upload(surfaces.top, into: topTexture, entity: icingTop)
            }
            if let side = surfaces.side, let mesh = icingSideMesh, let entity = icingSide, revision.1 != shownRevision.1 {
                write(ViewerMesh.icingSide(profile, field: side, geometry: surfaces.geometry), into: mesh)
                sideTexture = upload(side, into: sideTexture, entity: entity)
            }
            shownRevision = revision
        }
        syncToppings(surfaces)
    }

    #if DEBUG
    /// The spike re-meshes every frame to measure the update path.
    func remeshForSpike(surfaces: CakeSurfaces) {
        write(ViewerMesh.icingTop(profile, field: surfaces.top), into: icingTopMesh)
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

    private func upload(_ field: HeightField, into texture: TextureResource?, entity: ModelEntity) -> TextureResource? {
        guard let image = IcingImage.make(field) else { return texture }
        let options = TextureResource.CreateOptions(semantic: .color)
        if let texture {
            try? texture.replace(withImage: image, options: options)
            return texture
        }
        guard let created = try? TextureResource(image: image, options: options) else { return nil }
        if var m = entity.model?.materials.first as? PhysicallyBasedMaterial {
            m.baseColor = .init(tint: .white, texture: .init(created))
            entity.model?.materials = [m]
        }
        return created
    }
}

/// The icing texture: palette colour where there is icing, powder mixed over it, alpha =
/// covered (the material cuts out the rest).
enum IcingImage {
    static func make(_ field: HeightField) -> CGImage? {
        let palette = ViewerAssets.palette.map(\.rgb)
        let count = field.width * field.height
        var pixels = [UInt8](repeating: 0, count: count * 4)
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
        }
        // Row 0 of the field is y = 0 (mm); the mesh UVs put y = 0 at the image's bottom.
        var flipped = [UInt8](repeating: 0, count: pixels.count)
        let row = field.width * 4
        for y in 0..<field.height {
            let src = (field.height - 1 - y) * row
            flipped.replaceSubrange(y * row..<(y + 1) * row, with: pixels[src..<src + row])
        }
        guard let provider = CGDataProvider(data: Data(flipped) as CFData) else { return nil }
        return CGImage(width: field.width, height: field.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: row,
                       space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
