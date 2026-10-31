@testable import Domain
import Foundation
import Testing

struct GradeCalculatorTests {
    private func outcome(_ temperature: Temperature, doneness: Double, recipe: Recipe = .cupcakes, demo: Bool = false) -> BakeOutcome {
        let bake = Bake(BakeRequest(recipe: recipe, temperature: temperature, source: .faceDown, isDemo: demo))
        return BakeOutcome(bake: bake, doneness: doneness)
    }

    @Test func perfectBakeDecoratedAndServedEarnsThreeStars() {
        let grade = GradeCalculator.grade(outcome(.medium, doneness: 1), served: true)
        #expect(grade.stars == 3)
        #expect(grade.browning == .golden)
    }

    @Test(arguments: [(Temperature.low, Browning.pale), (.high, .dark)])
    func wrongTemperatureChangesBrowningAndDropsOneStar(temperature: Temperature, browning: Browning) {
        let grade = GradeCalculator.grade(outcome(temperature, doneness: 1), served: true)
        #expect(grade.browning == browning)
        #expect(grade.stars == 2)
        #expect(grade.doneness == 1)
    }

    @Test func halfBakedIsCappedAtOneStarAndPale() {
        let grade = GradeCalculator.grade(outcome(.medium, doneness: 0.62), served: true)
        #expect(grade.stars == 1)
        #expect(grade.isHalfBaked)
        #expect(grade.browning == .pale)
    }

    @Test func idealTemperatureComesFromTheRecipe() {
        let grade = GradeCalculator.grade(outcome(.low, doneness: 1, recipe: .biryani), served: true)
        #expect(grade.browning == .golden)
        #expect(grade.stars == 3)
    }

    @Test func demoBakesNeverEarnStars() {
        #expect(GradeCalculator.grade(outcome(.medium, doneness: 1, demo: true), served: true).stars == 0)
    }

    @Test(arguments: [(25, 5), (50, 8), (90, 10)])
    func breakFollowsBakeLength(bakeMinutes: Int, breakMinutes: Int) {
        let recipe = Recipe(id: "x", name: "x", region: "x", pack: "x", bakeMinutes: bakeMinutes, idealTemperature: .medium, isFree: true)
        #expect(recipe.breakMinutes == breakMinutes)
    }
}
