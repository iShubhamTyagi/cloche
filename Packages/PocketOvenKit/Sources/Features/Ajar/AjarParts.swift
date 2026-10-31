import DesignSystem
import Domain
import SwiftUI

/// "Door ajar" pill, ring countdown, headline and helper; shared by iPhone and Duo layouts.
struct AjarMessage: View {
    let copy: AjarCopy
    let remaining: TimeInterval
    let ringSize: CGFloat
    let numeralSize: CGFloat
    let headlineSize: CGFloat

    var body: some View {
        VStack(spacing: Spacing.margin) {
            Text("Door ajar", bundle: .module)
                .textStyle(.control)
                .foregroundStyle(Palette.text)
                .padding(.horizontal, Spacing.s4)
                .frame(minHeight: 32)
                .overlay(Capsule().strokeBorder(Palette.line2, lineWidth: 1))
                .accessibilityAddTraits(.isHeader)

            RingClock(
                remaining: remaining,
                total: SessionEngine.graceDuration,
                size: ringSize,
                numeralSize: numeralSize,
                label: copy.ringLabel(remaining)
            )
            .accessibilityIdentifier("ajar.ring")

            VStack(spacing: Spacing.s3) {
                copy.headline
                    .textStyle(.title.sized(headlineSize, lineHeight: headlineSize + 4))
                    .foregroundStyle(Palette.text)
                    .accessibilityIdentifier("ajar.title")
                copy.helper
                    .textStyle(.body)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
        }
    }
}

extension Bake {
    /// Fraction of the bake time that has passed by `date`, 0 to 1.
    func progress(at date: Date) -> Double {
        guard let startedAt, duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(startedAt) / duration, 0), 1)
    }
}
