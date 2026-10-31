import Domain
import Foundation
import os

/// Stores the session as JSON in Application Support. A file (rather than UserDefaults)
/// keeps the privacy manifest free of extra required-reason APIs.
public struct FileSessionSnapshotStore: SessionSnapshotStoring {
    private let url: URL

    public init(directory: URL) {
        url = directory.appendingPathComponent("session.json")
    }

    /// `Application Support/Cloche/session.json`.
    public static func standard() throws -> FileSessionSnapshotStore {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("Cloche", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileSessionSnapshotStore(directory: directory)
    }

    public func load() throws -> SessionEngine? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(SessionEngine.self, from: Data(contentsOf: url))
    }

    public func save(_ engine: SessionEngine) throws {
        try JSONEncoder().encode(engine).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// For previews and tests.
public final class InMemorySessionSnapshotStore: SessionSnapshotStoring, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<SessionEngine?>(initialState: nil)

    public init(_ engine: SessionEngine? = nil) {
        lock.withLock { $0 = engine }
    }

    public func load() throws -> SessionEngine? {
        lock.withLock { $0 }
    }

    public func save(_ engine: SessionEngine) throws {
        lock.withLock { $0 = engine }
    }
}
