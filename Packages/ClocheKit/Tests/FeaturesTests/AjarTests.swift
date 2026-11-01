import Domain
@testable import Features
import Foundation
import Testing

struct DoorGeometryTests {
    @Test func flatPhoneLeavesTheDoorFlat() {
        #expect(DoorGeometry.liftDegrees(hingeAngle: .pi) == 0)
    }

    @Test func shutPhoneLiftsTheDoorAllTheWay() {
        #expect(DoorGeometry.liftDegrees(hingeAngle: 0) == 180)
    }

    @Test func halfOpenIsNinetyDegrees() {
        #expect(abs(DoorGeometry.liftDegrees(hingeAngle: .pi / 2) - 90) < 0.0001)
    }

    @Test func outOfRangeReadingsAreClamped() {
        #expect(DoorGeometry.liftDegrees(hingeAngle: 4) == 0)
        #expect(DoorGeometry.liftDegrees(hingeAngle: -1) == 180)
        #expect(DoorGeometry.liftDegrees(hingeAngle: .nan) == 0)
    }
}

struct BakeProgressTests {
    @Test func progressIsElapsedOverDuration() {
        var engine = SessionEngine()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        _ = engine.handle(.preheat(BakeRequest(recipe: StarterRecipes.vanillaCupcakes, length: .quick, source: .faceDown)), now: start)
        _ = engine.handle(.door(.closed), now: start)
        guard case let .baking(bake) = engine.phase else {
            Issue.record("not baking")
            return
        }
        #expect(bake.progress(at: start.addingTimeInterval(750)) == 0.5)
        #expect(bake.progress(at: start.addingTimeInterval(-10)) == 0)
        #expect(bake.progress(at: start.addingTimeInterval(9999)) == 1)
    }
}
