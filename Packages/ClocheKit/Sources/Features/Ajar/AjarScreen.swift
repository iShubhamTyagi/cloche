import DesignSystem
import Domain
import SwiftUI

/// Boards "S2 7 Door ajar" and "Duo 2 Door ajar", one screen for both: the door opened
/// mid-bake. The top half is the rendered oven with its door open (following the hinge on the
/// Duo, ajar on the iPhone) and the countdown on its display. The warning lies on the open
/// door's glass as a HUD on the Duo (`OvenStage`), like Prep and Preheat; on the iPhone it fills
/// the bottom half. For a bake started by hand it carries the "Close the door" button.
struct AjarScreen: View {
    let bake: Bake
    let graceEndsAt: Date
    let door: DoorStyle
    /// Shuts the door by hand when the bake was started without turning the phone over.
    var onClose: (() -> Void)?

    /// How far the iPhone's drawn door stands open (the Duo's follows the hinge).
    private static let ajarAngle = 35.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = graceEndsAt.timeIntervalSince(context.date)
            OvenStage {
                EmptyView()
            } oven: {
                OvenFrame(
                    plate: Text(CountdownFormat.seconds(remaining)),
                    heat: 0.8,
                    dish: Dish(recipeID: bake.recipeID),
                    dishProgress: bake.progress(at: context.date),
                    browning: .pale,
                    doorOpen: 1,
                    openAngle: Self.ajarAngle
                )
                .accessibilityHidden(true)
            } content: {
                AjarContent(copy: AjarCopy(source: bake.source), remaining: remaining, onClose: onClose)
            }
        }
        .background(Palette.black.ignoresSafeArea())
    }
}

/// The warning: on the door's glass a compact side-by-side HUD (ring left, words and the close
/// button right); elsewhere the stacked message.
private struct AjarContent: View {
    let copy: AjarCopy
    let remaining: TimeInterval
    let onClose: (() -> Void)?

    @Environment(\.isOnDoorGlass) private var isOnDoorGlass

    var body: some View {
        if isOnDoorGlass {
            HStack(spacing: Spacing.margin) {
                RingClock(remaining: remaining, total: SessionEngine.graceDuration, size: 112, numeralSize: 46,
                          label: copy.ringLabel(remaining))
                    .accessibilityIdentifier("ajar.ring")
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    pill
                    copy.headline
                        .textStyle(.title.sized(22, lineHeight: 26))
                        .foregroundStyle(Palette.text)
                        .accessibilityIdentifier("ajar.title")
                    copy.helper
                        .textStyle(.note)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let onClose {
                        ManualDoorButton(title: Text("Close the door", bundle: .module), identifier: "ajar.closeManually", action: onClose)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: Spacing.s4) {
                AjarMessage(copy: copy, remaining: remaining, ringSize: 150, numeralSize: 68, headlineSize: 32)
                if let onClose {
                    ManualDoorButton(title: Text("Close the door", bundle: .module), identifier: "ajar.closeManually", action: onClose)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// "Door ajar", a glowing sand hairline pill on the glass.
    private var pill: some View {
        Text("Door ajar", bundle: .module)
            .textStyle(.control)
            .foregroundStyle(Palette.sand)
            .padding(.horizontal, Spacing.s3)
            .frame(minHeight: 28)
            .overlay(Capsule().strokeBorder(Palette.sand.opacity(0.85), lineWidth: 1))
            .shadow(color: Palette.sand.opacity(0.5), radius: 4)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    AjarScreen(
        bake: Bake(BakeRequest(recipe: StarterRecipes.vanillaCupcakes, length: .quick, source: .faceDown, isDemo: true)),
        graceEndsAt: .now.addingTimeInterval(11),
        door: DoorStyle(source: .faceDown, hingeAngle: nil)
    )
}
