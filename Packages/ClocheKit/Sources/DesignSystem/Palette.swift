import SwiftUI

/// Colour tokens from the design handoff. The interface has no hue: ivory on near-black.
/// Food colours are the only saturated colours, plus `honey` for the last 30 seconds.
/// The decorating screens are the exception: warm espresso panels with brass accents.
public enum Palette {
    public static let ground = Color(hex: 0x0E0E0D)
    public static let surface = Color(hex: 0x1A1917)
    public static let text = Color(hex: 0xF6F1E7)
    public static let muted = Color(hex: 0xAEA89B)
    public static let subtle = Color(hex: 0x8C877C)
    public static let accent = Color(hex: 0xF2E6CD)
    public static let sand = Color(hex: 0xCDB58A)
    public static let honey = Color(hex: 0xE3C07D)
    /// Pure black for the face-down bake screen (OLED off).
    public static let black = Color(hex: 0x000000)

    /// Decorating panels (owner's realism brief, 2026-11-06).
    public static let espresso = Color(hex: 0x21160F)
    public static let brass = Color(hex: 0xBE9A5F)
    public static let brassLine = Color(hex: 0xBE9A5F).opacity(0.4)

    public static let line1 = Color(hex: 0xF6F1E7).opacity(0.12)
    public static let line2 = Color(hex: 0xF6F1E7).opacity(0.16)
    public static let line3 = Color(hex: 0xF6F1E7).opacity(0.24)

    /// Ink for captions laid over the light backdrops.
    public static let captionInk = Color(hex: 0x2A2623)
}

/// sRGB components of a 24-bit hex colour.
struct HexColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

extension Color {
    init(hex: UInt32) {
        let rgb = HexColor(hex)
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}
