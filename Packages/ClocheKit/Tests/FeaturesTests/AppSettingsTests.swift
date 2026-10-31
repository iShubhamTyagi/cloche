import DoorSensing
@testable import Features
import Foundation
import Testing

@MainActor
struct AppSettingsTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "settings-test-\(UUID().uuidString)")!
    }

    @Test func defaultsMatchThePRD() {
        let settings = AppSettings(defaults: freshDefaults())
        #expect(settings.keepsScreenAwake)
        #expect(settings.soundsOn)
        #expect(settings.doorMode == .automatic)
        #expect(!settings.hasAskedForNotifications)
    }

    @Test func changesPersistAcrossLaunches() {
        let defaults = freshDefaults()
        let first = AppSettings(defaults: defaults)
        first.keepsScreenAwake = false
        first.soundsOn = false
        first.doorMode = .faceDown
        first.hasAskedForNotifications = true

        let second = AppSettings(defaults: defaults)
        #expect(!second.keepsScreenAwake)
        #expect(!second.soundsOn)
        #expect(second.doorMode == .faceDown)
        #expect(second.hasAskedForNotifications)
    }
}
