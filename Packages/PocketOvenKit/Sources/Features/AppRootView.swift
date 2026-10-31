import DesignSystem
import SwiftUI

/// Entry screen. Replaced by the Prep screen in Phase 1.4.
public struct AppRootView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()
            VStack(spacing: Spacing.s3) {
                Text("Pocket Oven", bundle: .module)
                    .font(Typography.title)
                    .foregroundStyle(Palette.text)
                    .accessibilityIdentifier("root.title")
                Text("Closed to commit, open to create.", bundle: .module)
                    .font(Typography.voice)
                    .foregroundStyle(Palette.sand)
            }
            .padding(.horizontal, Spacing.margin)
        }
    }
}

#Preview {
    AppRootView()
}
