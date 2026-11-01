import DesignSystem
import SwiftUI

/// Hosts a screen on the Duo's cover display the way the folded phone is actually held.
///
/// The cover panel draws in portrait (466 × 678 pt), but it is mounted sideways: the folded Duo is
/// held landscape, the same way round as the top half of the open screen, with the panel's top
/// edge on the viewer's left. The app is portrait-locked for the open screen, so the system won't
/// rotate the cover for us: this lays the content out landscape and turns it a quarter clockwise
/// so it reads upright. The turn is fixed by how the panel is mounted; the reported device
/// orientation flips between launches in the simulator, so it isn't used.
struct CoverDisplay<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isPanelPortrait = size.height > size.width
            content
                .frame(width: isPanelPortrait ? size.height : size.width, height: isPanelPortrait ? size.width : size.height)
                .rotationEffect(.degrees(isPanelPortrait ? angle : 0))
                .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }

    /// A quarter turn clockwise: the panel's top edge sits on the viewer's left.
    private let angle: Double = 90
}

/// The folded cover's layout: the cover is the back of the open screen's top half, so the oven
/// (`OvenFrame`) fills all of it, edge to edge, with the caption laid over its bottom band.
struct CoverStage<Oven: View, Caption: View>: View {
    @ViewBuilder let oven: Oven
    @ViewBuilder let caption: Caption

    var body: some View {
        oven
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                caption
                    .padding(.horizontal, Spacing.margin)
                    .padding(.bottom, Spacing.s3)
            }
    }
}
