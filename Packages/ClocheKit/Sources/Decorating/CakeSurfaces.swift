import Foundation

/// The icing on one cake: a top field (Cartesian, centred on the cake, covering its disc) and a
/// side strip (unrolled, wrapping left to right). Ops address points in plate-local polar
/// coordinates; this maps them into the fields. Replaying a document from scratch rebuilds it
/// exactly.
public struct CakeSurfaces: Equatable, Sendable {
    public let geometry: CakeGeometry
    public private(set) var top: HeightField
    public private(set) var side: HeightField?
    /// The 3D toppings and sprinkles, in op order (the renderer instances them).
    public private(set) var placements: [Placement] = []
    public private(set) var plate: String?
    public private(set) var backdrop: String?

    public struct Placement: Equatable, Sendable {
        public var kind: String
        public var variant: Int
        public var at: SurfacePoint
        public var spin: Float
    }

    /// Texel size: about 0.4 mm on the top and the side.
    public init(geometry: CakeGeometry, topResolution: Int = 512) {
        self.geometry = geometry
        let diameter = geometry.radius * 2
        top = HeightField(width: topResolution, height: topResolution, mmPerTexel: diameter / Float(topResolution), wrapsX: false)
        if geometry.hasSide {
            let circumference = 2 * Float.pi * geometry.radius
            let mm = diameter / Float(topResolution)
            side = HeightField(width: Int(circumference / mm), height: Int(geometry.height / mm) + 1, mmPerTexel: mm, wrapsX: true)
        }
    }

    public init(document: DecorDocument) {
        self.init(geometry: document.dish)
        for op in document.ops { apply(op) }
    }

    /// Top: plate-local polar → field mm (origin at the field's corner).
    public func topPosition(radius: Float, angle: Float) -> SIMD2<Float> {
        SIMD2(geometry.radius + radius * cos(angle), geometry.radius + radius * sin(angle))
    }

    /// Side: angle and height → strip mm (x along the circumference).
    public func sidePosition(angle: Float, height: Float) -> SIMD2<Float> {
        let turn = 2 * Float.pi
        let wrapped = (angle.truncatingRemainder(dividingBy: turn) + turn).truncatingRemainder(dividingBy: turn)
        return SIMD2(wrapped * geometry.radius, height)
    }

    private func split(_ points: [SurfacePoint]) -> (top: [SIMD2<Float>], side: [SIMD2<Float>]) {
        var top: [SIMD2<Float>] = [], side: [SIMD2<Float>] = []
        for p in points {
            switch p.surface {
            case .top: top.append(topPosition(radius: p.a, angle: p.b))
            case .side: side.append(unwrapped(sidePosition(angle: p.a, height: p.b), after: side.last))
            }
        }
        return (top, side)
    }

    /// Keeps a side path continuous across the seam (the field wraps it back).
    private func unwrapped(_ p: SIMD2<Float>, after last: SIMD2<Float>?) -> SIMD2<Float> {
        guard let last else { return p }
        let length = 2 * Float.pi * geometry.radius
        var x = p.x
        while x - last.x > length / 2 { x -= length }
        while last.x - x > length / 2 { x += length }
        return SIMD2(x, p.y)
    }

    public mutating func apply(_ op: DecorOp) {
        switch op {
        case let .pipe(nozzle, size, colour, points):
            let (t, s) = split(points)
            if !t.isEmpty { top.stroke(nozzle.brush, path: t, scale: size.scale, colour: colour, tail: true) }
            if !s.isEmpty { side?.stroke(nozzle.brush, path: s, scale: size.scale, colour: colour, tail: true) }
        case let .spread(colour, points):
            let (t, s) = split(points)
            if !t.isEmpty { top.spread(path: t, target: 3, colour: colour) }
            if !s.isEmpty { side?.spread(path: s, target: 2.5, colour: colour) }
        case let .pour(colour, at, scale):
            if at.surface == .top {
                top.pour(at: topPosition(radius: at.a, angle: at.b), scale: scale, level: 2.5, colour: colour)
            }
            // A pour near the top edge runs down the side as drips.
            if let side, at.surface == .top, at.a + Brush.pourBlob.footprint * scale * 0.4 > geometry.radius {
                var strip = side
                let reach = Brush.pourBlob.footprint * scale * 0.4
                let span = reach / geometry.radius
                var k: Float = -1
                while k <= 1 {
                    let angle = at.b + k * span
                    let length = geometry.height * (0.25 + 0.35 * abs(sin(angle * 7.3)))
                    let x = sidePosition(angle: angle, height: 0).x
                    strip.stroke(.drizzle, path: [SIMD2(x, geometry.height), SIMD2(x, geometry.height - length)],
                                 scale: 2.2, colour: colour, tail: false)
                    k += 0.25
                }
                self.side = strip
            }
        case let .drizzle(colour, points):
            let (t, s) = split(points)
            if !t.isEmpty { top.stroke(.drizzle, path: t, scale: 1, colour: colour, tail: false) }
            if !s.isEmpty { side?.stroke(.drizzle, path: s, scale: 1, colour: colour, tail: false) }
        case let .dust(colour, points):
            let (t, s) = split(points)
            if !t.isEmpty { top.dust(path: t, radius: 14, colour: colour) }
            if !s.isEmpty { side?.dust(path: s, radius: 10, colour: colour) }
        case let .topping(kind, variant, at, spin):
            placements.append(Placement(kind: kind, variant: variant, at: at, spin: spin))
        case let .sprinkles(seed, at, radius):
            var rng = SplitMix64(seed: seed)
            for _ in 0..<40 {
                let r = radius * Float(rng.unit()).squareRoot()
                let a = Float(rng.unit()) * 2 * .pi
                let p: SurfacePoint
                switch at.surface {
                case .top:
                    let c = topPosition(radius: at.a, angle: at.b) + SIMD2(r * cos(a), r * sin(a)) - SIMD2(geometry.radius, geometry.radius)
                    p = .top(radius: min((c.x * c.x + c.y * c.y).squareRoot(), geometry.radius), angle: atan2(c.y, c.x))
                case .side:
                    p = .side(angle: at.a + r * cos(a) / geometry.radius, height: min(max(at.b + r * sin(a), 0), geometry.height))
                }
                placements.append(Placement(kind: "sprinkle", variant: Int(rng.next() % 5), at: p, spin: Float(rng.unit()) * 2 * .pi))
            }
        case .turntable, .cream, .beads:
            break
        case let .plate(name):
            plate = name
        case let .backdrop(name):
            backdrop = name
        }
    }

    /// Height of the icing (mm) at a surface point.
    public func icingHeight(at p: SurfacePoint) -> Float {
        switch p.surface {
        case .top:
            let q = topPosition(radius: p.a, angle: p.b)
            return top.height(atX: q.x, y: q.y)
        case .side:
            let q = sidePosition(angle: p.a, height: p.b)
            return side?.height(atX: q.x, y: q.y) ?? 0
        }
    }
}

/// A small deterministic generator, so replays scatter sprinkles identically everywhere.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
