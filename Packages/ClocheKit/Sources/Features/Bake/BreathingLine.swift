import DesignSystem
import SwiftUI

/// The faint 1 pt ivory line on the dark bake screen. Breathes slowly; static under Reduce Motion.
struct BreathingLine: View {
    var width: CGFloat = 220
    var isBreathing = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDim = false

    var body: some View {
        Capsule()
            .fill(Palette.accent)
            .frame(width: width, height: 1)
            .shadow(color: Palette.accent.opacity(0.8), radius: 6)
            .opacity(isDim ? 0.3 : 0.9)
            .accessibilityHidden(true)
            .onAppear {
                guard isBreathing, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    isDim = true
                }
            }
    }
}
