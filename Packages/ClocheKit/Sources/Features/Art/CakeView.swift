import DesignSystem
import Domain
import SwiftUI

/// Code-drawn round cake, one or two tiers, on an optional plate. Placeholder art until the
/// 3D assets land. Bake progress raises the sponge and moves it from batter to the browning tone.
struct CakeView: View {
    var tiers = 1
    var progress: Double = 1
    var browning: Browning = .golden
    var icing: FoodPalette.Icing?
    var showsPlate = false

    var body: some View {
        Canvas { context, size in
            let d = showsPlate ? min(size.width / 1.2, size.height / 1.07) : min(size.width, size.height)
            let origin = CGPoint(x: (size.width - d) / 2, y: (size.height - d) / 2)
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: origin.x + d * x, y: origin.y + d * y)
            }

            if showsPlate {
                let c = point(0.5, 0.88)
                let plate = CGRect(x: c.x - d * 0.6, y: c.y - d * 0.135, width: d * 1.2, height: d * 0.27)
                context.fill(Path(ellipseIn: plate), with: .color(Color(red: 0.91, green: 0.87, blue: 0.81)))
                context.fill(Path(ellipseIn: plate.insetBy(dx: plate.width * 0.14, dy: plate.height * 0.14)), with: .color(Color(red: 0.84, green: 0.79, blue: 0.71)))
            }

            let p = min(max(progress, 0), 1)
            let rise = 0.8 + 0.2 * p
            // Bottom tier, then an optional smaller tier on top.
            var base = 0.86
            let shapes: [(width: Double, height: Double)] = tiers > 1 ? [(0.86, 0.30), (0.56, 0.24)] : [(0.80, 0.34)]
            for shape in shapes {
                let height = shape.height * rise
                drawTier(in: &context, centerX: 0.5, base: base, width: shape.width, height: height, point: point, d: d)
                base -= height
            }
        }
        .accessibilityHidden(true)
    }

    private func drawTier(in context: inout GraphicsContext, centerX: Double, base: Double, width: Double, height: Double, point: (Double, Double) -> CGPoint, d: CGFloat) {
        let left = centerX - width / 2
        let ellipseHeight = width * 0.24
        let top = base - height

        // Shadow, side, top.
        context.fill(Path(ellipseIn: CGRect(origin: point(left - 0.02, base - ellipseHeight / 2 + 0.02), size: CGSize(width: d * (width + 0.04), height: d * ellipseHeight))), with: .color(.black.opacity(0.25)))
        var side = Path()
        side.addRect(CGRect(origin: point(left, top), size: CGSize(width: d * width, height: d * height)))
        side.addEllipse(in: CGRect(origin: point(left, base - ellipseHeight / 2), size: CGSize(width: d * width, height: d * ellipseHeight)))
        context.fill(side, with: .color(crust.color))
        context.fill(Path(CGRect(origin: point(left, top), size: CGSize(width: d * width * 0.18, height: d * height))), with: .color(.white.opacity(0.08)))

        let topRect = CGRect(origin: point(left, top - ellipseHeight / 2), size: CGSize(width: d * width, height: d * ellipseHeight))
        context.fill(Path(ellipseIn: topRect), with: .color(icing?.color ?? crust.mixed(with: ArtColor(0xFFFFFF), 0.12).color))
        if icing != nil {
            // Drips over the edge.
            for index in 0..<7 {
                let x = left + width * (0.08 + 0.84 * Double(index) / 6)
                let length = height * (index.isMultiple(of: 2) ? 0.35 : 0.22)
                context.fill(Path(roundedRect: CGRect(origin: point(x - 0.025, top), size: CGSize(width: d * 0.05, height: d * length)), cornerRadius: d * 0.025), with: .color(icing?.color ?? .clear))
            }
        }
    }

    private var crust: ArtColor {
        let raw = ArtColor(0xEBDDBE)
        let target: ArtColor = switch browning {
        case .pale: ArtColor(0xE4C98F)
        case .golden: ArtColor(0xCC8A3E)
        case .dark: ArtColor(0x5E3115)
        }
        let p = min(max(progress, 0), 1)
        return raw.mixed(with: target, p * p * (3 - 2 * p))
    }
}

#Preview {
    HStack {
        CakeView(tiers: 1, progress: 0.2, browning: .pale)
        CakeView(tiers: 1)
        CakeView(tiers: 2, icing: .rose, showsPlate: true)
    }
    .frame(height: 140)
    .padding()
    .pocketScreenBackground()
}
