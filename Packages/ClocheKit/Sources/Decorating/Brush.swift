import Foundation

/// The brush height maps, generated in code with the same formulas as
/// `scripts/blender/brushes.py` (the PNGs it writes are the reference; nothing is loaded).
public enum Brush: String, CaseIterable, Sendable {
    case beadRound = "bead_round"
    case beadStar = "bead_star"
    case beadPetal = "bead_petal"
    case dollop
    case tail
    case drizzle
    case spatulaMask = "spatula_mask"
    case pourBlob = "pour_blob"

    /// Map width in millimetres at scale 1.
    public var footprint: Float {
        switch self {
        case .beadRound: 6
        case .beadStar: 9
        case .beadPetal: 12
        case .dollop: 9
        case .tail: 5
        case .drizzle: 2.4
        case .spatulaMask: 40
        case .pourBlob: 60
        }
    }

    /// Peak height in millimetres at scale 1 (masks are 1).
    public var maxHeight: Float {
        switch self {
        case .beadRound: 3.2
        case .beadStar: 4
        case .beadPetal: 3
        case .dollop: 4.8
        case .tail: 3.6
        case .drizzle: 0.9
        case .spatulaMask, .pourBlob: 1
        }
    }

    static let resolution = 128

    /// The 0...1 map, row-major, `resolution` square.
    var map: [Float] { BrushMaps.shared.maps[self] ?? [] }

    /// The map's value at u, v in -1...1 (nearest texel; 0 outside).
    func value(u: Float, v: Float) -> Float {
        guard abs(u) <= 1, abs(v) <= 1 else { return 0 }
        let n = Self.resolution
        let iu = min(max(Int((u + 1) / 2 * Float(n)), 0), n - 1)
        let iv = min(max(Int((v + 1) / 2 * Float(n)), 0), n - 1)
        return map[iv * n + iu]
    }
}

/// Generated once, then read-only.
final class BrushMaps: Sendable {
    static let shared = BrushMaps()
    let maps: [Brush: [Float]]

    private init() {
        var out: [Brush: [Float]] = [:]
        for brush in Brush.allCases {
            out[brush] = Self.generate(brush)
        }
        maps = out
    }

    private static func dome(_ r: Float, _ power: Float) -> Float {
        pow(max(1 - r * r, 0), power)
    }

    private static func generate(_ brush: Brush) -> [Float] {
        let n = Brush.resolution
        var out = [Float](repeating: 0, count: n * n)
        // A fixed wobble for the pour blob's organic edge (brushes.py uses numpy's RNG; the
        // exact wobble differs, the shape class is the same).
        var wobble: [(k: Float, amp: Float, phase: Float)] = []
        for k in 2...8 {
            let amp = 0.02 + 0.04 * Float((k * 37) % 11) / 10
            let phase = Float((k * 53) % 17) / 17 * 6.283
            wobble.append((Float(k), amp, phase))
        }
        for j in 0..<n {
            for i in 0..<n {
                let x = (Float(i) + 0.5) / Float(n) * 2 - 1
                let y = (Float(j) + 0.5) / Float(n) * 2 - 1
                let r = (x * x + y * y).squareRoot()
                let th = atan2(y, x)
                let value: Float
                switch brush {
                case .beadRound:
                    value = dome(r, 0.6)
                case .beadStar:
                    value = dome(r / (0.88 + 0.12 * cos(8 * th)), 0.55) * (0.78 + 0.22 * cos(8 * th))
                case .beadPetal:
                    let across = min(max((y + 1) / 2, 0), 1)
                    value = abs(y) < 0.98
                        ? pow(max(1 - (x / 0.95) * (x / 0.95), 0), 0.5) * pow(1 - across, 1.4) * (0.9 + 0.1 * sin(x * 18))
                        : 0
                case .dollop:
                    value = dome(r, 0.75)
                case .tail:
                    value = pow(max(1 - r, 0), 1.6)
                case .drizzle:
                    value = dome(r, 0.5)
                case .spatulaMask:
                    value = pow(max(1 - x * x - (y / 0.33) * (y / 0.33), 0), 0.7)
                case .pourBlob:
                    var edge: Float = 0.82
                    for w in wobble { edge += w.amp * cos(w.k * th + w.phase) }
                    let t = min(max((edge - r) / 0.08, 0), 1)
                    value = t * t * (3 - 2 * t)
                }
                out[j * n + i] = value
            }
        }
        return out
    }
}
