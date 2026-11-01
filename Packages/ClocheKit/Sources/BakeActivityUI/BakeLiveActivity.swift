import ActivityKit
import BakeActivity
import DesignSystem
import SwiftUI
import WidgetKit

/// The bake's Live Activity, drawn by the widget extension. Minimal on purpose: the time left and
/// one word for the state, ivory on black. The Watch shows the `.small` family in its Smart Stack
/// without a Watch app; the lock screen and Dynamic Island get the same content.
public struct BakeLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BakeActivityAttributes.self) { context in
            BakeActivityView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Palette.black)
                .activitySystemActionForegroundColor(Palette.text)
        } dynamicIsland: { context in
            let display = BakeDisplay(state: context.state, isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BakeLabel(display: display)
                        .padding(.leading, Spacing.s1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BakeTime(display: display, size: 28)
                        .padding(.trailing, Spacing.s1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BakeProgress(display: display)
                        .padding(.horizontal, Spacing.s1)
                }
            } compactLeading: {
                Image(systemName: "oven")
                    .foregroundStyle(Palette.text)
                    .accessibilityHidden(true)
            } compactTrailing: {
                BakeTime(display: display, size: 15)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "oven")
                    .foregroundStyle(Palette.text)
                    .accessibilityLabel(display.label)
            }
            .keylineTint(Palette.text)
        }
        .supplementalActivityFamilies([.small])
    }
}

/// Lock screen (`.medium`) and Watch Smart Stack (`.small`).
struct BakeActivityView: View {
    let state: BakeActivityAttributes.ContentState
    let isStale: Bool

    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small:
            // The Watch shows only the bake: a door left open keeps the bake timer on screen,
            // because the system relays updates to the Watch seconds late (DECISIONS 2026-11-01).
            WatchBakeView(display: BakeDisplay(state: state, isStale: isStale, showsDoor: false))
        default:
            let display = BakeDisplay(state: state, isStale: isStale)
            HStack(alignment: .center, spacing: Spacing.s4) {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    BakeLabel(display: display)
                    BakeProgress(display: display)
                }
                BakeTime(display: display, size: 40)
            }
            .padding(Spacing.s4)
        }
    }
}

/// The Watch: the time, large, with the state above it and a hairline of progress below.
/// Always-On dims it and drops the progress line.
struct WatchBakeView: View {
    let display: BakeDisplay

    @Environment(\.isLuminanceReduced) private var isDimmed

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            BakeLabel(display: display)
            BakeTime(display: display, size: 34)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !isDimmed {
                BakeProgress(display: display)
            }
        }
        .opacity(isDimmed ? 0.7 : 1)
        .padding(.horizontal, Spacing.s1)
    }
}

// MARK: Pieces

/// What a state shows. `isStale` means the stored end passed while the app couldn't update:
/// a bake past its end is ready; a door left open past its grace has ended the bake.
struct BakeDisplay {
    enum Kind { case counting(ClosedRange<Date>), ready, out }

    let label: Text
    let kind: Kind
    /// The whole bake, for the progress line; nil hides it.
    let bakeSpan: ClosedRange<Date>?

    /// `showsDoor` false shows a door left open as the bake still running (the bake keeps its
    /// end time while the door is open), with no grace countdown.
    init(state: BakeActivityAttributes.ContentState, isStale: Bool, showsDoor: Bool = true) {
        let span = state.startedAt...max(state.startedAt, state.endsAt)
        var stage = state.stage
        var isStale = isStale
        if !showsDoor, stage == .ajar {
            stage = .baking
            // Stale here only means the grace ran out; the timer itself stops at 0:00.
            isStale = false
        }
        switch (stage, isStale) {
        case (.baking, false):
            label = Text("Baking", bundle: .module)
            // The lower bound only has to be in the past; the text shows the time left to the upper.
            kind = .counting(span)
            bakeSpan = span
        case (.baking, true), (.ready, _):
            label = Text("Ready", bundle: .module)
            kind = .ready
            bakeSpan = nil
        case (.ajar, false):
            label = Text("Door ajar", bundle: .module)
            let graceEnd = state.graceEndsAt ?? state.endsAt
            kind = .counting(state.startedAt...max(state.startedAt, graceEnd))
            bakeSpan = nil
        case (.ajar, true):
            label = Text("Out of the oven", bundle: .module)
            kind = .out
            bakeSpan = nil
        }
    }
}

struct BakeLabel: View {
    let display: BakeDisplay

    var body: some View {
        HStack(spacing: Spacing.s1) {
            Image(systemName: "oven")
                .accessibilityHidden(true)
            display.label
                .textStyle(.eyebrow)
                .lineLimit(1)
        }
        .foregroundStyle(Palette.muted)
    }
}

/// Counts down by itself from the stored end time; nothing ticks over the air.
struct BakeTime: View {
    let display: BakeDisplay
    let size: CGFloat

    var body: some View {
        Group {
            switch display.kind {
            case let .counting(range):
                Text(timerInterval: range, countsDown: true)
                    .textStyle(.numeral(size))
                    .foregroundStyle(Palette.text)
            case .ready:
                Text("Prêt.", bundle: .module)
                    .textStyle(.voice(size))
                    .foregroundStyle(Palette.sand)
            case .out:
                Text("Open Cloche", bundle: .module)
                    .textStyle(.voice(size * 0.6))
                    .foregroundStyle(Palette.sand)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .multilineTextAlignment(.trailing)
    }
}

struct BakeProgress: View {
    let display: BakeDisplay

    var body: some View {
        if let span = display.bakeSpan {
            ProgressView(timerInterval: span, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(Palette.text)
            .accessibilityHidden(true)
        }
    }
}

#Preview("Lock screen", as: .content, using: BakeActivityAttributes()) {
    BakeLiveActivity()
} contentStates: {
    BakeActivityAttributes.ContentState(stage: .baking, startedAt: .now, endsAt: .now.addingTimeInterval(25 * 60))
    BakeActivityAttributes.ContentState(stage: .ajar, startedAt: .now, endsAt: .now.addingTimeInterval(20 * 60), graceEndsAt: .now.addingTimeInterval(12))
    BakeActivityAttributes.ContentState(stage: .ready, startedAt: .now, endsAt: .now)
}
