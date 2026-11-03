import Foundation

/// Where on the cake a point lies. Plate-local: the turntable's rotation is already taken out,
/// so a point stays on the same spot of the cake however the plate turns.
public enum DecorSurface: String, Codable, Sendable {
    case top
    case side
}

/// One point of a stroke in plate-local coordinates (millimetres, radians).
/// - top: `a` = radius from the cake's centre, `b` = angle
/// - side: `a` = angle around the cake, `b` = height above the plate
public struct SurfacePoint: Codable, Equatable, Sendable {
    public var surface: DecorSurface
    public var a: Float
    public var b: Float

    public init(surface: DecorSurface, a: Float, b: Float) {
        self.surface = surface
        self.a = a
        self.b = b
    }

    public static func top(radius: Float, angle: Float) -> SurfacePoint { .init(surface: .top, a: radius, b: angle) }
    public static func side(angle: Float, height: Float) -> SurfacePoint { .init(surface: .side, a: angle, b: height) }
}

public enum Nozzle: String, Codable, CaseIterable, Sendable {
    case round, star, petal

    var brush: Brush {
        switch self {
        case .round: .beadRound
        case .star: .beadStar
        case .petal: .beadPetal
        }
    }
}

public enum BeadSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large

    public var scale: Float {
        switch self {
        case .small: 0.75
        case .medium: 1
        case .large: 1.35
        }
    }
}

/// One decorating action. A cake is an ordered list of these; replaying the list rebuilds it
/// exactly (recipe book, share card, time-lapse). Never pixels.
public enum DecorOp: Codable, Equatable, Sendable {
    /// Piping cone: beads along the path.
    case pipe(nozzle: Nozzle, size: BeadSize, colour: Int, points: [SurfacePoint])
    /// Offset spatula: spreads and smooths toward an even coat.
    case spread(colour: Int, points: [SurfacePoint])
    /// Pour: a pool of ganache or glaze with a drip edge.
    case pour(colour: Int, at: SurfacePoint, scale: Float)
    /// Squeeze bottle: thin lines.
    case drizzle(colour: Int, points: [SurfacePoint])
    /// Sieve: a soft powder, colour only.
    case dust(colour: Int, points: [SurfacePoint])
    /// One 3D topping, placed at a point; `spin` is its turn about the surface normal.
    case topping(kind: String, variant: Int, at: SurfacePoint, spin: Float)
    /// A pinch of sprinkles: instanced rods scattered from `seed`.
    case sprinkles(seed: UInt64, at: SurfacePoint, radius: Float)
    /// The turntable started or stopped (kept for the time-lapse).
    case turntable(spinning: Bool, speed: Float, time: Double)
    case plate(String)
    case backdrop(String)
}

/// A decorated cake: what the recipe book stores.
public struct DecorDocument: Codable, Equatable, Sendable {
    public var dish: CakeGeometry
    public var ops: [DecorOp]

    public init(dish: CakeGeometry, ops: [DecorOp] = []) {
        self.dish = dish
        self.ops = ops
    }
}

/// The decorated body's size in millimetres: a cylinder (cake) or a cupcake's crown.
public struct CakeGeometry: Codable, Equatable, Sendable {
    public var radius: Float
    public var height: Float
    /// Cupcakes have no decoratable side (the liner covers it).
    public var hasSide: Bool

    public init(radius: Float, height: Float, hasSide: Bool) {
        self.radius = radius
        self.height = height
        self.hasSide = hasSide
    }

    /// The turned-out cake (build/cake_turnout.blend: 196 mm across, 40 mm tall).
    public static let cake = CakeGeometry(radius: 98, height: 40, hasSide: true)
    /// One hero cupcake's crown (64 mm across).
    public static let cupcake = CakeGeometry(radius: 32, height: 49, hasSide: false)
}
