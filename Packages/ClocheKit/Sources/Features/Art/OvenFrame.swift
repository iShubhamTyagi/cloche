import DesignSystem
import Domain
import SwiftUI

/// The oven slot: fills whatever frame it is given, with no aspect ratio of its own.
/// `OvenStage` gives it the whole top half of the open screen and `CoverStage` the whole folded
/// cover, so swapping this body for the 3D asset changes nothing else.
///
/// Placeholder art, kept minimal: a black body, a glass door hinged on its bottom edge with a
/// handle across the top, and a slim control column with a small timer display and two knobs.
/// The door takes nearly all the space, so the dish inside stays large.
struct OvenFrame: View {
    /// Text on the display, e.g. a time or "Prêt.".
    let plate: Text
    var isPlateItalic = false
    /// 0 cold, 1 fully heated; brightens the rods.
    var heat: Double = 0.4
    let dish: Dish
    var dishProgress: Double = 0
    var browning: Browning = .golden
    /// 0 shut, 1 dropped flat on its bottom hinge.
    var doorOpen: Double = 0
    /// False on the unfolded Duo, where the door lies on the bottom half (`DuoDoorPanel`) and the
    /// top half shows the same oven with its door off.
    var showsDoor = true

    /// The door (and so the oven's interior) is the same size in points on the open screen and on
    /// the folded cover, so folding and unfolding looks like the same oven. Sized to fit both of the
    /// Duo's halves (open top half 669 × 475 pt, cover 678 × 466 pt) with both bands; smaller
    /// screens shrink it. The black body takes up whatever is left.
    static let doorSize = CGSize(width: 520, height: 348)
    /// Kept on the body above the door for the header on the open screen, and below it for the
    /// caption on the cover. Both states keep both bands so the door sits in the same place.
    static let topBand: CGFloat = HitTarget.minimum
    static let bottomBand: CGFloat = Spacing.s4 + Spacing.s2
    private static let column: CGFloat = HitTarget.minimum + Spacing.s3

    var body: some View {
        HStack(spacing: Spacing.s3) {
            door
                .frame(maxWidth: Self.doorSize.width, maxHeight: Self.doorSize.height)
            controls
                .frame(width: Self.column)
                .frame(maxHeight: Self.doorSize.height)
        }
        .padding(Spacing.s4)
        .padding(.top, Self.topBand)
        .padding(.bottom, Self.bottomBand)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ovenBody)
        .padding(Spacing.s2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Oven", bundle: .module))
        .accessibilityValue(plate)
    }

    // MARK: Body

    private var ovenBody: some View {
        RoundedRectangle(cornerRadius: Spacing.s4)
            .fill(LinearGradient(colors: [Color(white: 0.13), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: Spacing.s4).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: Door

    /// The cavity, with the glass door over it; the door drops toward the viewer on its bottom hinge.
    private var door: some View {
        let corner = Spacing.s3
        return ZStack {
            OvenCavityView(heat: heat, dishProgress: dishProgress, browning: browning, dish: dish)
                .clipShape(RoundedRectangle(cornerRadius: corner))
            if showsDoor {
                doorPanel(corner: corner)
                    // Past 90° so the dropped door lies below the hinge, widening toward the viewer.
                    .rotation3DEffect(.degrees(-100 * min(max(doorOpen, 0), 1)), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.45)
            }
        }
    }

    /// Black door frame around clear glass, with a handle across the top.
    private func doorPanel(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner)
            .strokeBorder(Color(white: 0.03), lineWidth: Spacing.s2)
            .background(
                RoundedRectangle(cornerRadius: corner)
                    .fill(LinearGradient(colors: [.white.opacity(0.06), .clear, .white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: corner).strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color(white: 0.6))
                    .frame(height: 4)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.s4)
            }
            // Two hinge tabs on the bottom edge, where the door pivots.
            .overlay(alignment: .bottom) {
                HStack {
                    hingeTab
                    Spacer()
                    hingeTab
                }
                .padding(.horizontal, Spacing.margin)
                .offset(y: 3)
            }
    }

    private var hingeTab: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(white: 0.35))
            .frame(width: 18, height: 6)
    }

    // MARK: Controls

    /// A small timer display and two knobs.
    private var controls: some View {
        VStack(spacing: Spacing.s4) {
            plate
                .textStyle(isPlateItalic ? .voice(14) : .numeral(14))
                .foregroundStyle(isPlateItalic ? Palette.sand : Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, Spacing.s1)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.08), lineWidth: 1))
            knob
            knob
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.s2)
    }

    private var knob: some View {
        Circle()
            .fill(Color(white: 0.22))
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .top) {
                Capsule().fill(Color(white: 0.6)).frame(width: 2, height: 7).padding(.top, 3)
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }
}

#Preview("Open top half") {
    OvenFrame(plate: Text(verbatim: "25:00"), dish: .cupcakes)
        .frame(width: 402, height: 437)
}

#Preview("Cover") {
    OvenFrame(plate: Text(verbatim: "10:35"), heat: 0.7, dish: .cupcakes, dishProgress: 0.6)
        .frame(width: 678, height: 466)
}

#Preview("Door open") {
    OvenFrame(plate: Text(verbatim: "0:11"), heat: 0.8, dish: .cupcakes, dishProgress: 0.5, doorOpen: 0.6)
        .frame(width: 402, height: 437)
}
