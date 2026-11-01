import DesignSystem
import Domain
import SwiftUI

/// Boards "Duo 3" and "Duo 4": the Duo's outer screen while the phone is shut. The closed oven
/// carries the timer on its display plate; when ready the plate reads "Prêt." and a glow breathes.
/// Laid out from the available size, because the real cover screen is portrait (see DECISIONS).
struct CoverBakeScreen: View {
    let recipe: Recipe
    let bake: Bake
    let isReady: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowIsBright = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = (bake.endsAt ?? context.date).timeIntervalSince(context.date)
            let progress = bake.duration > 0 ? min(max(1 - remaining / bake.duration, 0), 1) : 1

            VStack(spacing: Spacing.margin) {
                Spacer(minLength: 0)
                OvenView(
                    plate: isReady ? Text("Prêt.", bundle: .module) : Text(CountdownFormat.clock(remaining)),
                    isPlateItalic: isReady,
                    heat: isReady ? 1 : 0.35 + 0.5 * progress
                )
                .accessibilityIdentifier(isReady ? "bake.ready" : "bake.timer")

                if isReady {
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
                }
                Spacer(minLength: 0)

                if !isReady {
                    progressLine(progress)
                }
            }
            .padding(.horizontal, Spacing.s3)
            .padding(.bottom, Spacing.margin)
            .offset(y: BurnInDrift.offset(at: context.date, period: 60, range: 7, step: 1))
        }
        .background {
            ZStack {
                Palette.black
                if isReady {
                    // Ready glow behind the oven, breathing over 4 s; covers the whole screen so it fades out softly.
                    RadialGradient(colors: [Palette.accent.opacity(glowIsBright ? 0.2 : 0.07), .clear], center: .center, startRadius: 0, endRadius: 320)
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

    private func progressLine(_ progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line1)
                Capsule().fill(Palette.accent).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 60)
        .accessibilityHidden(true)
    }
}
