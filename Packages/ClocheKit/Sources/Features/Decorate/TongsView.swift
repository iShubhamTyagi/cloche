import SwiftUI

/// Kitchen tongs, hanging tips down from a hinge at the top. `grip` 0 has the arms open,
/// 1 closed on a dish of `span` points across. The tips sit at the bottom centre of the frame.
struct TongsView: View {
    /// Width of what the tongs close on.
    let span: CGFloat
    var grip: Double = 0

    var body: some View {
        Canvas { context, size in
            let hinge = CGPoint(x: size.width / 2, y: 0)
            let tipY = size.height
            // Open, the tips spread past the dish; closed, they touch its sides.
            let spread = span / 2 + (1 - grip) * span * 0.35
            let steel = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color(white: 0.85), Color(white: 0.55)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
            )
            for side in [-1.0, 1.0] {
                let tip = CGPoint(x: hinge.x + side * spread, y: tipY)
                var arm = Path()
                arm.move(to: CGPoint(x: hinge.x + side * 3, y: hinge.y))
                arm.addQuadCurve(to: tip, control: CGPoint(x: hinge.x + side * spread * 0.35, y: tipY * 0.55))
                context.stroke(arm, with: steel, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                // Scalloped grip pad at the tip, turned in toward the dish.
                let pad = CGRect(x: tip.x - (side > 0 ? 9 : 3), y: tip.y - 14, width: 12, height: 16)
                context.fill(Path(roundedRect: pad, cornerRadius: 4), with: .color(Color(white: 0.7)))
            }
            // Hinge loop.
            context.stroke(Path(ellipseIn: CGRect(x: hinge.x - 7, y: hinge.y - 7, width: 14, height: 14)), with: .color(Color(white: 0.7)), lineWidth: 3)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 40) {
        TongsView(span: 80, grip: 0).frame(width: 160, height: 220)
        TongsView(span: 80, grip: 1).frame(width: 160, height: 220)
    }
    .padding()
    .background(Color.black)
}
