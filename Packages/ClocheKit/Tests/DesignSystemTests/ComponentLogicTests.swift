@testable import DesignSystem
import Testing

struct CountdownFormatTests {
    @Test(arguments: [
        (252.0, "4:12"),
        (251.2, "4:12"),
        (5.0, "0:05"),
        (0.0, "0:00"),
        (-3.0, "0:00"),
        (1500.0, "25:00"),
        (5400.0, "90:00"),
    ])
    func formatsMinutesAndSecondsRoundingUp(remaining: Double, expected: String) {
        #expect(CountdownFormat.clock(remaining) == expected)
    }

    @Test func shortCountdownsShowBareSeconds() {
        #expect(CountdownFormat.seconds(15) == "15")
        #expect(CountdownFormat.seconds(10.2) == "11")
        #expect(CountdownFormat.seconds(-1) == "0")
    }

    @Test func nonFiniteTimeReadsZero() {
        #expect(CountdownFormat.clock(.infinity) == "0:00")
        #expect(CountdownFormat.clock(.nan) == "0:00")
    }
}

struct RingClockTests {
    @Test func fractionIsTimeLeftOverTotal() {
        #expect(RingClock.fraction(remaining: 150, total: 300) == 0.5)
    }

    @Test func fractionIsClampedAndSafe() {
        #expect(RingClock.fraction(remaining: 400, total: 300) == 1)
        #expect(RingClock.fraction(remaining: -1, total: 300) == 0)
        #expect(RingClock.fraction(remaining: 10, total: 0) == 0)
    }
}

struct StarsTests {
    @Test func earnedCountIsClampedToZeroThroughThree() {
        #expect(Stars.clamped(-1) == 0)
        #expect(Stars.clamped(2) == 2)
        #expect(Stars.clamped(5) == 3)
    }
}
