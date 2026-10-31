import Foundation

public enum Temperature: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var heat: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }
}

/// One dish. A new dish is data plus art; no engine code changes (PRD §9).
public struct Recipe: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let region: String
    public let pack: String
    public let bakeMinutes: Int
    public let idealTemperature: Temperature
    public let isFree: Bool

    public init(id: String, name: String, region: String, pack: String, bakeMinutes: Int, idealTemperature: Temperature, isFree: Bool) {
        self.id = id
        self.name = name
        self.region = region
        self.pack = pack
        self.bakeMinutes = bakeMinutes
        self.idealTemperature = idealTemperature
        self.isFree = isFree
    }

    /// Break length that follows the bake: 5, 8 or 10 minutes after 25, 50 or 90 (PRD §8).
    public var breakMinutes: Int {
        switch bakeMinutes {
        case ...25: 5
        case ...50: 8
        default: 10
        }
    }
}
