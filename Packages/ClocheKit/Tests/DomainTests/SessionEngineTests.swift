import Domain
import Foundation
import Testing

struct SessionEngineBakeTests {
    @Test func closingTheDoorStartsTheBakeAndSchedulesTheReadyNotification() {
        var engine = SessionEngine()
        _ = engine.handle(.preheat(BakeRequest(recipe: .cupcakes, length: .quick, source: .faceDown)), now: t0)
        #expect(engine.phase.name == "armed")

        let effects = engine.handle(.door(.closed), now: at(3))

        #expect(engine.phase.name == "baking")
        #expect(effects.contains(.scheduleNotification(.bakeReady, at: at(3 + 1500))))
        #expect(effects.contains(.cue(.bakeStarted)))
        #expect(engine.nextDeadline == at(3 + 1500))
    }

    @Test func cancellingPreheatReturnsToIdle() {
        var engine = SessionEngine()
        _ = engine.handle(.preheat(BakeRequest(recipe: .cupcakes, length: .quick, source: .faceDown)), now: t0)
        _ = engine.handle(.cancelPreheat, now: t0)
        #expect(engine.phase == .idle)
    }

    @Test func finishedBakeKeepsWarmForeverWithNoPenalty() {
        var engine = bakingEngine()
        // Hours past the end, door still closed.
        _ = engine.handle(.tick, now: at(1500 + 6 * 3600))
        #expect(engine.phase.name == "ready")
        #expect(engine.nextDeadline == nil)

        let effects = engine.handle(.door(.open), now: at(1500 + 6 * 3600 + 1))

        #expect(effects.contains(.cue(.doorOpened)))
        #expect(engine.phase.outcome?.doneness == 1)
    }

    @Test func partlyOpeningAReadyOvenDoesNotRevealYet() {
        var engine = bakingEngine()
        _ = engine.handle(.tick, now: at(1500))
        _ = engine.handle(.door(.ajar), now: at(1501))
        #expect(engine.phase.name == "ready")
    }

    @Test func openingAfterTheEndRevealsAFullBakeEvenWithoutATick() {
        var engine = bakingEngine()
        let effects = engine.handle(.door(.open), now: at(1600))
        #expect(engine.phase.outcome?.doneness == 1)
        #expect(effects.contains(.cue(.bakeReady)))
        #expect(effects.contains(.cue(.doorOpened)))
    }
}

struct SessionEngineGraceTests {
    @Test func openingEarlyStartsAFifteenSecondGrace() {
        var engine = bakingEngine()
        let effects = engine.handle(.door(.open), now: at(600))
        #expect(engine.phase == .ajar(bakeOf(engine), openedAt: at(600), graceEndsAt: at(615)))
        #expect(effects == [.cue(.doorAjar)])
        #expect(engine.nextDeadline == at(615))
    }

    @Test func closingWithinTheGraceResumesWithNothingLost() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(600))
        let effects = engine.handle(.door(.closed), now: at(614))

        #expect(engine.phase.name == "baking")
        #expect(effects == [.cue(.bakeResumed)])
        // Same end time as before: the open seconds still counted as baking.
        #expect(engine.nextDeadline == at(1500))
    }

    @Test func leavingTheDoorOpenEndsTheBakeHalfBakedAtTheMomentItOpened() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(930))
        let effects = engine.handle(.tick, now: at(945))

        #expect(engine.phase.name == "graded")
        #expect(engine.phase.outcome?.doneness == 930.0 / 1500.0)
        #expect(effects.contains(.cancelNotification(.bakeReady)))
        #expect(effects.contains(.cue(.bakeEndedEarly)))
    }

    @Test func aDoorLeftAjarCountsAsOpen() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.ajar), now: at(100))
        _ = engine.handle(.tick, now: at(116))
        #expect(engine.phase.outcome?.isFullyBaked == false)
    }

    @Test func timerRunningOutDuringTheGraceCountsAsFullyBaked() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(1495))
        _ = engine.handle(.tick, now: at(1510))
        #expect(engine.phase.outcome?.doneness == 1)
    }

    @Test func relaunchLongAfterAnOpenedDoorStillEndsAtTheOpeningMoment() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(300))
        // App was killed; it comes back an hour later.
        _ = engine.handle(.tick, now: at(3600))
        #expect(engine.phase.outcome?.doneness == 300.0 / 1500.0)
    }

    private func bakeOf(_ engine: SessionEngine) -> Bake {
        if case let .ajar(bake, _, _) = engine.phase { return bake }
        Issue.record("not ajar")
        fatalError()
    }
}

struct SessionEngineBreakTests {
    @Test func decoratingStartsABreakThatFollowsTheBakeLength() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(1500))
        let effects = engine.handle(.decorate, now: at(1510))

        #expect(engine.nextDeadline == at(1510 + 5 * 60))
        #expect(effects == [.scheduleNotification(.breakOver, at: at(1510 + 300))])
    }

    @Test func breakAutoServesWhenTheClockRunsOutEvenIfTheAppWasAway() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(1500))
        _ = engine.handle(.decorate, now: at(1500))
        let effects = engine.handle(.tick, now: at(1500 + 3600))

        #expect(engine.phase.grade?.stars == 2)
        #expect(effects == [.cue(.served(stars: 2))])
    }

    @Test func serveNowEndsTheBreakEarlyAndLosesNothing() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(1500))
        _ = engine.handle(.decorate, now: at(1500))
        let effects = engine.handle(.serveNow, now: at(1520))

        #expect(engine.phase.grade?.stars == 2)
        #expect(effects.contains(.cancelNotification(.breakOver)))
    }

    @Test func servingPlainForfeitsOnlyTheServeStar() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(1500))
        _ = engine.handle(.servePlain, now: at(1501))
        #expect(engine.phase.grade?.stars == 1)
    }

    @Test func decoratingIsUnreachableWithoutABake() {
        var engine = SessionEngine()
        _ = engine.handle(.decorate, now: t0)
        _ = engine.handle(.serveNow, now: t0)
        #expect(engine.phase == .idle)
    }

    @Test func doneReturnsToACalmIdle() {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(1500))
        _ = engine.handle(.servePlain, now: at(1501))
        _ = engine.handle(.done, now: at(1502))
        #expect(engine.phase == .idle)
    }
}

struct SessionEnginePersistenceTests {
    @Test func stateSurvivesEncodingForForceQuitRecovery() throws {
        var engine = bakingEngine()
        _ = engine.handle(.door(.open), now: at(600))

        let data = try JSONEncoder().encode(engine)
        var restored = try JSONDecoder().decode(SessionEngine.self, from: data)

        #expect(restored == engine)
        _ = restored.handle(.door(.closed), now: at(610))
        #expect(restored.nextDeadline == at(1500))
    }

    @Test func demoBakeLastsFifteenSecondsAndEarnsNoStars() {
        var engine = bakingEngine(isDemo: true)
        #expect(engine.nextDeadline == at(15))
        _ = engine.handle(.door(.open), now: at(15))
        _ = engine.handle(.servePlain, now: at(16))
        #expect(engine.phase.grade?.stars == 0)
    }
}
