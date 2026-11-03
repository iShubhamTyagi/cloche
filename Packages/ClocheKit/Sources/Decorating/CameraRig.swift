import Foundation

/// The viewer's camera: it orbits only in elevation (90° straight down to about 10° from the
/// side) at a fixed azimuth, looking at the cake; the turntable turns the cake instead.
/// Plate-local millimetres, +Z up, the viewer stands at -Y.
public struct CameraRig: Equatable, Sendable {
    public enum Snap: String, CaseIterable, Sendable {
        case top, angle, side

        public var elevation: Float {
            switch self {
            case .top: 90
            case .angle: 55
            case .side: 10
            }
        }
    }

    public static let elevationRange: ClosedRange<Float> = 10...90
    public static let zoomRange: ClosedRange<Float> = 0.6...1.6

    /// Degrees above the horizon.
    public var elevation: Float
    /// 1 = the framing distance; smaller is closer.
    public var zoom: Float = 1
    /// Vertical field of view, degrees.
    public var fov: Float = 30
    /// What it looks at (the middle of the cake's top).
    public var target: SIMD3<Float>
    /// Distance at zoom 1, fitted so the cake fills `fill` of the narrower screen side.
    public var baseDistance: Float

    public init(elevation: Float = 90, target: SIMD3<Float>, cakeRadius: Float, aspect: Float, fill: Float = 0.78) {
        self.elevation = elevation
        self.target = target
        let halfV = Float(15) * .pi / 180
        // Horizontal half-angle from the vertical one and the aspect (width / height).
        let halfH = atan(tan(halfV) * min(aspect, 1))
        baseDistance = cakeRadius / fill / tan(halfH) * 1.05
    }

    public var distance: Float { baseDistance * zoom }

    public var position: SIMD3<Float> {
        let e = elevation * .pi / 180
        // Exactly vertical makes the up vector degenerate; 89.9° looks identical.
        let ec = min(e, 89.9 * .pi / 180)
        return target + SIMD3(0, -cos(ec) * distance, sin(ec) * distance)
    }

    public mutating func snap(_ snap: Snap) { elevation = snap.elevation }

    public mutating func tilt(by degrees: Float) {
        elevation = min(max(elevation + degrees, Self.elevationRange.lowerBound), Self.elevationRange.upperBound)
    }

    public mutating func pinch(scale: Float) {
        zoom = min(max(zoom / scale, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }

    /// Orthonormal camera basis: right, up, forward (toward the target).
    public var basis: (right: SIMD3<Float>, up: SIMD3<Float>, forward: SIMD3<Float>) {
        let f = normalize3(target - position)
        let worldUp = SIMD3<Float>(0, 0, 1)
        let r = normalize3(cross3(f, worldUp))
        let u = cross3(r, f)
        return (r, u, f)
    }

    /// The ray through a screen point; x, y in 0...1 from the top-left; aspect = width / height.
    public func ray(x: Float, y: Float, aspect: Float) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        let (r, u, f) = basis
        let t = tan(fov * .pi / 360)
        let dx = (x * 2 - 1) * t * aspect
        let dy = (1 - y * 2) * t
        return (position, normalize3(f + r * dx + u * dy))
    }

    /// Where a plate-local point lands on screen (0...1 from the top-left), or nil behind the camera.
    public func project(_ p: SIMD3<Float>, aspect: Float) -> SIMD2<Float>? {
        let (r, u, f) = basis
        let d = p - position
        let z = dot3(d, f)
        guard z > 0 else { return nil }
        let t = tan(fov * .pi / 360)
        let x = dot3(d, r) / z / (t * aspect)
        let y = dot3(d, u) / z / t
        return SIMD2((x + 1) / 2, (1 - y) / 2)
    }
}

@inline(__always) func cross3(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

@inline(__always) func dot3(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
    a.x * b.x + a.y * b.y + a.z * b.z
}
