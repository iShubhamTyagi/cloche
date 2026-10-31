import DesignSystem
import Domain
import SwiftUI

/// Boards "5 Grade" and "S2 8 Half-baked grade": the finished dish, its stars, doneness and
/// browning, then Decorate or Serve plain.
struct GradeScreen: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let onDecorate: () -> Void
    let onServePlain: () -> Void

    var body: some View {
        // Stars show what the dish earns if decorated and served; serving plain gives up only the serve star.
        let grade = GradeCalculator.grade(outcome, served: true)
        let copy = GradeCopy(grade: grade)

        VStack(spacing: 0) {
            EyebrowLabel(copy.eyebrow)
                .padding(.top, Spacing.s4)
                .accessibilityIdentifier("grade.eyebrow")

            CupcakeView(progress: grade.isHalfBaked ? max(outcome.doneness * 0.5, 0.3) : 1, browning: grade.browning, showsPlate: true)
                .frame(width: 210, height: 210)
                .padding(.top, Spacing.s3)

            Text(recipe.name)
                .textStyle(.name)
                .foregroundStyle(Palette.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.s2)

            Stars(earned: grade.stars, size: 34)
                .padding(.top, Spacing.s4)
                .accessibilityIdentifier("grade.stars")

            copy.voiceLine
                .textStyle(.voice(16))
                .foregroundStyle(Palette.sand)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.s3)

            VStack(spacing: Spacing.margin) {
                DonenessBar(copy: copy)
                BrowningBar(copy: copy)
            }
            .padding(.top, Spacing.margin)

            Spacer(minLength: Spacing.margin)

            Button(action: onDecorate) {
                HStack(spacing: Spacing.s2) {
                    Text("Decorate", bundle: .module)
                    Text("· \(Int(outcome.bake.breakDuration / 60)) min", bundle: .module)
                        .textStyle(.voice(17))
                }
            }
            .buttonStyle(.primary)
            .accessibilityLabel(Text("Decorate, \(Int(outcome.bake.breakDuration / 60)) minute break", bundle: .module))
            .accessibilityIdentifier("grade.decorate")

            Button(action: onServePlain) {
                Text("Serve plain", bundle: .module)
            }
            .buttonStyle(.text)
            .padding(.top, Spacing.s2)
            .accessibilityIdentifier("grade.servePlain")
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.s2)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .pocketScreenBackground()
    }
}
