import Foundation

public enum Browning: String, Codable, Sendable {
    case pale
    case golden
    case dark
}

/// The grade card: doneness, browning and up to three stars (bake, temperature, serve).
public struct Grade: Codable, Equatable, Sendable {
    public let doneness: Double
    public let browning: Browning
    public let bakeStar: Bool
    public let temperatureStar: Bool
    public let serveStar: Bool

    public init(doneness: Double, browning: Browning, bakeStar: Bool, temperatureStar: Bool, serveStar: Bool) {
        self.doneness = doneness
        self.browning = browning
        self.bakeStar = bakeStar
        self.temperatureStar = temperatureStar
        self.serveStar = serveStar
    }

    public var stars: Int {
        [bakeStar, temperatureStar, serveStar].filter { $0 }.count
    }

    public var isHalfBaked: Bool { doneness < 1 }
}

/// Turns a finished or abandoned bake into a grade. Nothing is ever taken away: a half-baked
/// dish can still earn the serve star (PRD §9).
public enum GradeCalculator {
    public static func grade(_ outcome: BakeOutcome, served: Bool) -> Grade {
        let bake = outcome.bake
        guard !bake.isDemo else {
            return Grade(doneness: outcome.doneness, browning: browning(for: outcome), bakeStar: false, temperatureStar: false, serveStar: false)
        }
        let fullyBaked = outcome.isFullyBaked
        return Grade(
            doneness: outcome.doneness,
            browning: browning(for: outcome),
            bakeStar: fullyBaked,
            temperatureStar: fullyBaked && bake.temperature == bake.idealTemperature,
            serveStar: served
        )
    }

    /// Too low is pale, too high is dark. An unfinished bake is always pale.
    static func browning(for outcome: BakeOutcome) -> Browning {
        guard outcome.isFullyBaked else { return .pale }
        let difference = outcome.bake.temperature.heat - outcome.bake.idealTemperature.heat
        if difference < 0 { return .pale }
        if difference > 0 { return .dark }
        return .golden
    }
}
