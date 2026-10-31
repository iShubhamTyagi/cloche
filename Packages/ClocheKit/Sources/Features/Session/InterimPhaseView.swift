import DesignSystem
import Domain
import SwiftUI

/// Stand-in for the phases whose screens arrive in slices 1.5 to 1.7 and 2.3, so the whole
/// loop can be walked through now. Every phase here is replaced before TestFlight.
struct InterimPhaseView: View {
    let phase: SessionPhase
    let send: (SessionEvent) -> Void

    var body: some View {
        VStack(spacing: Spacing.margin) {
            EyebrowLabel(Text(verbatim: title))
                .accessibilityIdentifier("interim.phase")
            if let deadline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(CountdownFormat.clock(deadline.timeIntervalSince(context.date)))
                        .textStyle(.numeral(76))
                        .foregroundStyle(Palette.subtle)
                }
            }
            actions
        }
        .padding(Spacing.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pocketScreenBackground()
    }

    private var title: String {
        switch phase {
        case .idle: "Idle"
        case .armed: "Armed"
        case .baking: "Baking"
        case .ajar: "Door ajar"
        case .ready: "Ready"
        case let .graded(outcome): outcome.isFullyBaked ? "Graded · fully baked" : "Graded · \(Int(outcome.doneness * 100))% baked"
        case .decorating: "Decorating"
        case let .served(_, grade): "Served · \(grade.stars) stars"
        }
    }

    private var deadline: Date? {
        switch phase {
        case let .baking(bake): bake.endsAt
        case let .ajar(_, _, graceEndsAt): graceEndsAt
        case let .decorating(_, breakEndsAt): breakEndsAt
        default: nil
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch phase {
        case .graded:
            Button(String("Decorate")) { send(.decorate) }.buttonStyle(.primary)
            Button(String("Serve plain")) { send(.servePlain) }.buttonStyle(.text)
        case .decorating:
            Button(String("Serve now")) { send(.serveNow) }.buttonStyle(.outline)
        case .served:
            Button(String("Done")) { send(.done) }.buttonStyle(.outline)
                .accessibilityIdentifier("interim.done")
        default:
            EmptyView()
        }
    }
}
