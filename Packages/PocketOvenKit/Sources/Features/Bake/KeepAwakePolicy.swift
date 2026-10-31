import Domain

/// When the screen must stay on: only while the bake is running, so face-down and ajar
/// detection keep working (DR-3). Once ready, normal auto-lock returns to save battery; the
/// stored end time and the notification still deliver the result.
enum KeepAwakePolicy {
    static func keepsAwake(_ phase: SessionPhase, setting: Bool = true) -> Bool {
        guard setting else { return false }
        switch phase {
        case .baking, .ajar: return true
        case .idle, .armed, .ready, .graded, .decorating, .served: return false
        }
    }
}
