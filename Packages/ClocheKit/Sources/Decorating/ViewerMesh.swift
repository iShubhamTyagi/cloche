import Foundation

/// The bare dish's shape, exported by `scripts/blender/cake_maps.py` (profile.json), in metres,
/// dish-local (origin at the centre of the base, +Z up).
public struct DishProfile: Codable, Equatable, Sendable {
    public var radius: Float
    public var topRadius: Float
    public var sideBottom: Float
    public var sideTop: Float
    public var height: Float
    public var topHeightsRings: [Float]
    public var sideRadiiRows: [Float]
    public var decoratableSide: Bool

    enum CodingKeys: String, CodingKey {
        case radius, height
        case topRadius = "top_radius", sideBottom = "side_bottom", sideTop = "side_top"
        case topHeightsRings = "top_heights_rings", sideRadiiRows = "side_radii_rows"
        case decoratableSide = "decoratable_side"
    }

    /// A plain cylinder (or crowned cupcake) for when no export is bundled.
    public static func placeholder(_ g: CakeGeometry) -> DishProfile {
        let r = g.radius / 1000, h = g.height / 1000
        let rings = (0...32).map { i -> Float in
            let t = Float(i) / 32
            return g.hasSide ? h - 0.002 * t * t * t * t : h - h * 0.35 * t * t
        }
        return DishProfile(radius: r, topRadius: r, sideBottom: 0, sideTop: g.hasSide ? h - 0.002 : h * 0.65, height: h,
                           topHeightsRings: rings, sideRadiiRows: Array(repeating: r, count: 9), decoratableSide: g.hasSide)
    }

    /// The decorating geometry (mm) this profile stands for.
    public var geometry: CakeGeometry {
        CakeGeometry(radius: topRadius * 1000, height: (decoratableSide ? sideTop : height) * 1000, hasSide: decoratableSide)
    }

    public func topHeight(atRadius r: Float) -> Float { Self.sample(topHeightsRings, at: r / max(topRadius, 1e-6)) }
    public func sideRadius(atHeight z: Float) -> Float {
        Self.sample(sideRadiiRows, at: (z - sideBottom) / max(sideTop - sideBottom, 1e-6))
    }

    static func sample(_ values: [Float], at t: Float) -> Float {
        guard values.count > 1 else { return values.first ?? 0 }
        let x = min(max(t, 0), 1) * Float(values.count - 1)
        let i = min(Int(x), values.count - 2)
        let f = x - Float(i)
        return values[i] * (1 - f) + values[i + 1] * f
    }
}

/// Interleaved vertices (position xyz, normal xyz, uv; 8 floats) and triangle indices, in
/// RealityKit's frame: metres, +Y up, the viewer at +Z. Plate-local (x, y, z) → (x, z, -y).
public struct MeshData: Sendable {
    public var vertices: [Float]
    public var indices: [UInt32]
    public var boundsMin: SIMD3<Float>
    public var boundsMax: SIMD3<Float>
    public var vertexCount: Int { vertices.count / 8 }
}

public enum ViewerMesh {
    public static let topRings = 120
    public static let topSegments = 384
    public static let sideRows = 48

    /// The bare cake's top (polar UVs: u = angle / 2π, v = radius / R).
    public static func cakeTop(_ p: DishProfile) -> MeshData {
        polarGrid(p, rings: 96, segments: 256) { r, _ in p.topHeight(atRadius: r) } uv: { r, a in
            SIMD2(a / (2 * .pi), r / p.topRadius)
        }
    }

    /// The bare side (UVs: u = angle / 2π, v = height share).
    public static func cakeSide(_ p: DishProfile) -> MeshData {
        sideGrid(p, rows: 32, segments: 256) { z, _ in p.sideRadius(atHeight: z) } uv: { z, a in
            SIMD2(a / (2 * .pi), (z - p.sideBottom) / max(p.sideTop - p.sideBottom, 1e-6))
        }
    }

    /// The icing over the top: the bare height plus the field; where there is no icing (or
    /// powder) the vertex sinks just under the cake so it never shows. UVs address the field.
    public static func icingTop(_ p: DishProfile, field: HeightField) -> MeshData {
        let d = p.topRadius * 2
        return polarGrid(p, rings: topRings, segments: topSegments) { r, a in
            let x = (p.topRadius + r * cos(a)) * 1000, y = (p.topRadius + r * sin(a)) * 1000
            let h = field.height(atX: x, y: y)
            return p.topHeight(atRadius: r) + (h > 0.02 ? h / 1000 + 0.0002 : -0.0008)
        } uv: { r, a in
            SIMD2((p.topRadius + r * cos(a)) / d, 1 - (p.topRadius + r * sin(a)) / d)
        }
    }

    public static func icingSide(_ p: DishProfile, field: HeightField, geometry: CakeGeometry) -> MeshData {
        let span = p.sideTop - p.sideBottom
        return sideGrid(p, rows: sideRows, segments: topSegments) { z, a in
            let turn = 2 * Float.pi
            let wrapped = (a.truncatingRemainder(dividingBy: turn) + turn).truncatingRemainder(dividingBy: turn)
            let h = field.height(atX: wrapped * geometry.radius, y: (z - p.sideBottom) / max(span, 1e-6) * geometry.height)
            return p.sideRadius(atHeight: z) + (h > 0.02 ? h / 1000 + 0.0002 : -0.0008)
        } uv: { z, a in
            SIMD2(a / (2 * .pi), 1 - (z - p.sideBottom) / max(span, 1e-6))
        }
    }

    // MARK: Grids

    static func polarGrid(_ p: DishProfile, rings: Int, segments: Int,
                          height: (Float, Float) -> Float, uv: (Float, Float) -> SIMD2<Float>) -> MeshData {
        var pos = [SIMD3<Float>](), uvs = [SIMD2<Float>]()
        pos.reserveCapacity((rings + 1) * (segments + 1))
        for i in 0...rings {
            let r = p.topRadius * Float(i) / Float(rings)
            for s in 0...segments {
                let a = 2 * Float.pi * Float(s) / Float(segments)
                pos.append(SIMD3(r * cos(a), r * sin(a), height(r, a)))
                uvs.append(uv(r, a))
            }
        }
        return assemble(pos, uvs, rows: rings + 1, cols: segments + 1, flip: false)
    }

    static func sideGrid(_ p: DishProfile, rows: Int, segments: Int,
                         radius: (Float, Float) -> Float, uv: (Float, Float) -> SIMD2<Float>) -> MeshData {
        var pos = [SIMD3<Float>](), uvs = [SIMD2<Float>]()
        for j in 0...rows {
            let z = p.sideBottom + (p.sideTop - p.sideBottom) * Float(j) / Float(rows)
            for s in 0...segments {
                let a = 2 * Float.pi * Float(s) / Float(segments)
                let r = radius(z, a)
                pos.append(SIMD3(r * cos(a), r * sin(a), z))
                uvs.append(uv(z, a))
            }
        }
        return assemble(pos, uvs, rows: rows + 1, cols: segments + 1, flip: true)
    }

    /// Normals from grid neighbours; converts to RealityKit's frame; two triangles per quad.
    static func assemble(_ pos: [SIMD3<Float>], _ uvs: [SIMD2<Float>], rows: Int, cols: Int, flip: Bool) -> MeshData {
        var vertices = [Float]()
        vertices.reserveCapacity(pos.count * 8)
        var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity)
        for j in 0..<rows {
            for i in 0..<cols {
                let k = j * cols + i
                // Neighbours along the row wrap past the duplicated seam column.
                let left = pos[j * cols + (i == 0 ? cols - 2 : i - 1)]
                let right = pos[j * cols + (i == cols - 1 ? 1 : i + 1)]
                let down = pos[max(j - 1, 0) * cols + i], up = pos[min(j + 1, rows - 1) * cols + i]
                var n = normalize3(cross3(up - down, right - left))
                if flip { n = -n }
                if j == 0, !flip { n = SIMD3(0, 0, 1) }       // the polar centre
                if dot3(n, n) == 0 { n = SIMD3(0, 0, 1) }
                let p = pos[k]
                let rk = SIMD3(p.x, p.z, -p.y)
                lo = SIMD3(min(lo.x, rk.x), min(lo.y, rk.y), min(lo.z, rk.z))
                hi = SIMD3(max(hi.x, rk.x), max(hi.y, rk.y), max(hi.z, rk.z))
                vertices += [rk.x, rk.y, rk.z, n.x, n.z, -n.y, uvs[k].x, uvs[k].y]
            }
        }
        var indices = [UInt32]()
        indices.reserveCapacity((rows - 1) * (cols - 1) * 6)
        for j in 0..<(rows - 1) {
            for i in 0..<(cols - 1) {
                let a = UInt32(j * cols + i), b = a + 1, c = a + UInt32(cols), d = c + 1
                if flip {
                    indices += [a, b, c, b, d, c]
                } else {
                    indices += [a, c, b, b, c, d]
                }
            }
        }
        return MeshData(vertices: vertices, indices: indices, boundsMin: lo, boundsMax: hi)
    }
}
