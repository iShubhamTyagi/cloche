import Foundation

/// The dish's colour. A finished bake is golden; one opened early is pale. Never burnt:
/// overtime keeps warm (BK-3).
public enum Browning: String, Codable, Sendable {
    case pale
    case golden
    case dark
}

/// The grade card: doneness and up to two stars (bake, serve).
public struct Grade: Codable, Equatable, Sendable {
    public static let maxStars = 2

    public let doneness: Double
    public let browning: Browning
    public let bakeStar: Bool
    public let serveStar: Bool

    public init(doneness: Double, browning: Browning, bakeStar: Bool, serveStar: Bool) {
        self.doneness = doneness
        self.browning = browning
        self.bakeStar = bakeStar
        self.serveStar = serveStar
    }

    public var stars: Int {
        [bakeStar, serveStar].filter { $0 }.count
    }

    public var isHalfBaked: Bool { doneness < 1 }
}

/// Turns a finished or abandoned bake into a grade. Nothing is ever taken away: a half-baked
/// dish can still earn the serve star (PRD §9).
public enum GradeCalculator {
    public static func grade(_ outcome: BakeOutcome, served: Bool) -> Grade {
        let browning = browning(for: outcome)
        guard !outcome.bake.isDemo else {
            return Grade(doneness: outcome.doneness, browning: browning, bakeStar: false, serveStar: false)
        }
        return Grade(doneness: outcome.doneness, browning: browning, bakeStar: outcome.isFullyBaked, serveStar: served)
    }

    static func browning(for outcome: BakeOutcome) -> Browning {
        outcome.isFullyBaked ? .golden : .pale
    }
}
