import Domain
import Services
import Testing

@MainActor
final class RecordingHaptics: HapticPlaying {
    private(set) var played: [Haptic] = []
    func play(_ haptic: Haptic) { played.append(haptic) }
}

@MainActor
final class RecordingAnnouncer: Announcing {
    private(set) var messages: [String] = []
    func announce(_ message: String) { messages.append(message) }
}

struct FeedbackPlanTests {
    @Test func bakeStartLatchesAndIsAnnounced() {
        let plan = FeedbackPlan.plan(for: .bakeStarted)
        #expect(plan.haptic == .doorLatch)
        #expect(plan.announcement == "Bake started")
    }

    @Test func revealThunksWithoutSpeakingOverTheScreen() {
        #expect(FeedbackPlan.plan(for: .doorOpened) == FeedbackPlan(haptic: .doorThunk, announcement: nil))
    }

    @Test func doorAjarAnnouncesTheGrace() {
        #expect(FeedbackPlan.plan(for: .doorAjar).announcement == "Door ajar, 15 seconds")
    }

    @Test func servingAnnouncesTheStars() {
        let plan = FeedbackPlan.plan(for: .served(stars: 3))
        #expect(plan.haptic == .softThud)
        #expect(plan.announcement == "Served. 3 of 3 stars")
    }
}

@MainActor
struct SessionEffectRouterTests {
    @Test func cuesBecomeHapticsAndAnnouncements() {
        let haptics = RecordingHaptics()
        let announcer = RecordingAnnouncer()
        let router = SessionEffectRouter(haptics: haptics, announcer: announcer)

        router.perform([.cue(.bakeStarted), .scheduleNotification(.bakeReady, at: .now), .cue(.doorOpened)])

        #expect(haptics.played == [.doorLatch, .doorThunk])
        #expect(announcer.messages == ["Bake started"])
    }
}
