import DesignSystem
import Domain
import SwiftUI

/// Boards "Duo 5 Unfolded, reveal and grade" and "Duo 6 Opened early". The top half is the
/// cavity (steam over a finished bake); the grade sits inside the door's glass on the bottom half.
struct DuoGradeScreen: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    /// Radians from UIKit; the door swings with the unfolding hinge.
    let hingeAngle: Double?
    let send: (SessionEvent) -> Void

    var body: some View {
        let grade = GradeCalculator.grade(outcome, served: true)
        let copy = GradeCopy(grade: grade, isDemo: outcome.bake.isDemo)

        GeometryReader { proxy in
            let half = proxy.size.height / 2
            VStack(spacing: 0) {
                ZStack {
                    OvenCavityView(heat: grade.isHalfBaked ? 0.8 : 1, dishProgress: grade.isHalfBaked ? max(outcome.doneness * 0.5, 0.3) : 1, browning: grade.browning, dish: Dish(recipeID: recipe.id))
                    if !grade.isHalfBaked {
                        SteamView()
                    }
                }
                .padding([.horizontal, .top], Spacing.s3)
                .padding(.bottom, 14)
                .frame(height: half)
                .accessibilityHidden(true)

                DuoDoorPanel(liftDegrees: hingeAngle.map(DoorGeometry.liftDegrees(hingeAngle:)) ?? 0) {
                    gradeContent(grade: grade, copy: copy)
                }
                .frame(height: half)
            }
            .overlay { HingeCrease().position(x: proxy.size.width / 2, y: half) }
        }
        .background(Palette.black.ignoresSafeArea())
    }

    private func gradeContent(grade: Grade, copy: GradeCopy) -> some View {
        VStack(spacing: Spacing.s3) {
            HStack(spacing: Spacing.s4) {
                DishView(dish: Dish(recipeID: recipe.id), progress: grade.isHalfBaked ? max(outcome.doneness * 0.5, 0.3) : 1, browning: grade.browning, showsPlate: true)
                    .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    EyebrowLabel(copy.eyebrow)
                        .accessibilityIdentifier("grade.eyebrow")
                    (grade.isHalfBaked ? Text("Half-baked.", bundle: .module) : Text("Prêt.", bundle: .module))
                        .textStyle(.hero.sized(grade.isHalfBaked ? 40 : 48, lineHeight: 52))
                        .foregroundStyle(Palette.sand)
                        .accessibilityIdentifier("reveal.title")
                    Stars(earned: grade.stars, size: 22)
                        .accessibilityIdentifier("grade.stars")
                    copy.voiceLine
                        .textStyle(.voice(15))
                        .foregroundStyle(Palette.sand)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            DonenessBar(copy: copy)

            HStack(spacing: Spacing.s3) {
                Button {
                    send(.decorate)
                } label: {
                    Text("Decorate", bundle: .module)
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("grade.decorate")
                Button {
                    send(.servePlain)
                } label: {
                    Text("Serve plain", bundle: .module)
                }
                .buttonStyle(.outline)
                .accessibilityIdentifier("grade.servePlain")
            }
        }
    }
}
