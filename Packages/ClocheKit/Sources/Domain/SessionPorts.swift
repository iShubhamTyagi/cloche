import Foundation

/// Saves the session so a bake survives sleep, calls and force-quit (BK-1).
public protocol SessionSnapshotStoring: Sendable {
    func load() throws -> SessionEngine?
    func save(_ engine: SessionEngine) throws
}

/// Carries out what the engine asks for: notifications, sounds, haptics, announcements.
@MainActor
public protocol SessionEffectPerforming: AnyObject {
    func perform(_ effects: [SessionEffect])
}
