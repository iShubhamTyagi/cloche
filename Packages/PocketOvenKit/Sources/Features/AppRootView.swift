import DesignSystem
import SwiftUI

/// Entry screen. Replaced by the Prep screen in Phase 1.4.
public struct AppRootView: View {
    private let showsComponentGallery: Bool

    /// - Parameter showsComponentGallery: debug-only design check; ignored in release builds.
    public init(showsComponentGallery: Bool = false) {
        self.showsComponentGallery = showsComponentGallery
    }

    public var body: some View {
        #if DEBUG
        if showsComponentGallery {
            ComponentGallery()
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.s3) {
            Text("Pocket Oven", bundle: .module)
                .textStyle(.title)
                .foregroundStyle(Palette.text)
                .accessibilityIdentifier("root.title")
            Text("Closed to commit, open to create.", bundle: .module)
                .textStyle(.voice(22))
                .foregroundStyle(Palette.sand)
        }
        .padding(.horizontal, Spacing.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pocketScreenBackground()
    }
}

#Preview {
    AppRootView()
}
