import Foundation

/// What the player asked for on the Prep screen.
public struct BakeRequest: Equatable, Sendable {
    public let recipe: Recipe
    public let temperature: Temperature
    public let source: DoorSource
    /// The 15 s demo bake from Settings: labelled, earns no stars (DR-6).
    public let isDemo: Bool

    public init(recipe: Recipe, temperature: Temperature, source: DoorSource, isDemo: Bool = false) {
        self.recipe = recipe
        self.temperature = temperature
        self.source = source
        self.isDemo = isDemo
    }
}

/// One bake in progress. Time is stored as dates, never counted by ticking (BK-1).
public struct Bake: Codable, Equatable, Sendable {
    public static let demoDuration: TimeInterval = 15
    public static let demoBreakDuration: TimeInterval = 60

    public let recipeID: String
    public let temperature: Temperature
    public let idealTemperature: Temperature
    public let duration: TimeInterval
    public let breakDuration: TimeInterval
    public let source: DoorSource
    public let isDemo: Bool
    /// Set when the door first closes.
    public private(set) var startedAt: Date?

    public init(_ request: BakeRequest) {
        recipeID = request.recipe.id
        temperature = request.temperature
        idealTemperature = request.recipe.idealTemperature
        duration = request.isDemo ? Self.demoDuration : TimeInterval(request.recipe.bakeMinutes * 60)
        breakDuration = request.isDemo ? Self.demoBreakDuration : TimeInterval(request.recipe.breakMinutes * 60)
        source = request.source
        isDemo = request.isDemo
    }

    public var endsAt: Date? {
        startedAt.map { $0.addingTimeInterval(duration) }
    }

    func started(at date: Date) -> Bake {
        var copy = self
        copy.startedAt = date
        return copy
    }

    /// Fraction baked if the door opened at `date`, 0 to 1.
    func doneness(openedAt date: Date) -> Double {
        guard let startedAt, duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(startedAt) / duration, 0), 1)
    }
}

/// A bake that has come out of the oven, finished or not.
public struct BakeOutcome: Codable, Equatable, Sendable {
    public let bake: Bake
    /// Time baked over target time. 1 means fully baked.
    public let doneness: Double

    public var isFullyBaked: Bool { doneness >= 1 }
}
