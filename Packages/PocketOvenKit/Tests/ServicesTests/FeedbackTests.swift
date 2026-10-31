import Domain
import Foundation
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

@MainActor
final class RecordingSounds: SoundPlaying {
    private(set) var played: [Sound] = []
    func play(_ sound: Sound) { played.append(sound) }
}

@MainActor
final class RecordingNotifications: NotificationScheduling {
    private(set) var scheduled: [(SessionNotification, Date)] = []
    private(set) var cancelled: [SessionNotification] = []
    func permission() async -> NotificationPermission { .notDetermined }
    func requestPermission() async -> Bool { true }
    func schedule(_ kind: SessionNotification, at date: Date) { scheduled.append((kind, date)) }
    func cancel(_ kind: SessionNotification) { cancelled.append(kind) }
}

struct FeedbackPlanTests {
    @Test func bakeStartLatchesAndIsAnnounced() {
        let plan = FeedbackPlan.plan(for: .bakeStarted)
        #expect(plan.haptic == .doorLatch)
        #expect(plan.announcement == "Bake started")
        #expect(plan.sound == nil)
    }

    @Test func revealThunksWithoutSpeakingOverTheScreen() {
        #expect(FeedbackPlan.plan(for: .doorOpened) == FeedbackPlan(haptic: .doorThunk, announcement: nil))
    }

    @Test func doorAjarAnnouncesTheGrace() {
        #expect(FeedbackPlan.plan(for: .doorAjar).announcement == "Door ajar, 15 seconds")
    }

    @Test func bakeReadyChimes() {
        #expect(FeedbackPlan.plan(for: .bakeReady).sound == .readyChime)
    }

    @Test func servingAnnouncesTheStars() {
        let plan = FeedbackPlan.plan(for: .served(stars: 3))
        #expect(plan.haptic == .softThud)
        #expect(plan.announcement == "Served. 3 of 3 stars")
    }
}

struct NotificationContentTests {
    @Test func readyNotificationNeverMentionsWhatThePlayerIsWorkingOn() {
        let content = NotificationContent.content(for: .bakeReady)
        #expect(content.title == "Your bake is ready")
        #expect(content.body.contains("keeps warm"))
    }
}

@MainActor
struct SessionEffectRouterTests {
    private func router(soundsOn: Bool = true) -> (SessionEffectRouter, RecordingHaptics, RecordingAnnouncer, RecordingSounds, RecordingNotifications) {
        let haptics = RecordingHaptics()
        let announcer = RecordingAnnouncer()
        let sounds = RecordingSounds()
        let notifications = RecordingNotifications()
        let router = SessionEffectRouter(haptics: haptics, announcer: announcer, sounds: sounds, notifications: notifications, soundsEnabled: { soundsOn })
        return (router, haptics, announcer, sounds, notifications)
    }

    @Test func cuesBecomeHapticsAnnouncementsAndSounds() {
        let (router, haptics, announcer, sounds, _) = router()
        router.perform([.cue(.bakeStarted), .cue(.bakeReady), .cue(.doorOpened)])

        #expect(haptics.played == [.doorLatch, .doorThunk])
        #expect(announcer.messages == ["Bake started", "Bake ready"])
        #expect(sounds.played == [.readyChime])
    }

    @Test func notificationsAreScheduledAndCancelled() {
        let (router, _, _, _, notifications) = router()
        let date = Date(timeIntervalSinceNow: 1500)
        router.perform([.scheduleNotification(.bakeReady, at: date), .cancelNotification(.bakeReady)])

        #expect(notifications.scheduled.map(\.0) == [.bakeReady])
        #expect(notifications.scheduled.first?.1 == date)
        #expect(notifications.cancelled == [.bakeReady])
    }

    @Test func soundsOffSilencesTheChimeButKeepsHapticsAndSpeech() {
        let (router, _, announcer, sounds, _) = router(soundsOn: false)
        router.perform([.cue(.bakeReady)])
        #expect(sounds.played.isEmpty)
        #expect(announcer.messages == ["Bake ready"])
    }
}
