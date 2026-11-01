import Domain
import Foundation

extension Recipe {
    static let cupcakes = Recipe(id: "cupcake", name: "Vanilla cupcakes", region: "Universal", pack: "core", isFree: true)
    static let cake = Recipe(id: "cake", name: "Chocolate drip cake", region: "Celebration", pack: "core", isFree: false)
    static let biryani = Recipe(id: "biryani", name: "Dum biryani", region: "North Indian", pack: "core", isFree: false)
}

let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

func at(_ seconds: TimeInterval) -> Date {
    t0.addingTimeInterval(seconds)
}

/// An engine already baking cupcakes for `length`, door closed at t0.
func bakingEngine(length: BakeLength = .quick, isDemo: Bool = false) -> SessionEngine {
    var engine = SessionEngine()
    _ = engine.handle(.preheat(BakeRequest(recipe: .cupcakes, length: length, source: .faceDown, isDemo: isDemo)), now: t0)
    _ = engine.handle(.door(.closed), now: t0)
    return engine
}

extension SessionPhase {
    var name: String {
        switch self {
        case .idle: "idle"
        case .armed: "armed"
        case .baking: "baking"
        case .ajar: "ajar"
        case .ready: "ready"
        case .graded: "graded"
        case .decorating: "decorating"
        case .served: "served"
        }
    }

    var outcome: BakeOutcome? {
        switch self {
        case let .graded(outcome), let .decorating(outcome, _), let .served(outcome, _): outcome
        default: nil
        }
    }

    var grade: Grade? {
        if case let .served(_, grade) = self { grade } else { nil }
    }
}
