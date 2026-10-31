@testable import DesignSystem
import Testing

struct TypographyTests {
    @Test func bundledFontsRegister() {
        #expect(FontRegistrar.availability == .init(sans: true, serif: true))
    }

    @Test func trackingIsEmTimesSize() {
        #expect(abs(TextStyle.eyebrow.tracking - 1.54) < 0.0001)
        #expect(abs(TextStyle.hero.tracking - -1.52) < 0.0001)
    }

    @Test func numeralsAndHeroLinesDoNotScale() {
        #expect(!TextStyle.hero.scalesWithDynamicType)
        #expect(!TextStyle.numeral(88).scalesWithDynamicType)
        #expect(TextStyle.numeral(88).usesTabularDigits)
        #expect(TextStyle.body.scalesWithDynamicType)
        #expect(TextStyle.button.scalesWithDynamicType)
    }

    @Test func lineSpacingReachesDesignLineHeight() {
        // Body is 15/22: 15 × 1.2 = 18 natural, so 4 pt is added.
        #expect(abs(TextStyle.body.lineSpacing - 4) < 0.0001)
        #expect(TextStyle.eyebrow.lineSpacing == 0)
    }

    @Test func nothingIsSmallerThanElevenPoints() {
        let styles: [TextStyle] = [.eyebrow, .body, .note, .button, .control, .hero, .title, .name]
        #expect(styles.allSatisfy { $0.size >= 11 })
    }
}
