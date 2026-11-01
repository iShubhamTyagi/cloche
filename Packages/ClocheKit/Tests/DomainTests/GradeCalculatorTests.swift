@testable import Domain
import Foundation
import Testing

struct GradeCalculatorTests {
    private func outcome(doneness: Double, length: BakeLength = .quick, demo: Bool = false) -> BakeOutcome {
        let bake = Bake(BakeRequest(recipe: .cupcakes, length: length, source: .faceDown, isDemo: demo))
        return BakeOutcome(bake: bake, doneness: doneness)
    }

    @Test func fullBakeServedEarnsBothStarsAndIsGolden() {
        let grade = GradeCalculator.grade(outcome(doneness: 1), served: true)
        #expect(grade.stars == Grade.maxStars)
        #expect(grade.stars == 2)
        #expect(grade.browning == .golden)
    }

    @Test func fullBakeServedPlainKeepsTheBakeStar() {
        let grade = GradeCalculator.grade(outcome(doneness: 1), served: false)
        #expect(grade.bakeStar)
        #expect(!grade.serveStar)
        #expect(grade.stars == 1)
    }

    @Test(arguments: BakeLength.allCases)
    func everyLengthGradesTheSame(length: BakeLength) {
        #expect(GradeCalculator.grade(outcome(doneness: 1, length: length), served: true).stars == 2)
    }

    @Test func halfBakedIsCappedAtOneStarAndPale() {
        let grade = GradeCalculator.grade(outcome(doneness: 0.62), served: true)
        #expect(grade.stars == 1)
        #expect(grade.isHalfBaked)
        #expect(grade.browning == .pale)
    }

    @Test func demoBakesNeverEarnStars() {
        #expect(GradeCalculator.grade(outcome(doneness: 1, demo: true), served: true).stars == 0)
    }

    @Test(arguments: [(BakeLength.quick, 25, 5), (.medium, 50, 8), (.long, 90, 10)])
    func lengthSetsBakeAndBreak(length: BakeLength, bakeMinutes: Int, breakMinutes: Int) {
        #expect(length.minutes == bakeMinutes)
        #expect(length.breakMinutes == breakMinutes)
        let bake = Bake(BakeRequest(recipe: .cupcakes, length: length, source: .faceDown))
        #expect(bake.duration == TimeInterval(bakeMinutes * 60))
        #expect(bake.breakDuration == TimeInterval(breakMinutes * 60))
    }
}
