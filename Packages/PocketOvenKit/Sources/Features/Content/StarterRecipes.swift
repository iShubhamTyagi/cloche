import Domain

/// Gate 0 ships one hard-coded dish. Replaced by bundled `Recipes.json` in slice 2.1.
enum StarterRecipes {
    static let vanillaCupcakes = Recipe(
        id: "cupcake",
        name: "Vanilla cupcakes",
        region: "Universal classic",
        pack: "core",
        bakeMinutes: 25,
        idealTemperature: .medium,
        isFree: true
    )
}
