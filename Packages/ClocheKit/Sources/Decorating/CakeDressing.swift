import Foundation

/// A ring the piping bag follows. `base` runs around the foot of the cake, on the plate.
public enum PipeRing: String, Codable, CaseIterable, Sendable {
    case edge, middle, base
}

/// What sits on the cream, derived from its ops: the beads on their ring slots and the toppings.
/// (The cream itself is a `CreamField`.) Everything here is a handful of small values, so applying an op, undoing and
/// replaying are all cheap enough to do between frames. Beads sit on even slots, so a piped ring
/// always closes neatly however the finger moved.
public struct CakeDressing: Equatable, Sendable {
    public struct BeadKey: Hashable, Sendable {
        public var ring: PipeRing
        public var slot: Int

        public init(ring: PipeRing, slot: Int) {
            self.ring = ring
            self.slot = slot
        }
    }

    public typealias Placement = CakeSurfaces.Placement

    public let geometry: CakeGeometry
    /// Palette index of the bead on each occupied slot.
    public private(set) var beads: [BeadKey: Int] = [:]
    public private(set) var placements: [Placement] = []
    /// Bumped on every change, so the renderer only looks when something happened.
    public private(set) var revision = 0

    public init(geometry: CakeGeometry) {
        self.geometry = geometry
    }

    public init(document: DecorDocument) {
        self.init(geometry: document.dish)
        for op in document.ops { apply(op) }
    }

    public mutating func apply(_ op: DecorOp) {
        switch op {
        case let .beads(colour, ring, slots):
            for slot in slots { beads[BeadKey(ring: ring, slot: slot)] = colour }
        case let .topping(kind, variant, at, spin):
            placements.append(Placement(kind: kind, variant: variant, at: at, spin: spin))
        case let .sprinkles(seed, at, radius):
            scatter(seed: seed, at: at, radius: radius)
        default:
            return
        }
        revision += 1
    }

    private mutating func scatter(seed: UInt64, at: SurfacePoint, radius: Float) {
        var rng = SplitMix64(seed: seed)
        let cx = at.a * cos(at.b), cy = at.a * sin(at.b)
        for _ in 0..<40 {
            let r = radius * Float(rng.unit()).squareRoot()
            let a = Float(rng.unit()) * 2 * .pi
            let x = cx + r * cos(a), y = cy + r * sin(a)
            let point = SurfacePoint.top(radius: min((x * x + y * y).squareRoot(), geometry.radius * 0.97), angle: atan2(y, x))
            placements.append(Placement(kind: "sprinkle", variant: Int(rng.next() % 5), at: point, spin: Float(rng.unit()) * 2 * .pi))
        }
    }
}

/// Where things go on a dish, in millimetres. Shared by the input and the renderer.
public extension CakeGeometry {
    var coatThickness: Float { CreamField.thickness }
    /// The spatula's working width.
    var bladeWidth: Float { radius * (hasSide ? 0.36 : 0.62) }
    var beadDiameter: Float { radius * (hasSide ? 0.17 : 0.27) }
    /// The turning plate. The stand is true size: it is the same object the oven stands beside.
    var plateRadius: Float { 150 }
    /// From the plate's top down to the slab.
    var standHeight: Float { 205.5 }
    /// Plate to the top of the cloche's finial.
    var clocheHeight: Float { 206 }
    /// How much of the plate the decorating view frames: all of it for a cake, close in on a cupcake.
    var viewRadius: Float { hasSide ? plateRadius : radius * 2.3 }

    /// The rings this dish can be piped on (a cupcake's liner leaves no foot to pipe).
    var pipeRings: [PipeRing] { hasSide ? [.edge, .middle, .base] : [.edge, .middle] }

    func radius(of ring: PipeRing) -> Float {
        switch ring {
        case .edge: radius * (hasSide ? 0.9 : 0.84)
        case .middle: radius * (hasSide ? 0.52 : 0.42)
        case .base: radius + coatThickness + beadDiameter * 0.22
        }
    }

    /// Slots around a ring, close enough that neighbouring beads touch.
    func slots(on ring: PipeRing) -> Int {
        max(6, Int((2 * .pi * radius(of: ring) / (beadDiameter * 0.86)).rounded()))
    }

    func angle(of slot: Int, on ring: PipeRing) -> Float {
        2 * .pi * Float(slot) / Float(slots(on: ring))
    }

    func slot(at angle: Float, on ring: PipeRing) -> Int {
        let n = slots(on: ring)
        let turns = angle / (2 * .pi)
        return ((Int((turns * Float(n)).rounded()) % n) + n) % n
    }

    /// The top ring nearest a radius.
    func nearestTopRing(to r: Float) -> PipeRing {
        abs(r - radius(of: .edge)) < abs(r - radius(of: .middle)) ? .edge : .middle
    }

    /// The tidy positions toppings settle into: rings between the piped ones, plus the centre.
    var toppingRings: [(radius: Float, count: Int)] {
        hasSide ? [(radius * 0.72, 12), (radius * 0.3, 6), (0, 1)] : [(radius * 0.62, 6), (0, 1)]
    }

    /// The tidy position nearest a point on the top.
    func snappedTopping(radius r: Float, angle: Float) -> SurfacePoint {
        let ring = toppingRings.min { abs($0.radius - r) < abs($1.radius - r) } ?? (0, 1)
        guard ring.radius > 0 else { return .top(radius: 0, angle: 0) }
        let step = 2 * .pi / Float(ring.count)
        let k = ((Int((angle / step).rounded()) % ring.count) + ring.count) % ring.count
        return .top(radius: ring.radius, angle: Float(k) * step)
    }
}
