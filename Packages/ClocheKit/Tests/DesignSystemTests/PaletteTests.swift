@testable import DesignSystem
import Testing

struct PaletteTests {
    @Test func hexSplitsIntoSRGBComponents() {
        let ground = HexColor(0x0E0E0D)
        #expect(ground.red == 14.0 / 255)
        #expect(ground.green == 14.0 / 255)
        #expect(ground.blue == 13.0 / 255)
    }

    @Test func extremesMapToZeroAndOne() {
        #expect(HexColor(0x000000) == HexColor(0x000000))
        #expect(HexColor(0xFFFFFF).red == 1)
        #expect(HexColor(0x000000).blue == 0)
    }
}
