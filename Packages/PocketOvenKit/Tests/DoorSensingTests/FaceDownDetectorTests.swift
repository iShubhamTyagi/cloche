import Domain
import DoorSensing
import Testing

struct FaceDownDetectorTests {
    @Test func closesOnlyAfterLyingFlatAndFaceDownForTheSettleTime() {
        var detector = FaceDownDetector()
        #expect(detector.update(gravityZ: 0.99, at: 0) == .open)
        #expect(detector.update(gravityZ: 0.99, at: 0.5) == .open)
        #expect(detector.update(gravityZ: 0.99, at: 0.8) == .closed)
    }

    @Test func aTiltedSurfaceNeverCloses() {
        var detector = FaceDownDetector()
        // About 30° from flat: cos(30°) ≈ 0.87.
        for second in 0..<10 {
            #expect(detector.update(gravityZ: 0.87, at: Double(second)) == .open)
        }
    }

    @Test func aBriefWobbleRestartsTheSettleTimer() {
        var detector = FaceDownDetector()
        _ = detector.update(gravityZ: 0.99, at: 0)
        _ = detector.update(gravityZ: 0.50, at: 0.5)
        _ = detector.update(gravityZ: 0.99, at: 0.6)
        #expect(detector.update(gravityZ: 0.99, at: 1.0) == .open)
        #expect(detector.update(gravityZ: 0.99, at: 1.5) == .closed)
    }

    @Test func smallMovementsWhileClosedDoNotOpenTheDoor() {
        var detector = FaceDownDetector()
        _ = detector.update(gravityZ: 0.99, at: 0)
        _ = detector.update(gravityZ: 0.99, at: 1)
        // Between the close and open thresholds: stays shut.
        #expect(detector.update(gravityZ: 0.85, at: 2) == .closed)
    }

    @Test func flippingUpOpensImmediately() {
        var detector = FaceDownDetector()
        _ = detector.update(gravityZ: 0.99, at: 0)
        _ = detector.update(gravityZ: 0.99, at: 1)
        #expect(detector.update(gravityZ: -0.95, at: 1.1) == .open)
    }
}

struct HingeReadingTests {
    @Test(arguments: [
        (HingeReading.Status.closed, DoorState.closed),
        (.partiallyOpen, .ajar),
        (.fullyOpen, .open),
        (.unknown, .open),
    ])
    func hingeStatusMapsToDoorState(status: HingeReading.Status, expected: DoorState) {
        #expect(HingeReading(status: status, angle: 0).doorState == expected)
    }
}

struct DoorModeResolverTests {
    @Test func automaticUsesTheHingeWhenPresent() {
        #expect(DoorModeResolver.source(hingePresent: true, preference: .automatic) == .hinge)
        #expect(DoorModeResolver.source(hingePresent: false, preference: .automatic) == .faceDown)
    }

    @Test func duoOwnersCanChooseFaceDown() {
        #expect(DoorModeResolver.source(hingePresent: true, preference: .faceDown) == .faceDown)
    }
}
