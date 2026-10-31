import Domain
@testable import Features
import Testing

struct GradeCopyTests {
    private func grade(doneness: Double, browning: Browning, stars: Int = 3) -> Grade {
        Grade(doneness: doneness, browning: browning, bakeStar: stars >= 2, temperatureStar: stars >= 3, serveStar: stars >= 1)
    }

    @Test func percentIsRoundedAndClamped() {
        #expect(GradeCopy(grade: grade(doneness: 0.62, browning: .pale)).donenessPercent == 62)
        #expect(GradeCopy(grade: grade(doneness: 0.624, browning: .pale)).donenessPercent == 62)
        #expect(GradeCopy(grade: grade(doneness: 1, browning: .golden)).donenessPercent == 100)
        #expect(GradeCopy(grade: grade(doneness: 1.4, browning: .golden)).donenessPercent == 100)
    }

    @Test func browningMarkerRunsPaleToDark() {
        #expect(GradeCopy.browningPosition(.pale) < GradeCopy.browningPosition(.golden))
        #expect(GradeCopy.browningPosition(.golden) < GradeCopy.browningPosition(.dark))
        #expect(GradeCopy.browningPosition(.golden) == 0.5)
    }
}
