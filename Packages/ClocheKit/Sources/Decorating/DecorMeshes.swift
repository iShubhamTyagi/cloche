import Foundation

/// The meshes decorating draws with, built once when the scene loads.
public extension ViewerMesh {
    /// The cloche's glass, as one smooth turned surface from the centre of its top down to the rim.
    /// Same sizes as scripts/blender/cloche.py, in metres, its rim at z = 0.
    static func clocheGlass() -> MeshData {
        let radius: Float = 0.1342, height: Float = 0.163, shoulder: Float = 0.025, crown: Float = 0.003
        var line: [SIMD2<Float>] = []
        let flat = radius - shoulder
        for i in 0...24 {
            let t = Float(i) / 24
            line.append(SIMD2(flat * t, height - crown * t * t))
        }
        let wallTop = height - crown - shoulder
        for i in 1...16 {
            let a = Float(i) / 16 * .pi / 2
            line.append(SIMD2(flat + shoulder * sin(a), wallTop + shoulder * cos(a)))
        }
        for i in 1...10 { line.append(SIMD2(radius, wallTop * (1 - Float(i) / 10))) }
        let segments = 192
        var pos = [SIMD3<Float>](), uvs = [SIMD2<Float>]()
        for p in line {
            for s in 0...segments {
                let a = 2 * Float.pi * Float(s) / Float(segments)
                pos.append(SIMD3(p.x * cos(a), p.x * sin(a), p.y))
                uvs.append(.zero)
            }
        }
        return assemble(pos, uvs, rows: line.count, cols: segments + 1, flip: false)
    }

    /// A cupcake's crown overhangs its liner, and the exports leave a gap between the two: this
    /// is the underside of the crown, from the top of the liner out to the crown's edge.
    static func crownUnderside(_ p: DishProfile) -> MeshData {
        let segments = 96
        let inner = SIMD2(p.sideRadius(atHeight: p.sideTop) * 0.97, p.sideTop - 0.001)
        let outer = SIMD2(p.topRadius, p.topHeight(atRadius: p.topRadius))
        var pos = [SIMD3<Float>](), uvs = [SIMD2<Float>]()
        for row in [outer, inner] {
            for s in 0...segments {
                let a = 2 * Float.pi * Float(s) / Float(segments)
                pos.append(SIMD3(row.x * cos(a), row.x * sin(a), row.y))
                uvs.append(SIMD2(a / (2 * .pi), 0.9))
            }
        }
        return assemble(pos, uvs, rows: 2, cols: segments + 1, flip: false)
    }

    /// One piped star bead, standing on its base at the origin: fluted with fine ridges, twisting
    /// up to a tip that pulls off to one side, on a small spread of icing. `seed` picks its shape.
    static func bead(diameter: Float, seed: UInt64 = 1) -> MeshData {
        var rng = SplitMix64(seed: seed &* 0x9E37_79B9 &+ 5)
        func pick(_ lo: Float, _ hi: Float) -> Float { lo + (hi - lo) * Float(rng.unit()) }
        let radius = diameter / 2000
        let height = diameter / 1000 * pick(0.68, 0.84)
        let twist = pick(0.7, 1.5), pull = radius * pick(0.12, 0.42), pullAngle = pick(0, 2 * .pi)
        let spread = pick(0.1, 0.22), lobes = Float([6, 7, 7, 8][Int(rng.next() % 4)])
        let rows = 24, segments = 84
        var pos = [SIMD3<Float>](), uvs = [SIMD2<Float>]()
        pos.reserveCapacity((rows + 1) * (segments + 1))
        uvs.reserveCapacity((rows + 1) * (segments + 1))
        for j in 0...rows {
            let t = Float(j) / Float(rows)   // 0 at the tip, 1 at the base
            let swell = pow(sin(min(t * 1.2, 1) * .pi / 2), 1.15)
            let foot = t > 0.84 ? (t - 0.84) / 0.16 : 0
            let flute = 0.17 * min(t * 2.2, 1) * (1 - foot * 0.75)
            let lean = (1 - t) * (1 - t)
            let cx = pull * lean * cos(pullAngle), cy = pull * lean * sin(pullAngle)
            for s in 0...segments {
                let a = 2 * Float.pi * Float(s) / Float(segments)
                let turn = a + twist * (1 - t)
                let ridges = 1 + flute * cos(lobes * turn) + 0.022 * min(t * 3, 1) * cos(lobes * 3 * turn)
                let r = radius * swell * (1 + spread * foot * foot) * ridges
                pos.append(SIMD3(cx + r * cos(a), cy + r * sin(a), height * (1 - t) * (1 - 0.08 * foot)))
                uvs.append(SIMD2(a / (2 * .pi), t))
            }
        }
        return assemble(pos, uvs, rows: rows + 1, cols: segments + 1, flip: false)
    }

    /// A thin flat ring for a guide, `height` metres up.
    static func guide(radius: Float, height: Float, width: Float) -> MeshData {
        let segments = 128
        var pos = [SIMD3<Float>](), uvs = [SIMD2<Float>]()
        for r in [radius - width / 2, radius + width / 2] {
            for s in 0...segments {
                let a = 2 * Float.pi * Float(s) / Float(segments)
                pos.append(SIMD3(r * cos(a), r * sin(a), height))
                uvs.append(.zero)
            }
        }
        return assemble(pos, uvs, rows: 2, cols: segments + 1, flip: false)
    }
}
