import DesignSystem
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
                    // The open Duo: the content sits inside the door's glass, like a HUD.
                    content
                        .environment(\.isOnDoorGlass, true)
                        .padding(Spacing.s3)
                        .frame(width: glass.width, height: glass.height)
                        .offset(x: glass.minX, y: glass.minY - fullHeight / 2)
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

    /// The open door's glass, when the door follows the Duo's hinge and the rendered oven is in.
    private func doorGlass(slot: CGSize) -> CGRect? {
        guard isContentOnDoor, hingeDoorAngle != nil, let layout = OvenRenderLayout.shared else { return nil }
        return RenderedOven.openGlass(layout: layout, in: slot)
    }
}
