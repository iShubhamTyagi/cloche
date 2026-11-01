import Domain
@testable import Features
import Testing

struct GradeCopyTests {
    private func grade(doneness: Double, browning: Browning, stars: Int = 2) -> Grade {
        Grade(doneness: doneness, browning: browning, bakeStar: stars >= 2, serveStar: stars >= 1)
    }

    @Test func percentIsRoundedAndClamped() {
        #expect(GradeCopy(grade: grade(doneness: 0.62, browning: .pale)).donenessPercent == 62)
        #expect(GradeCopy(grade: grade(doneness: 0.624, browning: .pale)).donenessPercent == 62)
        #expect(GradeCopy(grade: grade(doneness: 1, browning: .golden)).donenessPercent == 100)
        #expect(GradeCopy(grade: grade(doneness: 1.4, browning: .golden)).donenessPercent == 100)
    }
}
