import Domain
import Foundation
import Persistence
import Testing

struct FileSessionSnapshotStoreTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func emptyStoreLoadsNothing() throws {
        let store = FileSessionSnapshotStore(directory: try temporaryDirectory())
        #expect(try store.load() == nil)
    }

    @Test func savedSessionLoadsBackIdentically() throws {
        let directory = try temporaryDirectory()
        var engine = SessionEngine()
        let recipe = Recipe(id: "cupcake", name: "Vanilla cupcakes", region: "Universal", pack: "core", isFree: true)
        _ = engine.handle(.preheat(BakeRequest(recipe: recipe, length: .quick, source: .hinge)), now: Date(timeIntervalSinceReferenceDate: 0))
        _ = engine.handle(.door(.closed), now: Date(timeIntervalSinceReferenceDate: 5))

        try FileSessionSnapshotStore(directory: directory).save(engine)
        // A new store instance, as after a force-quit.
        let restored = try FileSessionSnapshotStore(directory: directory).load()

        #expect(restored == engine)
    }
}
