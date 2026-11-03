import Decorating
import Domain
import Foundation

/// Keeps the cake being decorated on disk, so leaving the app mid-break and coming back finds it
/// as it was, and keeps every served cake (the recipe book reads these later). Ops only, never
/// pixels. Files live in Application Support/Decorating.
struct DecorDraftStore: Sendable {
    let directory: URL

    static let standard = DecorDraftStore(directory: URL.applicationSupportDirectory.appending(path: "Decorating", directoryHint: .isDirectory))

    /// One draft per bake: its recipe and start time.
    static func key(for outcome: BakeOutcome) -> String {
        let start = Int(outcome.bake.startedAt?.timeIntervalSince1970 ?? 0)
        return "\(outcome.bake.recipeID)-\(start)"
    }

    private var draftURL: URL { directory.appending(path: "draft.json") }
    private var servedDirectory: URL { directory.appending(path: "Served", directoryHint: .isDirectory) }

    private struct Draft: Codable {
        let key: String
        let document: DecorDocument
    }

    func loadDraft(key: String) -> DecorDocument? {
        guard let data = try? Data(contentsOf: draftURL), let draft = try? JSONDecoder().decode(Draft.self, from: data),
              draft.key == key else { return nil }
        return draft.document
    }

    func saveDraft(_ document: DecorDocument, key: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(Draft(key: key, document: document)) {
            try? data.write(to: draftURL, options: .atomic)
        }
    }

    /// The draft becomes a served cake: kept under its key, and the latest one is what the
    /// served screen shows.
    @discardableResult
    func serve(key: String) -> DecorDocument? {
        guard let document = loadDraft(key: key) else { return nil }
        try? FileManager.default.createDirectory(at: servedDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(document) {
            try? data.write(to: servedDirectory.appending(path: "\(key).json"), options: .atomic)
        }
        return document
    }

    func served(key: String) -> DecorDocument? {
        guard let data = try? Data(contentsOf: servedDirectory.appending(path: "\(key).json")) else { return nil }
        return try? JSONDecoder().decode(DecorDocument.self, from: data)
    }
}
