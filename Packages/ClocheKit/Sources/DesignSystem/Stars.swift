import SwiftUI

/// Up to two stars: bake and serve. Earned stars are filled sand; the rest are
/// outlines, so the difference never depends on colour alone.
public struct Stars: View {
    nonisolated public static let total = 2

    private let earned: Int
    private let size: CGFloat

    public init(earned: Int, size: CGFloat = 34) {
        self.earned = Self.clamped(earned)
        self.size = size
    }

    nonisolated static func clamped(_ count: Int) -> Int {
        min(max(count, 0), total)
    }

    public var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<Self.total, id: \.self) { index in
                let isEarned = index < earned
                StarShape()
                    .fill(isEarned ? Palette.sand : .clear)
                    .overlay(StarShape().stroke(isEarned ? Palette.sand : Palette.subtle, lineWidth: 1))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(earned) of \(Self.total) stars", bundle: .module))
    }
}

/// Five-pointed star with softened proportions.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.04)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var path = Path()
        for point in 0..<10 {
            let radius = point.isMultiple(of: 2) ? outer : inner
            let angle = Double(point) * .pi / 5 - .pi / 2
            let vertex = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if point == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
        }
        path.closeSubpath()
        return path
    }
}
