import Foundation

/// How long the oven runs, picked on the Prep screen. The break that follows belongs to the
/// bake: 5, 8 or 10 minutes after 25, 50 or 90 (PRD §8).
public enum BakeLength: String, Codable, CaseIterable, Sendable {
    case quick
    case medium
    case long

    public var minutes: Int {
        switch self {
        case .quick: 25
        case .medium: 50
        case .long: 90
        }
    }

    public var breakMinutes: Int {
        switch self {
        case .quick: 5
        case .medium: 8
        case .long: 10
        }
    }
}

/// One dish. A new dish is data plus art; no engine code changes (PRD §9).
/// The session length is the player's choice (`BakeLength`), not the dish's.
public struct Recipe: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let region: String
    public let pack: String
    public let isFree: Bool

    public init(id: String, name: String, region: String, pack: String, isFree: Bool) {
        self.id = id
        self.name = name
        self.region = region
        self.pack = pack
        self.isFree = isFree
    }
}
