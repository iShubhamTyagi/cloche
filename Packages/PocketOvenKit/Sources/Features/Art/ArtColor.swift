import SwiftUI

/// sRGB colour that can be blended, for art whose colour follows bake progress.
struct ArtColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    private init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func mixed(with other: ArtColor, _ amount: Double) -> ArtColor {
        let t = min(max(amount, 0), 1)
        return ArtColor(red: red + (other.red - red) * t, green: green + (other.green - green) * t, blue: blue + (other.blue - blue) * t)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
