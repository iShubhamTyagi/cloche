import DesignSystem
import SwiftUI

/// Shown for a moment on every cold launch, before Prep: "Vanilla cupcakes / Prêt." over the oven,
/// whose door drops open on its bottom hinge to show a tray of finished cupcakes in a warm glow.
/// Reduce Motion: the door is already open and nothing moves.
struct SplashScreen: View {
    /// How long the splash stays before the main screen fades in.
    static let duration: Duration = .seconds(2)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false

    /// The Duo is folded at launch: draw on the cover, landscape and upright like the other cover
    /// screens, with the title beside the oven instead of above it.
    var isOnCover = false

    var body: some View {
        Group {
            if isOnCover {
                CoverDisplay { coverLayout }
            } else {
                openLayout
            }
        }
        .pocketScreenBackground()
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Cloche", bundle: .module))
        .accessibilityIdentifier("splash")
        .onAppear {
            guard !reduceMotion else {
                isOpen = true
                return
            }
            withAnimation(.spring(duration: 0.9, bounce: 0.15).delay(0.25)) {
                isOpen = true
            }
        }
    }

    /// Portrait: title above the oven. The oven grows with the screen, up to the Duo's inner width.
    private var openLayout: some View {
        GeometryReader { screen in
            let ovenWidth = min(screen.size.width - Spacing.margin * 2, Self.maxOvenWidth)
            VStack(spacing: 0) {
                Spacer(minLength: Spacing.margin)
                title
                oven(width: ovenWidth)
                    .padding(.top, Spacing.margin * 2)
                Spacer(minLength: Spacing.margin)
                Spacer(minLength: Spacing.margin)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Landscape cover (678 × 466 pt): title on the left, the oven on the right with its door
    /// hanging below it.
    private var coverLayout: some View {
        GeometryReader { cover in
            // The door drops to about a third of the oven's height below it.
            let ovenWidth = min(cover.size.width * 0.58, (cover.size.height - Spacing.margin * 2) / 1.1)
            HStack(spacing: Spacing.margin) {
                title
                    .frame(maxWidth: .infinity)
                oven(width: ovenWidth)
                    .padding(.bottom, ovenWidth * 0.3)
            }
            .padding(.horizontal, Spacing.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static let maxOvenWidth: CGFloat = 560

    private var title: some View {
        VStack(spacing: Spacing.s2) {
            EyebrowLabel(Text("Vanilla cupcakes", bundle: .module))
            Text("Prêt.", bundle: .module)
                .textStyle(.hero)
                .foregroundStyle(Palette.sand)
        }
        .opacity(isOpen ? 1 : 0)
    }

    private func oven(width: CGFloat) -> some View {
        OvenFrame(
            plate: Text("Prêt.", bundle: .module),
            isPlateItalic: true,
            heat: isOpen ? 1 : 0.4,
            dish: .cupcakes,
            dishProgress: 1,
            doorOpen: isOpen ? 1 : 0,
            openAngle: 130
        )
        .frame(width: width, height: width * 0.78)
        .background(glow(width: width).opacity(isOpen ? 1 : 0.3))
    }

    /// Warm light spilling from the open door onto the counter.
    private func glow(width: CGFloat) -> some View {
        RadialGradient(colors: [FoodPalette.bakeGolden.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: width * 0.7)
            .frame(width: width * 1.6, height: width * 1.4)
            .allowsHitTesting(false)
    }
}

#Preview("iPhone") {
    SplashScreen()
}

#Preview("Duo inner", traits: .fixedLayout(width: 669, height: 951)) {
    SplashScreen()
}

#Preview("Duo cover", traits: .fixedLayout(width: 466, height: 678)) {
    SplashScreen(isOnCover: true)
}
