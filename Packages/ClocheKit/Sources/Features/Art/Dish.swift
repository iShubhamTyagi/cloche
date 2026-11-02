import DesignSystem
import Domain
import SwiftUI

/// Which dish a recipe makes. `DishView` draws it (2D until the baked-dish renders land) on the
/// grade card and the plating station; the oven itself is rendered (`RenderedOven`).
enum Dish: Equatable, Sendable {
    case cupcakes
    case smallCake
    case largeCake

    init(recipeID: String) {
        switch recipeID {
        case StarterRecipes.smallCake.id: self = .smallCake
        case StarterRecipes.largeCake.id: self = .largeCake
        default: self = .cupcakes
        }
    }
}

/// One serving of a dish: a single cupcake or a whole cake, optionally on a plate.
struct DishView: View {
    let dish: Dish
    var progress: Double = 1
    var browning: Browning = .golden
    var icing: FoodPalette.Icing?
    var showsPlate = false

    var body: some View {
        switch dish {
        case .cupcakes:
            CupcakeView(progress: progress, browning: browning, icing: icing, showsPlate: showsPlate)
        case .smallCake:
            CakeView(tiers: 1, progress: progress, browning: browning, icing: icing, showsPlate: showsPlate)
        case .largeCake:
            CakeView(tiers: 2, progress: progress, browning: browning, icing: icing, showsPlate: showsPlate)
        }
    }
}
