import SwiftUI

/// Words for the tray (drawn by the app, never baked into art).
enum DecorCopy {
    static func short(_ name: String) -> LocalizedStringKey {
        switch name {
        case "ivory": "Ivory"
        case "rose": "Rose"
        case "pistachio": "Pistachio"
        case "chocolate": "Chocolate"
        case "berries": "Berries"
        case "mint": "Mint"
        case "sprinkles": "Sprinkles"
        default: "Gold"
        }
    }

    static func step(_ step: DecorStep) -> LocalizedStringKey {
        switch step {
        case .cream: "Cream"
        case .pipe: "Pipe"
        case .top: "Top"
        }
    }

    static func hint(_ step: DecorStep) -> LocalizedStringKey {
        switch step {
        case .cream: "Rub the cream on with the spatula"
        case .pipe: "Drag around a ring on the cake"
        case .top: "Choose a bowl"
        }
    }
}
