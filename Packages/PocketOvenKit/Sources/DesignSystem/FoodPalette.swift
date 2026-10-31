import SwiftUI

/// Food colours from the design handoff. These are the only saturated colours in the app and
/// appear on dishes, never on interface chrome.
public enum FoodPalette {
    public enum Icing: String, CaseIterable, Sendable {
        case rose, pistachio, lilac, butter, sky, cocoa

        public var color: Color {
            switch self {
            case .rose: Color(hex: 0xF3B7AE)
            case .pistachio: Color(hex: 0xBFD9A0)
            case .lilac: Color(hex: 0xCDB4EA)
            case .butter: Color(hex: 0xF4E3A1)
            case .sky: Color(hex: 0xA9CDEB)
            // Cocoa needs a 1 pt line-2 border on dark surfaces.
            case .cocoa: Color(hex: 0x6B4330)
            }
        }
    }

    public static let sprinkles: [Color] = [
        Color(hex: 0xF29AB5), Color(hex: 0x8FD0C4), Color(hex: 0xF4D77A), Color(hex: 0xA9B7F0), Color(hex: 0xFFFFFF),
    ]

    /// Browning bar gradient stops.
    public static let bakePale = Color(hex: 0xE4C98F)
    public static let bakeGolden = Color(hex: 0xCC8A3E)
    public static let bakeDark = Color(hex: 0x5E3115)
}
