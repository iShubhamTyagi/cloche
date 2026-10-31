/// The one question the bake asks: is the oven door shut?
public enum DoorState: String, Sendable, Equatable, Codable {
    case closed
    /// Partly open: a half-folded Duo, or a phone lifted off its face. Starts the 15 s grace.
    case ajar
    case open
}

/// Which input closed the door. Tagged on every analytics event (DR-7).
public enum DoorSource: String, Sendable, Codable, CaseIterable {
    case hinge
    case faceDown
    case covered
    case honor
}
