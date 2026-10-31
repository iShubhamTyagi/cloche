import SwiftUI

/// Type tokens from the design handoff. Instrument Sans for the interface, Newsreader for
/// numerals and the italic "voice". Falls back to system sans and New York if a font is missing.
public struct TextStyle: Sendable, Equatable {
    public enum Family: Sendable, Equatable {
        case sans
        case serif
    }

    public let family: Family
    public let size: CGFloat
    /// Design line height in points; nil means the font's natural height.
    public let lineHeight: CGFloat?
    public let weight: Font.Weight
    public let isItalic: Bool
    /// Letter spacing as a fraction of the font size (CSS `em`).
    public let trackingEm: CGFloat
    public let isUppercase: Bool
    /// Helper text, tabs, chips and buttons scale; numerals and hero lines stay fixed.
    public let scalesWithDynamicType: Bool
    public let usesTabularDigits: Bool

    /// Letter spacing in points.
    public var tracking: CGFloat { trackingEm * size }

    /// Extra space between lines to reach the design line height. Fonts render at roughly
    /// 1.2 × size by default, so only the remainder is added.
    public var lineSpacing: CGFloat {
        guard let lineHeight else { return 0 }
        return max(0, lineHeight - size * 1.2)
    }

    public var font: Font {
        let availability = FontRegistrar.availability
        var font: Font
        switch family {
        case .sans where availability.sans:
            font = custom(FontRegistrar.sansFamily)
        case .serif where availability.serif:
            font = custom(FontRegistrar.serifFamily)
        case .sans:
            font = .system(size: size)
        case .serif:
            font = .system(size: size, design: .serif)
        }
        font = font.weight(weight)
        if isItalic { font = font.italic() }
        if usesTabularDigits { font = font.monospacedDigit() }
        return font
    }

    private func custom(_ name: String) -> Font {
        scalesWithDynamicType
            ? .custom(name, size: size, relativeTo: .body)
            : .custom(name, fixedSize: size)
    }
}

public extension TextStyle {
    /// Sans 11, caps, tracking 0.14em. Labels above values.
    static let eyebrow = TextStyle(family: .sans, size: 11, lineHeight: nil, weight: .regular, isItalic: false, trackingEm: 0.14, isUppercase: true, scalesWithDynamicType: true, usesTabularDigits: false)
    /// Sans 15/22. Helper paragraphs.
    static let body = TextStyle(family: .sans, size: 15, lineHeight: 22, weight: .regular, isItalic: false, trackingEm: 0, isUppercase: false, scalesWithDynamicType: true, usesTabularDigits: false)
    /// Sans 13. Notes under buttons.
    static let note = TextStyle(family: .sans, size: 13, lineHeight: nil, weight: .regular, isItalic: false, trackingEm: 0, isUppercase: false, scalesWithDynamicType: true, usesTabularDigits: false)
    /// Sans 17/600, tracking 0.02em. Primary button.
    static let button = TextStyle(family: .sans, size: 17, lineHeight: nil, weight: .semibold, isItalic: false, trackingEm: 0.02, isUppercase: false, scalesWithDynamicType: true, usesTabularDigits: false)
    /// Sans 14/500. Tabs, chips, text buttons.
    static let control = TextStyle(family: .sans, size: 14, lineHeight: nil, weight: .medium, isItalic: false, trackingEm: 0, isUppercase: false, scalesWithDynamicType: true, usesTabularDigits: false)
    /// Serif italic 300, 76/80, tracking -0.02em. "Prêt."
    static let hero = TextStyle(family: .serif, size: 76, lineHeight: 80, weight: .light, isItalic: true, trackingEm: -0.02, isUppercase: false, scalesWithDynamicType: false, usesTabularDigits: false)
    /// Serif italic 300, 42/46. Screen headlines.
    static let title = TextStyle(family: .serif, size: 42, lineHeight: 46, weight: .light, isItalic: true, trackingEm: 0, isUppercase: false, scalesWithDynamicType: false, usesTabularDigits: false)
    /// Serif 400, 32/36. Dish name.
    static let name = TextStyle(family: .serif, size: 32, lineHeight: 36, weight: .regular, isItalic: false, trackingEm: -0.01, isUppercase: false, scalesWithDynamicType: false, usesTabularDigits: false)

    /// Serif 300 with tabular figures. Bake timer and countdowns, up to 88 pt.
    static func numeral(_ size: CGFloat) -> TextStyle {
        TextStyle(family: .serif, size: size, lineHeight: size, weight: .light, isItalic: false, trackingEm: 0, isUppercase: false, scalesWithDynamicType: false, usesTabularDigits: true)
    }

    /// Serif italic, 15 to 22. Captions, grade lines, the wordmark.
    static func voice(_ size: CGFloat) -> TextStyle {
        TextStyle(family: .serif, size: size, lineHeight: nil, weight: .regular, isItalic: true, trackingEm: 0, isUppercase: false, scalesWithDynamicType: true, usesTabularDigits: false)
    }

    /// Variant with a different size, for the per-screen sizes in the handoff (e.g. title 38 on ajar).
    func sized(_ newSize: CGFloat, lineHeight newLineHeight: CGFloat? = nil) -> TextStyle {
        TextStyle(family: family, size: newSize, lineHeight: newLineHeight, weight: weight, isItalic: isItalic, trackingEm: trackingEm, isUppercase: isUppercase, scalesWithDynamicType: scalesWithDynamicType, usesTabularDigits: usesTabularDigits)
    }
}

private struct TextStyleModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .textCase(style.isUppercase ? .uppercase : nil)
    }
}

public extension View {
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
