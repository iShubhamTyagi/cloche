import SwiftUI
import UIKit

/// Serving tongs: the Cycles renders from `tableware.py`, hanging from above. `grip` 0 is open,
/// 1 closed on a dish of `span` points across.
struct TongsView: View {
    /// Width of what the tongs close on.
    let span: CGFloat
    var grip: Double = 0

    /// The closed tips' gap, as a share of the image's width.
    private static let gap: CGFloat = 0.27
    /// Where the tips are, down the image.
    static let tipShare: CGFloat = 0.83

    /// The side of the square image for a dish of `span`.
    static func side(span: CGFloat) -> CGFloat { span / gap }

    var body: some View {
        ZStack {
            Self.image("tongs_open")?.resizable().opacity(1 - grip)
            Self.image("tongs_closed")?.resizable().opacity(grip)
        }
        .accessibilityHidden(true)
    }

    private static func image(_ name: String) -> Image? {
        Bundle.module.url(forResource: name, withExtension: "png")
            .flatMap { UIImage(contentsOfFile: $0.path) }
            .map(Image.init(uiImage:))
    }
}
