import DesignSystem
import SwiftUI

/// The plating station: a counter under a warm light, an empty cake stand in the middle and a
/// glass cloche set down beside it, waiting for the serve. Like `OvenFrame` it fills whatever
/// slot it is given, so the 3D asset can replace it; the dish itself is drawn by the screen on
/// top, at `servingFrame`.
struct PlatingStationView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = Layout(size: size)
            ZStack(alignment: .topLeading) {
                wall
                light(layout)
                counter(layout)
                cakeStand(layout)
                cloche(layout)
            }
            .frame(width: size.width, height: size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Finishing table", bundle: .module))
    }

    /// Where a serving of `side` points sits on the stand, in a slot of `size`. The dish art
    /// stands on the bottom ~17% of its frame, so the frame dips below the plate's top edge.
    static func servingFrame(side: CGFloat, in size: CGSize) -> CGRect {
        let layout = Layout(size: size)
        return CGRect(x: layout.standX - side / 2, y: layout.plateY - side * 0.83, width: side, height: side)
    }

    /// The largest serving that fits the stand.
    static func servingSide(in size: CGSize) -> CGFloat {
        let layout = Layout(size: size)
        return min(layout.plateWidth * 0.78, size.height * 0.42)
    }

    // MARK: Layout

    private struct Layout {
        let size: CGSize
        var counterY: CGFloat { size.height * 0.8 }
        var standX: CGFloat { size.width * 0.44 }
        var plateWidth: CGFloat { min(size.width * 0.46, size.height * 0.62) }
        var plateY: CGFloat { counterY - plateWidth * 0.36 }
        var clocheX: CGFloat { size.width * 0.82 }
        var clocheWidth: CGFloat { min(size.width * 0.24, size.height * 0.34) }
    }

    // MARK: Pieces

    private var wall: some View {
        LinearGradient(colors: [Color(white: 0.09), Color(red: 0.07, green: 0.06, blue: 0.05)], startPoint: .top, endPoint: .bottom)
    }

    /// A pool of warm light over the stand.
    private func light(_ layout: Layout) -> some View {
        RadialGradient(colors: [Palette.accent.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: layout.plateWidth)
            .frame(width: layout.plateWidth * 2, height: layout.plateWidth * 2)
            .position(x: layout.standX, y: layout.plateY - layout.plateWidth * 0.2)
    }

    private func counter(_ layout: Layout) -> some View {
        let height = layout.size.height - layout.counterY
        return Rectangle()
            .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.1)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.18)).frame(height: 1) }
            .frame(width: layout.size.width, height: height)
            .offset(y: layout.counterY)
    }

    /// Plate on a stem on a round foot, in porcelain.
    private func cakeStand(_ layout: Layout) -> some View {
        let w = layout.plateWidth
        let porcelain = Color(red: 0.91, green: 0.88, blue: 0.83)
        let shade = Color(red: 0.74, green: 0.70, blue: 0.64)
        return ZStack {
            // Shadow on the counter.
            Ellipse().fill(.black.opacity(0.35))
                .frame(width: w * 0.62, height: w * 0.07)
                .position(x: layout.standX, y: layout.counterY + w * 0.01)
            // Foot.
            Ellipse().fill(LinearGradient(colors: [porcelain, shade], startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.5, height: w * 0.08)
                .position(x: layout.standX, y: layout.counterY - w * 0.02)
            // Stem, narrowing to the plate.
            Path { path in
                let top = layout.plateY + w * 0.03
                let bottom = layout.counterY - w * 0.03
                path.move(to: CGPoint(x: layout.standX - w * 0.05, y: top))
                path.addLine(to: CGPoint(x: layout.standX + w * 0.05, y: top))
                path.addLine(to: CGPoint(x: layout.standX + w * 0.09, y: bottom))
                path.addLine(to: CGPoint(x: layout.standX - w * 0.09, y: bottom))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [shade, porcelain, shade], startPoint: .leading, endPoint: .trailing))
            // Plate: rim and top.
            Ellipse().fill(shade)
                .frame(width: w, height: w * 0.13)
                .position(x: layout.standX, y: layout.plateY + w * 0.02)
            Ellipse().fill(LinearGradient(colors: [porcelain, Color(red: 0.84, green: 0.80, blue: 0.74)], startPoint: .top, endPoint: .bottom))
                .frame(width: w, height: w * 0.11)
                .position(x: layout.standX, y: layout.plateY)
        }
    }

    /// A glass dome with a knob, resting on its rim on the counter.
    private func cloche(_ layout: Layout) -> some View {
        let w = layout.clocheWidth
        let h = w * 0.82
        let base = layout.counterY
        return ZStack {
            Ellipse().fill(.black.opacity(0.3))
                .frame(width: w * 1.05, height: w * 0.08)
                .position(x: layout.clocheX, y: base + w * 0.01)
            Dome()
                .fill(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Dome().stroke(.white.opacity(0.35), lineWidth: 1.2))
                .frame(width: w, height: h)
                .position(x: layout.clocheX, y: base - h / 2)
            // Glint.
            Capsule().fill(.white.opacity(0.35))
                .frame(width: w * 0.05, height: h * 0.32)
                .rotationEffect(.degrees(28))
                .position(x: layout.clocheX - w * 0.26, y: base - h * 0.62)
            // Knob.
            Capsule().fill(Color(white: 0.75))
                .frame(width: w * 0.16, height: w * 0.07)
                .position(x: layout.clocheX, y: base - h - w * 0.02)
            // Rim.
            Capsule().fill(.white.opacity(0.4))
                .frame(width: w * 1.02, height: 2)
                .position(x: layout.clocheX, y: base - 1)
        }
    }
}

/// A cloche's outline: straight sides rounding into a domed top.
private struct Dome: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.55))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.55),
            control1: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY - rect.height * 0.12),
            control2: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY - rect.height * 0.12)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview {
    PlatingStationView()
        .frame(width: 402, height: 437)
}
