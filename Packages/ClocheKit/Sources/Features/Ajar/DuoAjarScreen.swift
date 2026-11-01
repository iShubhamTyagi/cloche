import DesignSystem
import Domain
import SwiftUI

/// Board "Duo 2 Door ajar": the inner display split at the hinge. The top half is the dimmed
/// oven cavity with the countdown; the bottom half is the oven door, tilted by the real hinge
/// angle (effect only, never layout). Nothing is placed across the hinge band.
struct DuoAjarScreen: View {
    let bake: Bake
    let graceEndsAt: Date
    /// Radians from UIKit, π when flat; nil before the hinge has reported.
    let hingeAngle: Double?

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.height / 2
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                VStack(spacing: 0) {
                    topHalf(at: context.date)
                        .frame(height: half)
                    DuoDoorPanel(liftDegrees: hingeAngle.map(DoorGeometry.liftDegrees(hingeAngle:)) ?? DoorGeometry.defaultAjarLift)
                        .frame(height: half)
                        .accessibilityHidden(true)
                }
                .overlay { HingeCrease().position(x: proxy.size.width / 2, y: half) }
            }
        }
        .background(Palette.black.ignoresSafeArea())
    }

    private func topHalf(at date: Date) -> some View {
        ZStack {
            OvenCavityView(heat: 0.8, dishProgress: bake.progress(at: date), browning: .pale, dish: Dish(recipeID: bake.recipeID))
                .padding([.horizontal, .top], Spacing.s3)
                .padding(.bottom, 14)
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
        }
        .clipped()
    }
}

/// The open oven door lying on the bottom half, with optional content shown through its glass.
/// Rotates about its top edge, which is the hinge.
struct DuoDoorPanel<Content: View>: View {
    let liftDegrees: Double
    @ViewBuilder var content: () -> Content

    init(liftDegrees: Double, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.liftDegrees = liftDegrees
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - Spacing.s4 * 2, 560)
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.13)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line2, lineWidth: 1))
                .overlay {
                    // Glass window, with whatever the door shows behind it.
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                        .overlay { content().padding(Spacing.s3) }
                        .padding(.horizontal, width * 0.06)
                        .padding(.top, proxy.size.height * 0.06)
                        .padding(.bottom, proxy.size.height * 0.12)
                }
                .overlay(alignment: .bottom) {
                    // Chrome handle at the far edge.
                    Capsule().fill(Color(white: 0.6)).frame(width: width * 0.75, height: 12).padding(.bottom, 16)
                        .accessibilityHidden(true)
                }
                .frame(width: width, height: proxy.size.height - 10)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 10)
                .rotation3DEffect(.degrees(liftDegrees), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.25)
                .frame(maxWidth: .infinity)
                .padding(.top, 1)
        }
        // The door never draws outside its half.
        .clipped()
    }
}

/// Crease shadow and two fixed hinge barrels along the fold (handoff "Hinge details").
struct HingeCrease: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [.clear, .black.opacity(0.62), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
                HStack {
                    barrel
                    Spacer()
                    barrel
                }
                .padding(.horizontal, proxy.size.width * 0.055)
            }
            .frame(height: 24)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var barrel: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(white: 0.75), Color(white: 0.35)], startPoint: .top, endPoint: .bottom))
            .frame(width: 86, height: 16)
    }
}
