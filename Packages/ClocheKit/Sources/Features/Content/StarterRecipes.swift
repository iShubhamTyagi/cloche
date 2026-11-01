import Domain

/// The starter dishes, one per bake length: Quick bakes cupcakes, Medium a small cake and Long
/// a large one. Replaced by bundled `Recipes.json` in slice 2.1.
enum StarterRecipes {
    static let vanillaCupcakes = Recipe(id: "cupcake", name: "Vanilla cupcakes", region: "Universal classic", pack: "core", isFree: true)
    static let smallCake = Recipe(id: "sponge-cake", name: "Vanilla sponge", region: "Universal classic", pack: "core", isFree: true)
    static let largeCake = Recipe(id: "celebration-cake", name: "Celebration cake", region: "Universal classic", pack: "core", isFree: true)

    static let all = [vanillaCupcakes, smallCake, largeCake]

    static func recipe(id: String) -> Recipe {
        all.first { $0.id == id } ?? vanillaCupcakes
    }

    static func recipe(for length: BakeLength) -> Recipe {
        switch length {
        case .quick: vanillaCupcakes
        case .medium: smallCake
        case .long: largeCake
        }
    }
}
