import CoreGraphics

/// Spacing, radius and hit-target tokens from the design handoff.
public enum Spacing {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let margin: CGFloat = 24
}

public enum Radius {
    public static let card: CGFloat = 28
    public static let tile: CGFloat = 14
    public static let chip: CGFloat = 12
}

public enum HitTarget {
    /// Minimum height and width for every control.
    public static let minimum: CGFloat = 44
}
