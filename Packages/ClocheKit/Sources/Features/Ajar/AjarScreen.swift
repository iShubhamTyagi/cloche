import DesignSystem
import Domain
import SwiftUI

/// Board "S2 7 Door ajar" (iPhone): the phone was turned over mid-bake. The open oven sits dimmed
/// behind a 15 s countdown; turning the phone back over within it keeps the bake going.
struct AjarScreen: View {
    let bake: Bake
    let graceEndsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            ZStack {
                OvenView(plate: Text(CountdownFormat.seconds(graceEndsAt.timeIntervalSince(context.date))), heat: 0.8, doorOpen: 1, dishProgress: bake.progress(at: context.date), browning: .pale, dish: Dish(recipeID: bake.recipeID))
                    .frame(maxWidth: 342)
                    .opacity(0.38)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, Spacing.margin)
                    .accessibilityHidden(true)

                LinearGradient(colors: [Palette.ground.opacity(0.2), Palette.ground.opacity(0.92), Palette.ground], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                AjarMessage(
                    copy: AjarCopy(source: bake.source),
                    remaining: graceEndsAt.timeIntervalSince(context.date),
                    ringSize: 190,
                    numeralSize: 88,
                    headlineSize: 38
                )
                .padding(.horizontal, Spacing.margin)
                .padding(.top, 140)
            }
        }
        .pocketScreenBackground()
    }
}
