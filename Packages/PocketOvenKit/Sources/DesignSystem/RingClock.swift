import SwiftUI

/// Countdown ring used by the break clock and the 15 s door-ajar grace. Display only: callers
/// drive `remaining` from a stored end date (usually inside a `TimelineView`).
public struct RingClock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private let remaining: TimeInterval
    private let total: TimeInterval
    private let size: CGFloat
    private let isAmber: Bool
    private let label: Text

    /// - Parameters:
    ///   - isAmber: the last-30-seconds state: honey colour, thicker stroke, slow pulse.
    ///   - label: spoken description, e.g. "4:12 left in the break".
    public init(remaining: TimeInterval, total: TimeInterval, size: CGFloat, isAmber: Bool = false, label: Text) {
        self.remaining = remaining
        self.total = total
        self.size = size
        self.isAmber = isAmber
        self.label = label
    }

    /// Fraction of time left, 0 to 1.
    nonisolated static func fraction(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0, remaining.isFinite else { return 0 }
        return min(max(remaining / total, 0), 1)
    }

    public var body: some View {
        let fraction = Self.fraction(remaining: remaining, total: total)
        let lineWidth: CGFloat = isAmber ? 8 : 6
        let colour = isAmber ? Palette.honey : Palette.accent

        ZStack {
            Circle()
                .stroke(Palette.line1, lineWidth: lineWidth)
            // Depletes clockwise from 12 o'clock: the start of the arc moves, the end stays at 12.
            Circle()
                .trim(from: 1 - fraction, to: 1)
                .stroke(colour, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(isAmber && isPulsing ? 0.55 : 1)
            Text(CountdownFormat.clock(remaining))
                .textStyle(.numeral(size * 0.29))
                .foregroundStyle(isAmber ? Palette.honey : Palette.text)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(lineWidth * 2)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(label)
        .onChange(of: isAmber, initial: true) { _, amber in
            guard amber, !reduceMotion else {
                isPulsing = false
                return
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
