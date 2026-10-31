import Foundation

/// Wall-clock source for every stored end timestamp. Injected so tests control time.
/// Named to avoid clashing with the standard library's `Clock`.
public protocol TimeProviding: Sendable {
    var now: Date { get }
}

public struct SystemTimeProvider: TimeProviding {
    public init() {}

    public var now: Date { Date() }
}
