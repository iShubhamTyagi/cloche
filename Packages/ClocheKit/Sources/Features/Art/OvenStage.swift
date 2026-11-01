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
    @ViewBuilder let header: Header
    @ViewBuilder let oven: Oven
    @ViewBuilder let content: Content

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
}
