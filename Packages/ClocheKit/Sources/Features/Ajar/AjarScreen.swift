import DesignSystem
import Domain
import SwiftUI

/// Boards "S2 7 Door ajar" and "Duo 2 Door ajar", one screen for both: the door opened
/// mid-bake. The top half is the oven (`OvenFrame` in `OvenStage`'s slot, door off), dimmed, with
/// the 15 s countdown; the bottom half is its open door. On the Duo the door tilts with the real
/// hinge (effect only, never layout) and the fold gets its crease; on the iPhone it lies flat and,
/// for a bake started by hand, carries the "Close the door" button.
struct AjarScreen: View {
    let bake: Bake
    let graceEndsAt: Date
    let door: DoorStyle
    /// Shuts the door by hand when the bake was started without turning the phone over.
    var onClose: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            OvenStage(isContentFullBleed: true) {
                EmptyView()
            } oven: {
                topHalf(at: context.date)
            } content: {
                DoorPanel(liftDegrees: door.liftDegrees) {
                    if let onClose {
                        ManualDoorButton(title: Text("Close the door", bundle: .module), identifier: "ajar.closeManually", action: onClose)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .hingeCrease(door)
        }
        .background(Palette.black.ignoresSafeArea())
    }

    private func topHalf(at date: Date) -> some View {
        ZStack {
            OvenFrame(
                plate: Text(CountdownFormat.seconds(graceEndsAt.timeIntervalSince(date))),
                heat: 0.8,
                dish: Dish(recipeID: bake.recipeID),
                dishProgress: bake.progress(at: date),
                browning: .pale,
                showsDoor: false
            )
            .accessibilityHidden(true)
            // 80% scrim over the cavity.
            Palette.black.opacity(0.8)
                .accessibilityHidden(true)
            AjarMessage(
                copy: AjarCopy(source: bake.source),
                remaining: graceEndsAt.timeIntervalSince(date),
                ringSize: 150,
                numeralSize: 68,
                headlineSize: 32
            )
            .padding(.horizontal, Spacing.margin)
            .padding(.top, OvenFrame.topBand)
        }
        .clipped()
    }
}
