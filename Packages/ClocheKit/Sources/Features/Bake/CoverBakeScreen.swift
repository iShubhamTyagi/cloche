import DesignSystem
import Domain
import SwiftUI

/// Boards "Duo 3" and "Duo 4": the Duo's outer screen while the phone is shut. It is the outside
/// of the same oven the inner screen shows, in the same place and size (`OvenStage`): door shut,
/// the dish visible through the glass, the timer on the display plate. When ready the plate
/// reads "Prêt." and a glow breathes.
struct CoverBakeScreen: View {
    let recipe: Recipe
    let bake: Bake
    let isReady: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowIsBright = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max((bake.endsAt ?? context.date).timeIntervalSince(context.date), 0)
            let progress = bake.duration > 0 ? min(max(1 - remaining / bake.duration, 0), 1) : 1

            OvenStage {
                Color.clear
            } oven: {
                OvenView(
                    plate: isReady ? Text("Prêt.", bundle: .module) : Text(CountdownFormat.clock(remaining)),
                    isPlateItalic: isReady,
                    heat: isReady ? 1 : 0.35 + 0.5 * progress,
                    dishProgress: isReady ? 1 : progress,
                    dish: Dish(recipeID: recipe.id),
                    hasClearGlass: true
                )
                .accessibilityIdentifier(isReady ? "bake.ready" : "bake.timer")
            } content: {
                status(remaining: remaining, progress: progress)
            }
            // Keeps static art moving slightly over a 90-minute bake (Guideline 2.4.2).
            .offset(y: BurnInDrift.offset(at: context.date, period: 60, range: 7, step: 1))
        }
        .background {
            ZStack {
                Palette.black
                if isReady {
                    // Ready glow behind the oven, breathing over 4 s; covers the whole screen so it fades out softly.
                    RadialGradient(colors: [Palette.accent.opacity(glowIsBright ? 0.2 : 0.07), .clear], center: .top, startRadius: 0, endRadius: 420)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .onAppear {
            guard isReady, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIsBright = true
            }
        }
    }

    @ViewBuilder
    private func status(remaining: TimeInterval, progress: Double) -> some View {
        VStack(spacing: Spacing.s3) {
            if isReady {
                Text("Prêt.", bundle: .module)
                    .textStyle(.hero)
                    .foregroundStyle(Palette.sand)
                    .accessibilityHidden(true)
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "chevron.up")
                        .accessibilityHidden(true)
                    Text("Ready. Lift the lid to open the door.", bundle: .module)
                }
                .textStyle(.control)
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
            } else {
                EyebrowLabel(Text("Baking · \(recipe.name)", bundle: .module))
                Text(CountdownFormat.clock(remaining))
                    .textStyle(.numeral(64))
                    .foregroundStyle(Palette.subtle)
                    .accessibilityLabel(Text("\(CountdownFormat.clock(remaining)) left in the bake", bundle: .module))
                progressLine(progress)
                    .padding(.top, Spacing.s2)
            }
        }
        .padding(.top, Spacing.margin)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func progressLine(_ progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line1)
                Capsule().fill(Palette.accent).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 40)
        .accessibilityHidden(true)
    }
}

#Preview("Baking") {
    CoverBakeScreen(recipe: StarterRecipes.vanillaCupcakes, bake: Bake(BakeRequest(recipe: StarterRecipes.vanillaCupcakes, length: .quick, source: .hinge)), isReady: false)
        .frame(width: 466, height: 678)
}

#Preview("Ready") {
    CoverBakeScreen(recipe: StarterRecipes.largeCake, bake: Bake(BakeRequest(recipe: StarterRecipes.largeCake, length: .long, source: .hinge)), isReady: true)
        .frame(width: 466, height: 678)
}
