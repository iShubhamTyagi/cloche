import DesignSystem
import SwiftUI

/// Three soft puffs that rise about 50 pt and fade, staggered (5, 5.5 and 6 s loops).
/// Sized by its container, so lay it over the cavity. Off under Reduce Motion.
struct SteamView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    puff(t, period: 5.0, x: -0.22)
                    puff(t, period: 5.5, x: 0.02)
                    puff(t, period: 6.0, x: 0.24)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Horizontal centre of the puffs, as a fraction of the width (the cavity sits left of the controls).
    var centerX: Double = 0.5
    /// Where the puffs start, as a fraction of the height (just above the dish).
    var startY: Double = 0.8

    private func puff(_ time: TimeInterval, period: Double, x: Double) -> some View {
        let phase = time.truncatingRemainder(dividingBy: period) / period
        return GeometryReader { proxy in
            Ellipse()
                .fill(Palette.text.opacity(0.22 * sin(phase * .pi)))
                .frame(width: proxy.size.width * 0.28, height: proxy.size.width * 0.16)
                .blur(radius: 14)
                .position(x: proxy.size.width * (centerX + x * 0.7), y: proxy.size.height * startY - 50 * phase)
        }
    }
}
