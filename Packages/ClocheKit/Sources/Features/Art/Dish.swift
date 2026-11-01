import DesignSystem
import Domain
import SwiftUI

/// Which art a recipe draws with. Placeholder 2D art until the 3D assets land; screens only
/// ever ask for a `DishView`, so swapping the art does not touch them.
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

/// What sits on the oven rack: a row of cupcakes, or one cake sized to its length.
struct RackDishView: View {
    let dish: Dish
    var progress: Double = 1
    var browning: Browning = .golden

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            HStack(alignment: .bottom, spacing: w * 0.02) {
                switch dish {
                case .cupcakes:
                    ForEach(0..<3, id: \.self) { _ in
                        CupcakeView(progress: progress, browning: browning)
                            .frame(width: min(w * 0.26, h), height: min(w * 0.26, h))
                    }
                case .smallCake:
                    CakeView(tiers: 1, progress: progress, browning: browning)
                        .frame(width: min(w * 0.42, h * 1.1), height: min(w * 0.42, h * 1.1))
                case .largeCake:
                    CakeView(tiers: 2, progress: progress, browning: browning)
                        .frame(width: min(w * 0.6, h * 1.2), height: min(w * 0.6, h * 1.2))
                }
            }
            .frame(width: w, height: h, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
