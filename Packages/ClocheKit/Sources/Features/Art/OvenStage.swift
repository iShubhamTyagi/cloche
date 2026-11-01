import DesignSystem
import SwiftUI

/// The shared stage: a header slot and the oven in the top half, content in the bottom half.
/// Prep (iPhone and the Duo's inner screen) and the Duo's cover screens all use it, so when the
/// phone folds the oven keeps its place, size and orientation: you just see it from outside.
struct OvenStage<Header: View, Oven: View, Content: View>: View {
    /// Caps the stage width so the oven is about the same physical size on every screen
    /// (the Duo's inner screen is wider than its cover).
    static var maxWidth: CGFloat { 440 }

    @ViewBuilder let header: Header
    @ViewBuilder let oven: Oven
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                        .frame(maxWidth: .infinity)
                        .frame(height: HitTarget.minimum)
                    oven
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: proxy.size.height / 2)
                content
                    .frame(height: proxy.size.height / 2)
            }
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.s2)
        .frame(maxWidth: Self.maxWidth)
        .frame(maxWidth: .infinity)
    }
}
