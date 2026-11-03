import SwiftUI

/// Labels for the station's seats, tools and controls (drawn by the app, never baked into art).
enum DecorCopy {
    static func label(_ name: String) -> LocalizedStringKey {
        switch name {
        case "ivory": "Ivory buttercream"
        case "rose": "Rose buttercream"
        case "pistachio": "Pistachio buttercream"
        case "chocolate": "Chocolate buttercream"
        case "caramel": "Caramel buttercream"
        case "white": "White buttercream"
        case "raspberry": "Raspberry buttercream"
        case "bluegrey": "Blue-grey buttercream"
        case "ganache_dark": "Dark ganache"
        case "ganache_milk": "Milk ganache"
        case "ganache_white": "White ganache"
        case "ganache_caramel": "Caramel ganache"
        case "NozzleRound": "Round tip"
        case "NozzleStar": "Star tip"
        case "NozzlePetal": "Petal tip"
        case "PipingCone": "Piping bag"
        case "OffsetSpatula": "Offset spatula"
        case "PourPan": "Pour"
        case "DrizzleBottle": "Drizzle"
        case "Sieve": "Dust"
        case "berries": "Berries"
        case "mint": "Mint"
        case "chocolate_shavings": "Chocolate shavings"
        case "gold_flakes": "Gold flakes"
        case "sprinkles": "Sprinkles"
        case "sugar_pearls": "Sugar pearls"
        case "crushed_pistachio": "Crushed pistachio"
        case "flower_petals": "Flower petals"
        case "undo": "Undo"
        case "clear": "Clear"
        case "turntable": "Turn"
        case "speed": "Speed"
        case "plate": "Plate"
        case "backdrop": "Backdrop"
        case "topping": "Toppings"
        default: "Decorating"
        }
    }
}
