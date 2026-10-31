import Domain

/// The player's door-mode setting (DR-8). Automatic picks the hinge when there is one.
public enum DoorModePreference: String, Codable, CaseIterable, Sendable {
    case automatic
    case faceDown
}

/// DR-1: hinge if present, otherwise face-down; a Duo owner can still choose face-down.
public enum DoorModeResolver {
    public static func source(hingePresent: Bool, preference: DoorModePreference) -> DoorSource {
        switch preference {
        case .faceDown: .faceDown
        case .automatic: hingePresent ? .hinge : .faceDown
        }
    }
}
