#if DEBUG
import SwiftUI

/// Every design-system piece on one scrolling screen, for checking against the canvas
/// "Foundations" board. Debug builds only; launch with `-componentGallery`.
public struct ComponentGallery: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.margin) {
                section("Type") {
                    Text(verbatim: "Prêt.").textStyle(.hero).foregroundStyle(Palette.sand)
                    Text(verbatim: "The oven is ready.").textStyle(.title).foregroundStyle(Palette.text)
                    Text(verbatim: "Vanilla cupcakes").textStyle(.name).foregroundStyle(Palette.text)
                    Text(verbatim: "24:59").textStyle(.numeral(76)).foregroundStyle(Palette.subtle)
                    Text(verbatim: "Golden at Medium last time").textStyle(.voice(16)).foregroundStyle(Palette.sand)
                    EyebrowLabel(Text(verbatim: "25 min · Universal classic"))
                    Text(verbatim: "Place the phone face down to keep baking. Left up, this bake ends as half-baked.")
                        .textStyle(.body).foregroundStyle(Palette.muted)
                }
                section("Colour") {
                    HStack(spacing: Spacing.s2) {
                        ForEach(Array(Self.swatches.enumerated()), id: \.offset) { _, colour in
                            RoundedRectangle(cornerRadius: Radius.chip)
                                .fill(colour)
                                .overlay(RoundedRectangle(cornerRadius: Radius.chip).strokeBorder(Palette.line2))
                                .frame(width: 36, height: 36)
                        }
                    }
                    HStack(spacing: Spacing.s2) {
                        ForEach(FoodPalette.Icing.allCases, id: \.self) { icing in
                            Circle().fill(icing.color).frame(width: 36, height: 36)
                        }
                    }
                }
                section("Buttons") {
                    Button {} label: {
                        HStack(spacing: Spacing.s2) {
                            Text(verbatim: "Preheat")
                            Text(verbatim: "· 25 min").textStyle(.voice(17))
                        }
                    }
                    .buttonStyle(.primary)
                    Button(String("Done")) {}.buttonStyle(.outline)
                    Button(String("Part of the Full Kitchen")) {}.buttonStyle(.locked)
                    Button(String("Serve plain")) {}.buttonStyle(.text)
                }
                section("Stars") {
                    HStack(spacing: Spacing.margin) {
                        Stars(earned: 2)
                        Stars(earned: 1, size: 22)
                    }
                }
                section("Ring clock") {
                    HStack(spacing: Spacing.margin) {
                        RingClock(remaining: 252, total: 300, size: 96, label: Text(verbatim: "4:12 left in the break"))
                        RingClock(remaining: 24, total: 300, size: 96, isAmber: true, label: Text(verbatim: "0:24 left in the break, last 30 seconds"))
                        RingClock(remaining: 11, total: 15, size: 96, label: Text(verbatim: "11 seconds left"))
                    }
                }
            }
            .padding(Spacing.margin)
        }
        .pocketScreenBackground()
        .accessibilityIdentifier("componentGallery")
    }

    private static let swatches: [Color] = [
        Palette.ground, Palette.surface, Palette.text, Palette.muted, Palette.subtle, Palette.accent, Palette.sand, Palette.honey,
    ]

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            EyebrowLabel(Text(verbatim: title))
            content()
        }
    }
}

#Preview {
    ComponentGallery()
}
#endif
