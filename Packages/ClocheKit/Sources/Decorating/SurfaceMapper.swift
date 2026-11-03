import Foundation

/// Maps between rays and plate-local cake surface points. Plate-local frame: millimetres, origin
/// at the centre of the plate's top, +Z up, the cake a cylinder of `radius` from z = 0 to
/// `height`. The turntable angle is removed by the caller (`Turntable.toPlate`).
public struct SurfaceMapper: Sendable {
    public let geometry: CakeGeometry

    public init(geometry: CakeGeometry) {
        self.geometry = geometry
    }

    public struct Hit: Equatable, Sendable {
        public var point: SurfacePoint
        public var position: SIMD3<Float>
        public var normal: SIMD3<Float>
        public var distance: Float
    }

    /// The nearest hit of a ray on the cake's top disc or (if the dish has one) its side.
    public func hit(origin: SIMD3<Float>, direction: SIMD3<Float>) -> Hit? {
        let d = normalize3(direction)
        var best: Hit?
        // Top disc at z = height.
        if abs(d.z) > 1e-6 {
            let t = (geometry.height - origin.z) / d.z
            if t > 0 {
                let p = origin + d * t
                let r = (p.x * p.x + p.y * p.y).squareRoot()
                if r <= geometry.radius {
                    best = Hit(point: .top(radius: r, angle: atan2(p.y, p.x)), position: p, normal: SIMD3(0, 0, 1), distance: t)
                }
            }
        }
        // Side cylinder: x² + y² = R², 0 ≤ z ≤ height.
        if geometry.hasSide {
            let a = d.x * d.x + d.y * d.y
            let b = 2 * (origin.x * d.x + origin.y * d.y)
            let c = origin.x * origin.x + origin.y * origin.y - geometry.radius * geometry.radius
            let disc = b * b - 4 * a * c
            if a > 1e-9, disc >= 0 {
                let t = (-b - disc.squareRoot()) / (2 * a)
                let p = origin + d * t
                if t > 0, p.z >= 0, p.z <= geometry.height, t < (best?.distance ?? .infinity) {
                    let n = normalize3(SIMD3(p.x, p.y, 0))
                    best = Hit(point: .side(angle: atan2(p.y, p.x), height: p.z), position: p, normal: n, distance: t)
                }
            }
        }
        return best
    }

    /// The 3D position (on the bare cake, before icing) and normal of a surface point.
    public func position(of point: SurfacePoint) -> (position: SIMD3<Float>, normal: SIMD3<Float>) {
        switch point.surface {
        case .top:
            return (SIMD3(point.a * cos(point.b), point.a * sin(point.b), geometry.height), SIMD3(0, 0, 1))
        case .side:
            let n = SIMD3(cos(point.a), sin(point.a), Float(0))
            return (SIMD3(n.x * geometry.radius, n.y * geometry.radius, point.b), n)
        }
    }
}

@inline(__always) func normalize3(_ v: SIMD3<Float>) -> SIMD3<Float> {
    let length = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
    return length > 0 ? v / length : v
}
