import SwiftUI

/// Full-width ivory pill. One per screen, for the main action.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.button)
            .foregroundStyle(Palette.ground)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.margin)
            .frame(maxWidth: .infinity, minHeight: ButtonMetrics.primaryHeight)
            // Glow sits on the pill alone; on the whole view it would ghost the label text.
            .background(
                Capsule()
                    .fill(Palette.accent)
                    .shadow(color: Palette.accent.opacity(0.28), radius: 15, y: 10)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .contentShape(Capsule())
    }
}

/// Outlined pill. `.standard` for "Done"; `.locked` for "Part of the Full Kitchen".
public struct OutlineButtonStyle: ButtonStyle {
    public enum Tone: Sendable {
        case standard
        case locked
    }

    private let tone: Tone

    public init(tone: Tone = .standard) {
        self.tone = tone
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(tone == .locked ? .button.sized(16) : .button)
            .foregroundStyle(tone == .locked ? Palette.sand : Palette.text)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.margin)
            .frame(maxWidth: .infinity, minHeight: tone == .locked ? ButtonMetrics.primaryHeight : ButtonMetrics.outlineHeight)
            .overlay(Capsule().strokeBorder(tone == .locked ? Palette.sand.opacity(0.55) : Palette.line3, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// Plain text action such as "Serve plain" or "Close the door another way".
public struct TextButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.control)
            .foregroundStyle(Palette.text)
            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            .padding(.horizontal, Spacing.s2)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
    static var locked: OutlineButtonStyle { OutlineButtonStyle(tone: .locked) }
}

public extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
}
