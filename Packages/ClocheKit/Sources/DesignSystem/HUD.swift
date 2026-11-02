import SwiftUI

extension EnvironmentValues {
    /// The content is shown as a heads-up display on glass (the oven door on the open Duo):
    /// controls drop their solid fills for hairline outlines and a soft glow, in the same ivory,
    /// sand and honey. Set by the screen that lays content on glass.
    @Entry public var isHUD = false
}

/// HUD dressing for a pane of glass: corner brackets, a hairline inner frame, faint scan lines
/// and two edge ticks, all in the interface's own ivory and sand. Decorative only.
public struct HUDGlassChrome: View {
    public init() {}

    public var body: some View {
        GeometryReader { box in
            let w = box.size.width, h = box.size.height
            let arm = min(w, h) * 0.08
            ZStack {
                // Scan lines, very faint.
                Path { path in
                    var y: CGFloat = 0
                    while y < h {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                        y += 4
                    }
                }
                .stroke(Palette.text.opacity(0.025), lineWidth: 1)
                RoundedRectangle(cornerRadius: Radius.tile)
                    .strokeBorder(Palette.line1, lineWidth: 1)
                    .padding(Spacing.s2)
                // Corner brackets.
                Path { path in
                    let inset = Spacing.s1
                    for (x, y, sx, sy) in [(inset, inset, 1.0, 1.0), (w - inset, inset, -1.0, 1.0),
                                           (w - inset, h - inset, -1.0, -1.0), (inset, h - inset, 1.0, -1.0)] {
                        path.move(to: CGPoint(x: x + sx * arm, y: y))
                        path.addLine(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + sy * arm))
                    }
                }
                .stroke(Palette.sand.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
                .shadow(color: Palette.sand.opacity(0.5), radius: 4)
                // Edge ticks at mid-height.
                Path { path in
                    for x in [Spacing.s1, w - Spacing.s1] {
                        for k in -2...2 {
                            let y = h / 2 + CGFloat(k) * 6
                            path.move(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x + (x < w / 2 ? 1 : -1) * (k == 0 ? 8 : 4), y: y))
                        }
                    }
                }
                .stroke(Palette.sand.opacity(0.5), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The HUD form of the primary action: an outlined, glowing ivory pill on dark glass.
struct HUDPrimaryLook: View {
    let label: ButtonStyleConfiguration.Label
    let isPressed: Bool

    var body: some View {
        label
            .textStyle(.button)
            .foregroundStyle(Palette.accent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.margin)
            .frame(maxWidth: .infinity, minHeight: ButtonMetrics.primaryHeight)
            .background(
                Capsule()
                    .fill(Palette.accent.opacity(isPressed ? 0.22 : 0.10))
                    .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.85), lineWidth: 1.5))
                    .shadow(color: Palette.accent.opacity(0.45), radius: 10)
            )
            .shadow(color: Palette.accent.opacity(0.5), radius: 3)
            .contentShape(Capsule())
    }
}
