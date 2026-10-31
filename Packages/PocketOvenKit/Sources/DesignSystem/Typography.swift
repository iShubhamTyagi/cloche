import SwiftUI

/// Type tokens. System sans and New York serif stand in until Instrument Sans and
/// Newsreader are bundled in Phase 1.1.
public enum Typography {
    public static let voice = Font.system(size: 22, weight: .regular, design: .serif).italic()
    public static let title = Font.system(size: 42, weight: .light, design: .serif).italic()
    public static let eyebrow = Font.system(size: 11, weight: .regular)
}
