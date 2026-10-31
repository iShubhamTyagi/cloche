import SwiftUI

/// The faint 4 pt dot grid laid over every dark screen.
public struct GrainOverlay: View {
    private static let pitch: CGFloat = 4
    private static let dotRadius: CGFloat = 0.6

    public init() {}

    public var body: some View {
        Canvas { context, size in
            var dots = Path()
            var y = Self.pitch / 2
            while y < size.height {
                var x = Self.pitch / 2
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x - Self.dotRadius, y: y - Self.dotRadius, width: Self.dotRadius * 2, height: Self.dotRadius * 2))
                    x += Self.pitch
                }
                y += Self.pitch
            }
            context.fill(dots, with: .color(Palette.text.opacity(0.05)))
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public extension View {
    /// Standard dark screen: ground colour edge to edge with grain on top.
    func pocketScreenBackground() -> some View {
        background {
            ZStack {
                Palette.ground
                GrainOverlay()
            }
            .ignoresSafeArea()
        }
    }
}
