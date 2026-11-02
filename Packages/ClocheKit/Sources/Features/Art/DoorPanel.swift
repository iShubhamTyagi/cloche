import DesignSystem
import Domain
import SwiftUI

/// How a screen's open oven door is drawn, from where the bake's door signal comes from. The
/// layout is the same everywhere (oven in the top half, its open door lying in the bottom half);
/// only these details change.
struct DoorStyle {
    /// The door lifts with the real hinge and the fold gets its crease (iPhone Duo, unfolded).
    let followsHinge: Bool
    /// Degrees the door is lifted off flat.
    let liftDegrees: Double

    /// - Parameters:
    ///   - hingeAngle: radians from UIKit, nil before the hinge has reported or without one.
    ///   - restingLift: the lift when the hinge hasn't reported (the iPhone's door lies flat).
    init(source: DoorSource, hingeAngle: Double?, restingLift: Double = 0) {
        followsHinge = source == .hinge
        liftDegrees = followsHinge ? (hingeAngle.map(DoorGeometry.liftDegrees(hingeAngle:)) ?? restingLift) : 0
    }
}

extension View {
    /// The hinge crease along the middle, on the Duo only.
    @ViewBuilder
    func hingeCrease(_ style: DoorStyle) -> some View {
        if style.followsHinge {
            overlay { HingeCrease().ignoresSafeArea() }
        } else {
            self
        }
    }
}

/// The open oven door lying on the bottom half, with optional content shown through its glass.
/// Rotates about its top edge, which is the hinge.
struct DoorPanel<Content: View>: View {
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
