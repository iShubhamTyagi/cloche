import SwiftUI

/// Small caps label that sits above a value or section ("Preheating", "Fresh from the oven").
public struct EyebrowLabel: View {
    private let text: Text

    public init(_ text: Text) {
        self.text = text
    }

    public var body: some View {
        text
            .textStyle(.eyebrow)
            .foregroundStyle(Palette.muted)
    }
}
