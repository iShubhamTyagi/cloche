import DesignSystem
import QuartzCore
import SwiftUI

/// The shared stage: the oven fills the whole top half of the screen, edge to edge, with the
/// header row laid over it; content sits in the bottom half. The folded cover (`CoverStage`)
/// gives the oven the whole cover, so the oven slot is one full half in both states and the
/// placeholder art (`OvenFrame`) can be swapped for the 3D asset.
struct OvenStage<Header: View, Oven: View, Content: View>: View {
    /// Caps the bottom half's width on wide screens (the Duo's inner screen).
    static var maxWidth: CGFloat { 440 }

    /// The unfolded Duo's door panel spans the whole bottom half; other content is inset and capped.
    var isContentFullBleed = false
    /// Lay the content on the open door's glass on the open Duo. Off for screens whose top half
    /// isn't the oven with its door (decorating moves to the plating station).
    var isContentOnDoor = true
    @ViewBuilder let header: Header
    @ViewBuilder let oven: Oven
    @ViewBuilder let content: Content

    /// On the open Duo the oven door hangs open into the bottom half (it follows the hinge), so
    /// the content is laid over its glass like a HUD: centred on the door, as wide as its glass.
    @Environment(\.hingeDoorAngle) private var hingeDoorAngle

    var body: some View {
        GeometryReader { screen in
            // The status bar is hidden, so the oven runs to the top edge. The header row sits
            // level with the Dynamic Island (title left, buttons right, both clear of it); on
            // screens without one it just keeps a small margin.
            let safeTop = screen.safeAreaInsets.top
            let headerTop = max(safeTop / 2 - HitTarget.minimum / 2, Spacing.s2)
            let fullHeight = screen.size.height + safeTop + screen.safeAreaInsets.bottom
            VStack(spacing: 0) {
                oven
                    .frame(maxWidth: .infinity)
                    .frame(height: fullHeight / 2)
                    .overlay(alignment: .top) {
                        header
                            .frame(maxWidth: Self.maxWidth)
                            .frame(height: HitTarget.minimum)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, headerTop)
                    }
                if isContentFullBleed {
                    content
                        .frame(maxWidth: .infinity)
                        .frame(height: fullHeight / 2)
                } else if let glass = doorGlass(slot: CGSize(width: screen.size.width, height: fullHeight / 2)) {
                    // The open Duo: the content lies on the door's glass as a HUD, projected onto
                    // the glass at the door's current angle so it tilts with the hinge.
                    let slot = CGSize(width: screen.size.width, height: fullHeight / 2)
                    hudPane(size: glass.size)
                        .modifier(GlassProjection(size: glass.size, quad: glassQuad(slot: slot, below: slot.height)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .frame(height: fullHeight / 2)
                } else {
                    content
                        .padding(.horizontal, Spacing.margin)
                        .padding(.bottom, screen.safeAreaInsets.bottom + Spacing.s2)
                        .frame(maxWidth: Self.maxWidth)
                        .frame(maxWidth: .infinity)
                        .frame(height: fullHeight / 2)
                }
            }
            .ignoresSafeArea()
        }
    }

    /// The content as a HUD laid out on the fully open door's glass (its size there).
    private func hudPane(size: CGSize) -> some View {
        content
            .environment(\.isOnDoorGlass, true)
            .environment(\.isHUD, true)
            .shadow(color: Palette.accent.opacity(0.22), radius: 3)
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.s3)
            .frame(width: size.width, height: size.height)
            .background(HUDGlassChrome())
    }

    /// The glass at the hinge's current angle, in the bottom half's coordinates.
    private func glassQuad(slot: CGSize, below: CGFloat) -> GlassQuad {
        guard let layout = OvenRenderLayout.shared, let angle = hingeDoorAngle else { return GlassQuad(corners: [], facing: 0) }
        let quad = RenderedOven.glassQuad(layout: layout, angle: angle, in: slot)
        return GlassQuad(corners: quad.corners.map { CGPoint(x: $0.x, y: $0.y - below) }, facing: quad.facing)
    }

    /// The open door's glass, when the door follows the Duo's hinge and the rendered oven is in.
    private func doorGlass(slot: CGSize) -> CGRect? {
        guard isContentOnDoor, hingeDoorAngle != nil, let layout = OvenRenderLayout.shared else { return nil }
        return RenderedOven.openGlass(layout: layout, in: slot)
    }
}

/// Four corners of the door glass (reading order: top-left, top-right, bottom-right,
/// bottom-left) and how squarely it faces the viewer.
struct GlassQuad: Equatable {
    var corners: [CGPoint]
    var facing: Double
}

/// Lays a flat `size` view onto a quadrilateral with a true perspective (homography) transform,
/// so it lies on the glass at any door angle. Fades out as the glass turns edge-on, and stops
/// taking touches once it has (no tapping a sliver of a button).
struct GlassProjection: ViewModifier {
    let size: CGSize
    let quad: GlassQuad

    /// Below this the glass is too edge-on to read or touch.
    private static let fadeStart = 0.08
    private static let fadeEnd = 0.35

    func body(content: Content) -> some View {
        let opacity = min(max((quad.facing - Self.fadeStart) / (Self.fadeEnd - Self.fadeStart), 0), 1)
        content
            .projectionEffect(ProjectionTransform(Self.transform(from: size, to: quad.corners)))
            .opacity(opacity)
            .allowsHitTesting(opacity > 0.5)
            .accessibilityHidden(opacity < 0.5)
    }

    /// The homography taking the rect (0, 0, w, h) to the quad, as a CATransform3D.
    static func transform(from size: CGSize, to q: [CGPoint]) -> CATransform3D {
        guard q.count == 4, size.width > 0, size.height > 0 else { return CATransform3DIdentity }
        let (x0, y0, x1, y1) = (q[0].x, q[0].y, q[1].x, q[1].y)
        let (x2, y2, x3, y3) = (q[2].x, q[2].y, q[3].x, q[3].y)
        let sx = x0 - x1 + x2 - x3, sy = y0 - y1 + y2 - y3
        var g: CGFloat = 0, h: CGFloat = 0
        if abs(sx) > 1e-6 || abs(sy) > 1e-6 {
            let dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2
            let den = dx1 * dy2 - dx2 * dy1
            guard abs(den) > 1e-9 else { return CATransform3DIdentity }
            g = (sx * dy2 - dx2 * sy) / den
            h = (dx1 * sy - sx * dy1) / den
        }
        // Unit square -> quad, then scale the square to the view's size.
        let a = (x1 - x0 + g * x1) / size.width, b = (x3 - x0 + h * x3) / size.height
        let d = (y1 - y0 + g * y1) / size.width, e = (y3 - y0 + h * y3) / size.height
        var m = CATransform3DIdentity
        m.m11 = a; m.m21 = b; m.m41 = x0
        m.m12 = d; m.m22 = e; m.m42 = y0
        m.m14 = g / size.width; m.m24 = h / size.height; m.m44 = 1
        return m
    }
}
