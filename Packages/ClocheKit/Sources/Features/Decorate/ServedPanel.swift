import Decorating
import DesignSystem
import Domain
import SwiftUI
import UIKit

/// The panel under the cake once it is served: its stars, a time-lapse of how it was made, a share
/// image, and Done. The cake itself stays on the turntable above.
struct ServedPanel: View {
    let model: DecorStudioModel
    let grade: Grade
    let onDone: () -> Void

    @State private var replayTask: Task<Void, Never>?
    @State private var snapshot: UIImage?

    var body: some View {
        VStack(spacing: Spacing.s3) {
            Stars(earned: grade.stars)
                .accessibilityElement()
                .accessibilityLabel(Text("\(grade.stars) stars", bundle: .module))
            HStack(spacing: Spacing.s3) {
                Button(action: replay) {
                    Text("Replay", bundle: .module)
                }
                .buttonStyle(.outline)
                .accessibilityHint(Text("Watch the cake being decorated again", bundle: .module))
                if let snapshot {
                    ShareLink(item: Image(uiImage: snapshot), preview: SharePreview(Text("My cake", bundle: .module), image: Image(uiImage: snapshot))) {
                        Text("Share", bundle: .module)
                    }
                    .buttonStyle(.outline)
                }
            }
            Button(action: onDone) {
                Text("Done", bundle: .module)
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("served.done")
        }
        .task { snapshot = CakeSnapshot.image(of: model.dressing, cream: model.cream, side: 1080) }
        .onDisappear { replayTask?.cancel() }
        .accessibilityIdentifier("served.screen")
    }

    private func replay() {
        replayTask?.cancel()
        let model = model
        replayTask = Task { await model.replay() }
    }
}

/// A flat, top-down picture of a cake for sharing: the plate, the cream, the beads and toppings.
enum CakeSnapshot {
    @MainActor
    static func image(of dressing: CakeDressing, cream: CreamField, side: CGFloat) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let g = dressing.geometry
        func colour(_ index: Int) -> UIColor {
            let (r, gr, b) = ViewerAssets.palette[index].rgb
            return UIColor(red: CGFloat(r) / 255, green: CGFloat(gr) / 255, blue: CGFloat(b) / 255, alpha: 1)
        }
        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.055, green: 0.055, blue: 0.05, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let plate = side * 0.92
            UIColor(white: 0.93, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: (side - plate) / 2, y: (side - plate) / 2, width: plate, height: plate))
            let mmToPx = plate / CGFloat(g.plateRadius * 2)
            func dot(radius: Float, angle: Float, size: CGFloat) {
                let x = side / 2 + CGFloat(radius * cos(angle)) * mmToPx
                let y = side / 2 - CGFloat(radius * sin(angle)) * mmToPx
                cg.fillEllipse(in: CGRect(x: x - size * mmToPx / 2, y: y - size * mmToPx / 2, width: size * mmToPx, height: size * mmToPx))
            }
            UIColor(red: 0.8, green: 0.55, blue: 0.27, alpha: 1).setFill()
            dot(radius: 0, angle: 0, size: CGFloat(g.radius * 2))
            if let top = creamImage(cream, reach: g.radius) {
                let size = CGFloat(g.radius * 2) * mmToPx
                top.draw(in: CGRect(x: (side - size) / 2, y: (side - size) / 2, width: size, height: size))
            }
            for (key, value) in dressing.beads {
                colour(value).setFill()
                dot(radius: g.radius(of: key.ring), angle: g.angle(of: key.slot, on: key.ring), size: CGFloat(g.beadDiameter))
            }
            for p in dressing.placements {
                ToppingColour.of(p.kind, variant: p.variant).setFill()
                dot(radius: p.at.a, angle: p.at.b, size: p.kind == "sprinkle" ? 1.6 : 10)
            }
        }
    }
}

private func creamImage(_ cream: CreamField, reach: Float) -> UIImage? {
    let side = 512
    let bytes = cream.topView(side: side, reach: reach)
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                              space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                              provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
    return UIImage(cgImage: image)
}

@MainActor
enum ToppingColour {
    static func of(_ kind: String, variant: Int) -> UIColor {
        switch kind {
        case "raspberry", "strawberry_slice": UIColor(red: 0.56, green: 0.06, blue: 0.16, alpha: 1)
        case "blueberry": UIColor(red: 0.11, green: 0.13, blue: 0.25, alpha: 1)
        case "cherry": UIColor(red: 0.43, green: 0.04, blue: 0.09, alpha: 1)
        case "mint_leaf": UIColor(red: 0.16, green: 0.37, blue: 0.14, alpha: 1)
        case "chocolate_curl", "chocolate_shard": UIColor(red: 0.18, green: 0.1, blue: 0.07, alpha: 1)
        case "gold_flake": UIColor(red: 0.91, green: 0.76, blue: 0.42, alpha: 1)
        case "sugar_pearl": UIColor(white: 0.95, alpha: 1)
        case "pistachio_crumb": UIColor(red: 0.42, green: 0.54, blue: 0.16, alpha: 1)
        case "almond_flake": UIColor(red: 0.92, green: 0.85, blue: 0.71, alpha: 1)
        case "flower_petal": UIColor(red: 0.85, green: 0.44, blue: 0.56, alpha: 1)
        case "sprinkle": ToppingFactory.sprinkleColours[variant % ToppingFactory.sprinkleColours.count]
        default: UIColor(white: 0.8, alpha: 1)
        }
    }
}
