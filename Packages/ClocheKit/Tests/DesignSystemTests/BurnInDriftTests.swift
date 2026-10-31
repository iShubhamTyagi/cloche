import DesignSystem
import Foundation
import Testing

struct BurnInDriftTests {
    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    @Test func staysWithinTheRange() {
        for second in stride(from: 0.0, to: 180, by: 0.5) {
            let offset = BurnInDrift.offset(at: date(second), period: 90, range: 16)
            #expect(offset >= -8 && offset <= 8)
        }
    }

    @Test func reachesBothEndsOnceEachPeriod() {
        #expect(BurnInDrift.offset(at: date(0), period: 90, range: 16) == -8)
        #expect(BurnInDrift.offset(at: date(45), period: 90, range: 16) == 8)
        #expect(BurnInDrift.offset(at: date(90), period: 90, range: 16) == -8)
    }

    @Test func movesInWholeSteps() {
        for second in stride(from: 0.0, to: 90, by: 1.3) {
            let offset = BurnInDrift.offset(at: date(second), period: 90, range: 16, step: 2)
            #expect(offset.truncatingRemainder(dividingBy: 2) == 0)
        }
    }

    @Test func invalidInputsDoNotMove() {
        #expect(BurnInDrift.offset(at: date(10), period: 0, range: 16) == 0)
        #expect(BurnInDrift.offset(at: date(10), period: 90, range: 0) == 0)
    }
}
