import Domain
@testable import Features
import Foundation
import Testing

struct KeepAwakePolicyTests {
    private let bake = Bake(BakeRequest(recipe: StarterRecipes.vanillaCupcakes, length: .quick, source: .faceDown))
    private let now = Date(timeIntervalSinceReferenceDate: 0)

    @Test func screenStaysOnOnlyWhileTheBakeRuns() {
        #expect(KeepAwakePolicy.keepsAwake(.baking(bake)))
        #expect(KeepAwakePolicy.keepsAwake(.ajar(bake, openedAt: now, graceEndsAt: now)))
        #expect(!KeepAwakePolicy.keepsAwake(.idle))
        #expect(!KeepAwakePolicy.keepsAwake(.armed(bake)))
        #expect(!KeepAwakePolicy.keepsAwake(.ready(bake)))
    }

    @Test func turningTheSettingOffLetsTheScreenSleep() {
        #expect(!KeepAwakePolicy.keepsAwake(.baking(bake), setting: false))
    }
}
