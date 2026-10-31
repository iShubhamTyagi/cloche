import SwiftUI

/// Rounded status line with a dot that breathes (2.4 s), e.g. "Waiting for the fold".
public struct StatusPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDim = false

    private let text: Text

    public init(_ text: Text) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: Spacing.s2) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 7, height: 7)
                .opacity(isDim ? 0.25 : 1)
                .accessibilityHidden(true)
            text
                .textStyle(.control)
                .foregroundStyle(Palette.text)
        }
        .padding(.horizontal, Spacing.s4)
        .frame(minHeight: 36)
        .overlay(Capsule().strokeBorder(Palette.line2, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isDim = true
            }
        }
    }
}
