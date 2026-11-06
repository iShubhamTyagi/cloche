import Decorating
import Metal
import RealityKit
import UIKit

/// The cream on screen: a shell over the dish that rises where there is cream, with its colour
/// and surface detail in two GPU textures. A blade only ever touches a few rows, so only those
/// rows of the mesh and the staging buffers are rewritten; the textures are refreshed by a GPU
/// copy. Nothing here walks the whole field during a stroke.
@MainActor
final class CreamLayer {
    static let meshRows = 128
    static let meshCols = 256
    /// position, normal, uv, tangent, bitangent.
    private static let stride = 14

    let entity: ModelEntity
    private let mesh: LowLevelMesh
    private let line: DishLine
    private var vertices: [Float]
    private let queue: MTLCommandQueue
    private let colourTexture: LowLevelTexture
    private let normalTexture: LowLevelTexture
    private let glossTexture: LowLevelTexture
    private let colourStaging: MTLBuffer
    private let normalStaging: MTLBuffer
    private let glossStaging: MTLBuffer

    init?(line: DishLine) async {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        let rows = Self.meshRows, cols = Self.meshCols + 1
        var indices = [UInt32]()
        indices.reserveCapacity((rows - 1) * (cols - 1) * 6)
        for j in 0..<(rows - 1) {
            for i in 0..<(cols - 1) {
                let a = UInt32(j * cols + i), b = a + 1, c = a + UInt32(cols), d = c + 1
                indices += [a, c, b, b, c, d]
            }
        }
        var desc = LowLevelMesh.Descriptor()
        desc.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: 0),
            .init(semantic: .normal, format: .float3, offset: 12),
            .init(semantic: .uv0, format: .float2, offset: 24),
            .init(semantic: .tangent, format: .float3, offset: 32),
            .init(semantic: .bitangent, format: .float3, offset: 44),
        ]
        desc.vertexLayouts = [.init(bufferIndex: 0, bufferStride: Self.stride * 4)]
        desc.vertexCapacity = rows * cols
        desc.indexCapacity = indices.count
        desc.indexType = .uint32
        guard let mesh = try? LowLevelMesh(descriptor: desc) else { return nil }
        mesh.withUnsafeMutableIndices { raw in
            let dst = raw.bindMemory(to: UInt32.self)
            for (i, v) in indices.enumerated() { dst[i] = v }
        }
        let reach = (line.points.map(\.x).max() ?? 100) / 1000 + 0.01
        let height = (line.points.map(\.y).max() ?? 50) / 1000 + 0.01
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: indices.count, topology: .triangle,
                                                 bounds: BoundingBox(min: SIMD3(-reach, -0.002, -reach), max: SIMD3(reach, height, reach)))])

        let w = CreamField.cols, h = CreamField.rows
        func texture(_ format: MTLPixelFormat) -> LowLevelTexture? {
            try? LowLevelTexture(descriptor: .init(textureType: .type2D, pixelFormat: format, width: w, height: h, depth: 1,
                                                   mipmapLevelCount: 1, textureUsage: [.shaderRead]))
        }
        guard let colour = texture(.rgba8Unorm_srgb), let normal = texture(.rgba8Unorm), let gloss = texture(.rgba8Unorm),
              let colourStaging = device.makeBuffer(length: w * h * 4, options: .storageModeShared),
              let normalStaging = device.makeBuffer(length: w * h * 4, options: .storageModeShared),
              let glossStaging = device.makeBuffer(length: w * h * 4, options: .storageModeShared),
              let glossResource = try? await TextureResource(from: gloss),
              let colourResource = try? await TextureResource(from: colour),
              let normalResource = try? await TextureResource(from: normal),
              let resource = try? await MeshResource(from: mesh) else { return nil }

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(colourResource))
        material.normal = .init(texture: .init(normalResource))
        material.roughness = .init(scale: 1, texture: .init(glossResource))
        material.specular = 0.4
        material.sheen = .init(tint: UIColor(white: 0.25, alpha: 1))
        material.opacityThreshold = 0.5

        entity = ModelEntity(mesh: resource, materials: [material])
        self.mesh = mesh
        self.line = line
        self.queue = queue
        colourTexture = colour
        normalTexture = normal
        glossTexture = gloss
        self.glossStaging = glossStaging
        self.colourStaging = colourStaging
        self.normalStaging = normalStaging
        vertices = [Float](repeating: 0, count: rows * cols * Self.stride)
    }

    /// Takes in whatever changed since the last call. Free when nothing did.
    func update(from field: CreamField) {
        field.flush()
        guard let dirty = field.dirtyRows else { return }
        field.clearDirty()
        writeMesh(field, fieldRows: dirty)
        writeTextures(field, rows: dirty)
    }

    private func writeMesh(_ field: CreamField, fieldRows dirty: ClosedRange<Int>) {
        let rows = Self.meshRows, cols = Self.meshCols + 1
        let ratio = Float(CreamField.rows - 1) / Float(rows - 1)
        let first = max(Int(Float(dirty.lowerBound) / ratio) - 1, 0)
        let last = min(Int(Float(dirty.upperBound) / ratio) + 2, rows - 1)
        let length = line.length
        let fieldCols = CreamField.cols
        field.heights.withUnsafeBufferPointer { h in
            vertices.withUnsafeMutableBufferPointer { v in
                for j in first...last {
                    let s = length * Float(j) / Float(rows - 1)
                    let (point, n) = line.at(s)
                    let fieldRow = min(Int(Float(j) * ratio), CreamField.rows - 1)
                    let rowV = 1 - Float(fieldRow) / Float(CreamField.rows - 1)
                    for i in 0..<cols {
                        let u = Float(i) / Float(cols - 1)
                        let a = u * 2 * .pi
                        let thickness = h[fieldRow * fieldCols + min(Int(u * Float(fieldCols)), fieldCols - 1)]
                        // Bare spots sink under the dish; the texture cuts the rest cleanly.
                        let lift = thickness > 0 ? thickness * 0.8 + 0.3 : -1
                        let r = (point.x + n.x * lift) / 1000, z = (point.y + n.y * lift) / 1000
                        let c = cos(a), sn = sin(a)
                        let at = (j * cols + i) * Self.stride
                        // Plate-local (x, y, z) to RealityKit (x, z, -y).
                        v[at] = r * c; v[at + 1] = z; v[at + 2] = -r * sn
                        v[at + 3] = n.x * c; v[at + 4] = n.y; v[at + 5] = -n.x * sn
                        v[at + 6] = u; v[at + 7] = rowV
                        v[at + 8] = -sn; v[at + 9] = 0; v[at + 10] = -c
                        // Along the line, toward the centre: +v in the texture.
                        v[at + 11] = -n.y * c; v[at + 12] = n.x; v[at + 13] = n.y * sn
                    }
                }
            }
        }
        let start = first * cols * Self.stride * 4, count = (last - first + 1) * cols * Self.stride * 4
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            vertices.withUnsafeBytes { src in
                raw[start..<(start + count)].copyBytes(from: src[start..<(start + count)])
            }
        }
    }

    private func writeTextures(_ field: CreamField, rows: ClosedRange<Int>) {
        let rowBytes = CreamField.cols * 4
        let start = rows.lowerBound * rowBytes, count = rows.count * rowBytes
        for (bytes, staging) in [(field.shaded, colourStaging), (field.normal, normalStaging), (field.gloss, glossStaging)] {
            bytes.withUnsafeBytes { src in
                guard let base = src.baseAddress else { return }
                (staging.contents() + start).copyMemory(from: base + start, byteCount: count)
            }
        }
        guard let commands = queue.makeCommandBuffer(), let blit = commands.makeBlitCommandEncoder() else { return }
        let size = MTLSize(width: CreamField.cols, height: CreamField.rows, depth: 1)
        for (staging, texture) in [(colourStaging, colourTexture), (normalStaging, normalTexture), (glossStaging, glossTexture)] {
            blit.copy(from: staging, sourceOffset: 0, sourceBytesPerRow: rowBytes, sourceBytesPerImage: rowBytes * CreamField.rows,
                      sourceSize: size, to: texture.replace(using: commands), destinationSlice: 0, destinationLevel: 0,
                      destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        }
        blit.endEncoding()
        commands.commit()
    }
}
