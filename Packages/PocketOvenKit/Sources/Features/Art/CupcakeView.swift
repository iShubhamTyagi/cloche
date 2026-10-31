import DesignSystem
import Domain
import SwiftUI

/// Code-drawn cupcake on an optional plate. Bake progress raises the dome and moves the crust
/// from raw to the browning tone. A first pass for Gate 0; refined with the other dishes in 2.2.
struct CupcakeView: View {
    var progress: Double = 1
    var browning: Browning = .golden
    var icing: FoodPalette.Icing?
    var showsPlate = false

    var body: some View {
        Canvas { context, size in
            // The plate is 1.2 × the dish, so the dish shrinks to keep the plate inside the frame.
            let d = showsPlate ? min(size.width / 1.2, size.height / 1.07) : min(size.width, size.height)
            let origin = CGPoint(x: (size.width - d) / 2, y: (size.height - d) / 2 - d * 0.08)
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: origin.x + d * x, y: origin.y + d * y)
            }

            if showsPlate {
                let plateCenter = point(0.5, 0.93)
                let plate = CGRect(x: plateCenter.x - d * 0.6, y: plateCenter.y - d * 0.135, width: d * 1.2, height: d * 0.27)
                context.fill(Path(ellipseIn: plate), with: .color(Color(red: 0.91, green: 0.87, blue: 0.81)))
                context.fill(Path(ellipseIn: plate.insetBy(dx: plate.width * 0.14, dy: plate.height * 0.14)), with: .color(Color(red: 0.84, green: 0.79, blue: 0.71)))
            }

            // Shadow under the liner.
            context.fill(Path(ellipseIn: CGRect(origin: point(0.24, 0.86), size: CGSize(width: d * 0.52, height: d * 0.07))), with: .color(.black.opacity(0.3)))

            // Paper liner with pleats.
            var liner = Path()
            liner.move(to: point(0.22, 0.56))
            liner.addLine(to: point(0.78, 0.56))
            liner.addLine(to: point(0.70, 0.89))
            liner.addLine(to: point(0.30, 0.89))
            liner.closeSubpath()
            context.fill(liner, with: .color(Color(red: 0.93, green: 0.89, blue: 0.82)))
            for index in 1..<8 {
                let t = Double(index) / 8
                var pleat = Path()
                pleat.move(to: point(0.22 + 0.56 * t, 0.56))
                pleat.addLine(to: point(0.30 + 0.40 * t, 0.89))
                context.stroke(pleat, with: .color(.black.opacity(0.08)), lineWidth: d * 0.006)
            }

            // Dome rises with progress.
            let rise = 0.84 + 0.16 * min(max(progress, 0), 1)
            let top = 0.56 - 0.26 * rise
            var dome = Path()
            dome.move(to: point(0.19, 0.58))
            dome.addCurve(to: point(0.5, top), control1: point(0.17, top + 0.12), control2: point(0.32, top))
            dome.addCurve(to: point(0.81, 0.58), control1: point(0.68, top), control2: point(0.83, top + 0.12))
            dome.closeSubpath()
            context.fill(dome, with: .color(crust.color))
            context.fill(Path(ellipseIn: CGRect(origin: point(0.32, top + 0.04), size: CGSize(width: d * 0.18, height: d * 0.07))), with: .color(.white.opacity(0.18)))

            if let icing {
                drawFrosting(in: &context, colour: icing.color, top: top, point: point, d: d)
            }
        }
        .accessibilityHidden(true)
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

    private func drawFrosting(in context: inout GraphicsContext, colour: Color, top: Double, point: (Double, Double) -> CGPoint, d: CGFloat) {
        let tiers: [(width: Double, y: Double)] = [(0.62, 0.53), (0.48, 0.44), (0.32, 0.36)]
        for tier in tiers {
            let rect = CGRect(x: point(0.5 - tier.width / 2, 0).x, y: point(0, tier.y).y, width: d * tier.width, height: d * 0.13)
            context.fill(Path(roundedRect: rect, cornerRadius: d * 0.065), with: .color(colour))
            context.fill(Path(roundedRect: rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.3).offsetBy(dx: -rect.width * 0.1, dy: -rect.height * 0.15), cornerRadius: d * 0.03), with: .color(.white.opacity(0.22)))
        }
        var tip = Path()
        tip.move(to: point(0.44, 0.37))
        tip.addQuadCurve(to: point(0.5, 0.27), control: point(0.44, 0.29))
        tip.addQuadCurve(to: point(0.56, 0.37), control: point(0.56, 0.29))
        context.fill(tip, with: .color(colour))
    }
}

#Preview {
    HStack {
        CupcakeView(progress: 0.2, browning: .pale)
        CupcakeView(progress: 1)
        CupcakeView(progress: 1, icing: .rose, showsPlate: true)
    }
    .frame(height: 140)
    .padding()
    .pocketScreenBackground()
}
